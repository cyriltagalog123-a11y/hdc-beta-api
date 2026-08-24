import 'package:flutter/foundation.dart';

import '../core/proposals/proposal_activity_service.dart';
import '../core/proposals/proposal_comparison_service.dart';
import '../models/proposal.dart';
import '../models/proposal_draft.dart';
import '../models/proposal_comparison.dart';
import '../models/proposal_activity_entry.dart';
import '../models/proposal_request_summary.dart';
import '../models/service_request.dart';
import '../repositories/proposal_repository.dart';

class ProposalProvider extends ChangeNotifier {
  final ProposalRepository repository;
  final ProposalActivityService activityService;
  final ProposalComparisonService comparisonService;

  ProposalProvider({
    required this.repository,
    this.activityService = const ProposalActivityService(),
    this.comparisonService = const ProposalComparisonService(),
  });

  bool _isLoading = true;
  bool _isSaving = false;
  Object? _lastError;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  Object? get lastError => _lastError;

  List<Proposal> get proposals => repository.getAll();

  List<Proposal> get activeProposals => proposals
      .where((proposal) => proposal.status.isActive)
      .toList(growable: false);

  Proposal? byId(String id) => repository.byId(id);

  List<Proposal> forRequest(String requestId) {
    return repository.byRequestId(requestId);
  }

  List<Proposal> forTechnician(String technicianId) {
    return repository.byTechnicianId(technicianId);
  }

  int countForRequest(String requestId) {
    return forRequest(requestId)
        .where((proposal) => proposal.status != ProposalStatus.draft)
        .length;
  }

  ProposalRequestSummary summaryForRequest(String requestId) {
    return activityService.summarize(forRequest(requestId));
  }

  int get totalReceivedProposals {
    return proposals
        .where((proposal) => proposal.status != ProposalStatus.draft)
        .where((proposal) => proposal.status != ProposalStatus.withdrawn)
        .length;
  }

  Proposal? latestForTechnicianRequest({
    required String technicianId,
    required String requestId,
  }) {
    final matching = forTechnician(technicianId)
        .where((proposal) => proposal.requestId == requestId)
        .toList(growable: false);
    if (matching.isEmpty) return null;
    matching.sort((a, b) => b.latestLifecycleAt.compareTo(a.latestLifecycleAt));
    return matching.first;
  }

  List<ProposalActivityEntry> activityForRequest(ServiceRequest request) {
    return activityService.activityForRequest(
      request: request,
      proposals: forRequest(request.id),
    );
  }

  String customerNexusInsight(String requestId) {
    return activityService.customerNexusInsight(summaryForRequest(requestId));
  }

  String technicianNexusInsight({
    required String requestId,
    required String technicianId,
  }) {
    return activityService.technicianNexusInsight(
      summary: summaryForRequest(requestId),
      technicianProposal: latestForTechnicianRequest(
        technicianId: technicianId,
        requestId: requestId,
      ),
    );
  }


  List<Proposal> comparableForRequest(String requestId) {
    return forRequest(requestId)
        .where(comparisonService.isEligible)
        .toList(growable: false);
  }

  ProposalComparisonResult compareProposals({
    required String requestId,
    required List<String> proposalIds,
  }) {
    final available = comparableForRequest(requestId);
    final byId = {
      for (final proposal in available) proposal.id: proposal,
    };
    final selected = <Proposal>[];

    for (final proposalId in proposalIds) {
      final proposal = byId[proposalId];
      if (proposal == null) {
        throw StateError(
          'One or more selected proposals are no longer available '
          'for comparison.',
        );
      }
      selected.add(proposal);
    }

    return comparisonService.compare(
      requestId: requestId,
      proposals: selected,
    );
  }

  String comparisonNexusInsight(ProposalComparisonResult result) {
    return comparisonService.nexusTradeoffSummary(result);
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    try {
      await repository.initialize();
      _lastError = null;
    } on Object catch (error) {
      _lastError = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Proposal> saveDraft({
    required ProposalDraft draft,
    required TechnicianReputationSnapshot reputation,
  }) async {
    final validationErrors = draft.validate();
    if (validationErrors.isNotEmpty) {
      throw ArgumentError(validationErrors.join(' '));
    }

    _setSaving(true);
    try {
      final now = DateTime.now();
      final existing = draft.proposalId == null
          ? null
          : repository.byId(draft.proposalId!);
      final qualityScore = calculateQualityScore(draft);

      if (existing != null) {
        if (!existing.status.canEdit) {
          throw StateError('Only draft proposals can be edited.');
        }
        final updated = _applyDraft(
          existing,
          draft,
          reputation,
          qualityScore,
        );
        await repository.update(updated);
        _lastError = null;
        return repository.byId(updated.id) ?? updated;
      }

      final proposal = Proposal(
        id: _createId(now),
        requestId: draft.requestId,
        technicianId: draft.technicianId,
        status: ProposalStatus.draft,
        serviceFee: draft.serviceFee,
        partsArrangement: draft.partsArrangement,
        estimatedPartsCost: draft.estimatedPartsCost,
        earliestArrival: draft.earliestArrival,
        estimatedDurationMinutes: draft.estimatedDurationMinutes,
        warrantyType: draft.warrantyType,
        customWarrantyDays: draft.customWarrantyDays,
        diagnosis: draft.diagnosis.trim(),
        repairApproach: draft.repairApproach.trim(),
        professionalNotes: draft.professionalNotes.trim(),
        reputation: reputation,
        qualityScore: qualityScore,
        attachmentIds: List<String>.from(draft.attachmentIds),
        createdAt: now,
        updatedAt: now,
      );
      await repository.create(proposal);
      _lastError = null;
      return repository.byId(proposal.id) ?? proposal;
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _setSaving(false);
    }
  }

  Future<Proposal> submit(String proposalId) async {
    final current = _requireProposal(proposalId);
    if (current.status != ProposalStatus.draft) {
      throw StateError('Only draft proposals can be submitted.');
    }
    if (current.qualityScore < 40) {
      throw StateError(
        'Complete more proposal details before submitting.',
      );
    }

    return _updateStatus(
      current,
      ProposalStatus.submitted,
      submittedAt: DateTime.now(),
    );
  }

  Future<Proposal> markViewed(String proposalId) async {
    final current = _requireProposal(proposalId);
    if (current.status != ProposalStatus.submitted) return current;
    return _updateStatus(
      current,
      ProposalStatus.viewed,
      viewedAt: DateTime.now(),
    );
  }

  Future<Proposal> shortlist(String proposalId) async {
    final current = _requireProposal(proposalId);
    if (current.status != ProposalStatus.submitted &&
        current.status != ProposalStatus.viewed) {
      throw StateError('This proposal cannot be shortlisted.');
    }
    final now = DateTime.now();
    return _updateStatus(
      current,
      ProposalStatus.shortlisted,
      viewedAt: current.viewedAt ?? now,
      shortlistedAt: now,
    );
  }

  Future<Proposal> removeFromShortlist(String proposalId) async {
    final current = _requireProposal(proposalId);
    if (current.status != ProposalStatus.shortlisted) {
      return current;
    }
    return _updateStatus(
      current,
      ProposalStatus.viewed,
      clearShortlistedAt: true,
    );
  }

  Future<Proposal> accept(String proposalId) async {
    final accepted = _requireProposal(proposalId);
    if (!accepted.status.isActive) {
      throw StateError('This proposal is no longer available.');
    }

    _setSaving(true);
    try {
      final requestProposals = repository.byRequestId(accepted.requestId);
      Proposal? result;
      final now = DateTime.now();
      for (final proposal in requestProposals) {
        if (proposal.id == accepted.id) {
          result = proposal.copyWith(
            status: ProposalStatus.accepted,
            viewedAt: proposal.viewedAt ?? now,
            acceptedAt: now,
          );
          await repository.update(result);
        } else if (proposal.status.isActive) {
          await repository.update(
            proposal.copyWith(
              status: ProposalStatus.declined,
              declinedAt: now,
            ),
          );
        }
      }
      _lastError = null;
      return result!;
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _setSaving(false);
    }
  }

  Future<Proposal> decline(String proposalId) async {
    final current = _requireProposal(proposalId);
    if (!current.status.isActive) {
      throw StateError('This proposal cannot be declined.');
    }
    return _updateStatus(
      current,
      ProposalStatus.declined,
      declinedAt: DateTime.now(),
    );
  }

  Future<Proposal> withdraw(String proposalId) async {
    final current = _requireProposal(proposalId);
    if (!current.status.canWithdraw) {
      throw StateError('This proposal cannot be withdrawn.');
    }
    return _updateStatus(
      current,
      ProposalStatus.withdrawn,
      withdrawnAt: DateTime.now(),
    );
  }

  Future<void> deleteDraft(String proposalId) async {
    final current = repository.byId(proposalId);
    if (current == null || current.status != ProposalStatus.draft) return;

    _setSaving(true);
    try {
      await repository.delete(proposalId);
      _lastError = null;
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _setSaving(false);
    }
  }

  int calculateQualityScore(ProposalDraft draft) {
    var score = 20;

    if (draft.serviceFee > 0) score += 15;
    if (draft.earliestArrival.isAfter(DateTime.now())) score += 10;
    if (draft.estimatedDurationMinutes > 0) score += 10;
    if (draft.diagnosis.trim().length >= 30) score += 15;
    if (draft.repairApproach.trim().length >= 30) score += 15;
    if (draft.professionalNotes.trim().length >= 20) score += 5;
    if (draft.warrantyType != ProposalWarrantyType.none) score += 5;
    if (draft.partsArrangement != ProposalPartsArrangement.none) score += 5;

    return score.clamp(0, 100);
  }

  Proposal _applyDraft(
    Proposal current,
    ProposalDraft draft,
    TechnicianReputationSnapshot reputation,
    int qualityScore,
  ) {
    return current.copyWith(
      serviceFee: draft.serviceFee,
      partsArrangement: draft.partsArrangement,
      estimatedPartsCost: draft.estimatedPartsCost,
      clearEstimatedPartsCost:
          draft.partsArrangement != ProposalPartsArrangement.technicianSupplies,
      earliestArrival: draft.earliestArrival,
      estimatedDurationMinutes: draft.estimatedDurationMinutes,
      warrantyType: draft.warrantyType,
      customWarrantyDays: draft.customWarrantyDays,
      clearCustomWarrantyDays:
          draft.warrantyType != ProposalWarrantyType.custom,
      diagnosis: draft.diagnosis.trim(),
      repairApproach: draft.repairApproach.trim(),
      professionalNotes: draft.professionalNotes.trim(),
      reputation: reputation,
      qualityScore: qualityScore,
      attachmentIds: List<String>.from(draft.attachmentIds),
    );
  }

  Proposal _requireProposal(String id) {
    final proposal = repository.byId(id);
    if (proposal == null) {
      throw StateError('Proposal $id was not found.');
    }
    return proposal;
  }

  Future<Proposal> _updateStatus(
    Proposal current,
    ProposalStatus status, {
    DateTime? submittedAt,
    DateTime? viewedAt,
    DateTime? shortlistedAt,
    DateTime? acceptedAt,
    DateTime? declinedAt,
    DateTime? withdrawnAt,
    bool clearShortlistedAt = false,
  }) async {
    _setSaving(true);
    try {
      final updated = current.copyWith(
        status: status,
        submittedAt: submittedAt,
        viewedAt: viewedAt,
        shortlistedAt: shortlistedAt,
        acceptedAt: acceptedAt,
        declinedAt: declinedAt,
        withdrawnAt: withdrawnAt,
        clearShortlistedAt: clearShortlistedAt,
      );
      await repository.update(updated);
      _lastError = null;
      return repository.byId(updated.id) ?? updated;
    } on Object catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _setSaving(false);
    }
  }

  void refreshFromRepository() {
    notifyListeners();
  }

  void _setSaving(bool value) {
    _isSaving = value;
    notifyListeners();
  }

  String _createId(DateTime time) => 'PR-${time.millisecondsSinceEpoch}';
}
