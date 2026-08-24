import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/proposal.dart';
import 'proposal_repository.dart';

class SharedPreferencesProposalRepository implements ProposalRepository {
  static const _storageKey = 'hdc_professional_proposals_v1';

  final List<Proposal> _proposals = [];
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_storageKey);

    if (stored != null && stored.trim().isNotEmpty) {
      final decoded = jsonDecode(stored);
      if (decoded is List) {
        _proposals
          ..clear()
          ..addAll(
            decoded.whereType<Map>().map(
              (item) => Proposal.fromJson(
                Map<String, dynamic>.from(item),
              ),
            ),
          );
      }
    }

    _initialized = true;
  }

  @override
  List<Proposal> getAll() {
    final proposals = List<Proposal>.from(_proposals);
    proposals.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return proposals;
  }

  @override
  Proposal? byId(String id) {
    for (final proposal in _proposals) {
      if (proposal.id == id) return proposal;
    }
    return null;
  }

  @override
  List<Proposal> byRequestId(String requestId) {
    return getAll()
        .where((proposal) => proposal.requestId == requestId)
        .toList(growable: false);
  }

  @override
  List<Proposal> byTechnicianId(String technicianId) {
    return getAll()
        .where((proposal) => proposal.technicianId == technicianId)
        .toList(growable: false);
  }

  @override
  Future<void> create(Proposal proposal) async {
    if (byId(proposal.id) != null) {
      throw StateError('Proposal ${proposal.id} already exists.');
    }
    _proposals.add(proposal);
    await _persist();
  }

  @override
  Future<void> update(Proposal proposal) async {
    final index = _proposals.indexWhere((item) => item.id == proposal.id);
    if (index == -1) {
      throw StateError('Proposal ${proposal.id} was not found.');
    }
    _proposals[index] = proposal;
    await _persist();
  }

  @override
  Future<void> delete(String id) async {
    _proposals.removeWhere((proposal) => proposal.id == id);
    await _persist();
  }

  Future<void> _persist() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      _proposals.map((proposal) => proposal.toJson()).toList(),
    );
    final saved = await preferences.setString(_storageKey, encoded);
    if (!saved) {
      throw StateError('Professional proposals could not be saved locally.');
    }
  }
}
