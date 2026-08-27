import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui/hdc_colors.dart';
import '../../models/account_identity.dart';
import '../../models/proposal.dart';
import '../../models/proposal_draft.dart';
import '../../models/service_request.dart';
import '../../providers/hdc_auth_provider.dart';
import '../../providers/proposal_provider.dart';

class ProposalStudioScreen extends StatefulWidget {
  final ServiceRequest request;

  const ProposalStudioScreen({
    required this.request,
    super.key,
  });

  @override
  State<ProposalStudioScreen> createState() => _ProposalStudioScreenState();
}

class _ProposalStudioScreenState extends State<ProposalStudioScreen> {
  AccountIdentity? get _technicianIdentity {
    final auth = context.read<HDCAuthProvider>();
    final identity = auth.identity;
    if (!auth.authenticated ||
        identity == null ||
        !identity.hasPlatformRole(HDCPlatformRole.technician)) {
      return null;
    }
    return identity;
  }

  String get _technicianId {
    final identity = _technicianIdentity;
    if (identity == null) {
      throw StateError('Registered technician access is required.');
    }
    return identity.id;
  }

  TechnicianReputationSnapshot get _reputation {
    final identity = _technicianIdentity;
    if (identity == null) {
      throw StateError('Registered technician access is required.');
    }

    return TechnicianReputationSnapshot(
      technicianName: identity.displayName,
      isVerified: false,
      rating: 0,
      completedJobs: 0,
      averageResponseMinutes: 0,
      successRate: 0,
      memberSinceYear: identity.createdAt.year,
    );
  }

  final _serviceFeeController = TextEditingController();
  final _partsCostController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _repairApproachController = TextEditingController();
  final _notesController = TextEditingController();
  final _customWarrantyController = TextEditingController();

  ProposalPartsArrangement _partsArrangement =
      ProposalPartsArrangement.none;
  ProposalWarrantyType _warrantyType = ProposalWarrantyType.thirtyDays;
  DateTime _earliestArrival = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _arrivalTime = const TimeOfDay(hour: 9, minute: 0);
  int _durationMinutes = 120;
  String? _proposalId;
  bool _initialized = false;
  bool _hasUnsavedChanges = false;
  bool _isSubmitting = false;
  DateTime? _lastSavedAt;
  Timer? _saveDebounce;
  Future<Proposal>? _saveInFlight;
  int _editRevision = 0;
  int _lastPersistedRevision = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final identity = _technicianIdentity;
    if (identity == null) {
      return;
    }

    final provider = context.read<ProposalProvider>();
    final drafts = provider
        .forTechnician(_technicianId)
        .where(
          (proposal) =>
              proposal.requestId == widget.request.id &&
              proposal.status == ProposalStatus.draft,
        )
        .toList(growable: false);

    if (drafts.isNotEmpty) {
      _loadProposal(drafts.first);
    }

    for (final controller in [
      _serviceFeeController,
      _partsCostController,
      _diagnosisController,
      _repairApproachController,
      _notesController,
      _customWarrantyController,
    ]) {
      controller.addListener(_onChanged);
    }
  }

  void _loadProposal(Proposal proposal) {
    _proposalId = proposal.id;
    _serviceFeeController.text = proposal.serviceFee == 0
        ? ''
        : proposal.serviceFee.toStringAsFixed(0);
    _partsCostController.text = proposal.estimatedPartsCost == null
        ? ''
        : proposal.estimatedPartsCost!.toStringAsFixed(0);
    _diagnosisController.text = proposal.diagnosis;
    _repairApproachController.text = proposal.repairApproach;
    _notesController.text = proposal.professionalNotes;
    _customWarrantyController.text = proposal.customWarrantyDays?.toString() ?? '';
    _partsArrangement = proposal.partsArrangement;
    _warrantyType = proposal.warrantyType;
    _earliestArrival = proposal.earliestArrival;
    _arrivalTime = TimeOfDay.fromDateTime(proposal.earliestArrival);
    _durationMinutes = proposal.estimatedDurationMinutes;
    _lastSavedAt = proposal.updatedAt;
    _lastPersistedRevision = _editRevision;
  }

  void _recordEdit() {
    _editRevision += 1;
    _hasUnsavedChanges = true;
  }

  void _onChanged() {
    if (!mounted) return;
    setState(_recordEdit);
    _scheduleAutoSave();
  }

  void _scheduleAutoSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) unawaited(_saveDraft(showMessage: false));
    });
  }

  double? _numberFrom(TextEditingController controller) {
    return double.tryParse(controller.text.trim().replaceAll(',', ''));
  }

  DateTime get _arrivalDateTime => DateTime(
        _earliestArrival.year,
        _earliestArrival.month,
        _earliestArrival.day,
        _arrivalTime.hour,
        _arrivalTime.minute,
      );

  ProposalDraft _buildDraft() {
    return ProposalDraft(
      proposalId: _proposalId,
      requestId: widget.request.id,
      technicianId: _technicianId,
      serviceFee: _numberFrom(_serviceFeeController) ?? 0,
      partsArrangement: _partsArrangement,
      estimatedPartsCost:
          _partsArrangement == ProposalPartsArrangement.technicianSupplies
              ? _numberFrom(_partsCostController) ?? 0
              : null,
      earliestArrival: _arrivalDateTime,
      estimatedDurationMinutes: _durationMinutes,
      warrantyType: _warrantyType,
      customWarrantyDays: _warrantyType == ProposalWarrantyType.custom
          ? int.tryParse(_customWarrantyController.text.trim())
          : null,
      diagnosis: _diagnosisController.text,
      repairApproach: _repairApproachController.text,
      professionalNotes: _notesController.text,
    );
  }

  Future<Proposal> _saveCurrentRevision() {
    final active = _saveInFlight;
    if (active != null) return active;

    if (!_hasUnsavedChanges && _proposalId != null) {
      final saved = context.read<ProposalProvider>().byId(_proposalId!);
      if (saved == null) {
        return Future<Proposal>.error(
          StateError('The saved proposal is no longer available.'),
        );
      }
      return Future<Proposal>.value(saved);
    }

    final revision = _editRevision;
    final draft = _buildDraft();
    late final Future<Proposal> pending;
    pending = _persistRevision(
      draft: draft,
      revision: revision,
    ).whenComplete(() {
      if (identical(_saveInFlight, pending)) {
        _saveInFlight = null;
      }
    });
    _saveInFlight = pending;
    return pending;
  }

  Future<Proposal> _persistRevision({
    required ProposalDraft draft,
    required int revision,
  }) async {
    final proposal = await context.read<ProposalProvider>().saveDraft(
          draft: draft,
          reputation: _reputation,
        );
    if (!mounted) return proposal;

    setState(() {
      _proposalId = proposal.id;
      _lastPersistedRevision = revision;
      _hasUnsavedChanges = _editRevision != revision;
      _lastSavedAt = proposal.updatedAt;
    });
    if (_editRevision != revision) _scheduleAutoSave();
    return proposal;
  }

  Future<Proposal?> _saveDraft({required bool showMessage}) async {
    try {
      final alreadySaved = !_hasUnsavedChanges && _proposalId != null;
      final proposal = await _saveCurrentRevision();
      if (!mounted) return proposal;
      if (showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              alreadySaved
                  ? 'Your proposal draft is already saved.'
                  : 'Proposal draft saved.',
            ),
          ),
        );
      }
      return proposal;
    } on Object catch (error) {
      if (!mounted) return null;
      if (showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save draft: $error')),
        );
      }
      return null;
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    _saveDebounce?.cancel();
    setState(() => _isSubmitting = true);
    try {
      Proposal? saved;
      while (mounted &&
          (_proposalId == null ||
              _lastPersistedRevision != _editRevision)) {
        saved = await _saveCurrentRevision();
      }
      if (!mounted) return;
      saved ??= context.read<ProposalProvider>().byId(_proposalId!);
      if (saved == null) {
        throw StateError('The proposal draft could not be loaded.');
      }
      _saveDebounce?.cancel();
      final submitted = await context.read<ProposalProvider>().submit(saved.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: HDCColors.success, size: 42),
          title: const Text('Proposal submitted'),
          content: Text(
            '${submitted.reputation.technicianName}\'s proposal was sent to '
            '${widget.request.customerName}. It is now ready for customer review.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _earliestArrival,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    setState(() {
      _earliestArrival = date;
      _recordEdit();
    });
    _scheduleAutoSave();
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _arrivalTime,
    );
    if (time == null || !mounted) return;
    setState(() {
      _arrivalTime = time;
      _recordEdit();
    });
    _scheduleAutoSave();
  }

  String _dateLabel(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _durationLabel(int minutes) {
    if (minutes < 60) return '$minutes minutes';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return remainder == 0 ? '$hours hour${hours == 1 ? '' : 's'}' : '$hours hr $remainder min';
  }

  String get _saveStatus {
    if (context.watch<ProposalProvider>().isSaving) return 'Saving...';
    if (_hasUnsavedChanges) return 'Unsaved changes';
    if (_lastSavedAt != null) return 'Saved';
    return 'New draft';
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    for (final controller in [
      _serviceFeeController,
      _partsCostController,
      _diagnosisController,
      _repairApproachController,
      _notesController,
      _customWarrantyController,
    ]) {
      controller
        ..removeListener(_onChanged)
        ..dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<HDCAuthProvider>();
    final identity = auth.identity;
    final canAccess = auth.authenticated &&
        identity != null &&
        identity.hasPlatformRole(HDCPlatformRole.technician);

    if (!canAccess) {
      return const Scaffold(
        body: Center(
          child: Text('Registered technician access required.'),
        ),
      );
    }

    final draft = _buildDraft();
    final quality = context.read<ProposalProvider>().calculateQualityScore(draft);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Professional Proposal Studio'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Center(
              child: _SaveStatus(label: _saveStatus),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1080;
            final editor = _buildEditor(context, quality);
            final preview = _ProposalPreview(
              request: widget.request,
              draft: draft,
              reputation: _reputation,
              qualityScore: quality,
              dateLabel: _dateLabel,
              durationLabel: _durationLabel,
            );

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 7,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(22),
                      child: editor,
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    flex: 5,
                    child: Container(
                      color: HDCColors.background,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(22),
                        child: preview,
                      ),
                    ),
                  ),
                ],
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  editor,
                  const SizedBox(height: 22),
                  preview,
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : () => _saveDraft(showMessage: true),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Draft'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(_isSubmitting ? 'Submitting...' : 'Submit Proposal'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor(BuildContext context, int quality) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RequestSummary(request: widget.request),
          const SizedBox(height: 18),
          _SectionCard(
            title: 'Technical assessment',
            subtitle: 'Explain what you think is happening and how you plan to resolve it.',
            icon: Icons.troubleshoot_outlined,
            child: Column(
              children: [
                TextField(
                  controller: _diagnosisController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Initial diagnosis',
                    hintText: 'Describe the most likely cause based on the customer\'s symptoms.',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _repairApproachController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Repair plan',
                    hintText: 'Explain your diagnostic and repair process.',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionCard(
            title: 'Pricing',
            subtitle: 'Give the customer a transparent estimate before work begins.',
            icon: Icons.payments_outlined,
            child: Column(
              children: [
                TextField(
                  controller: _serviceFeeController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Service fee',
                    prefixText: 'PHP ',
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<ProposalPartsArrangement>(
                  initialValue: _partsArrangement,
                  decoration: const InputDecoration(labelText: 'Parts arrangement'),
                  items: ProposalPartsArrangement.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _partsArrangement = value;
                      _recordEdit();
                    });
                    _scheduleAutoSave();
                  },
                ),
                if (_partsArrangement == ProposalPartsArrangement.technicianSupplies) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: _partsCostController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Estimated parts cost',
                      prefixText: 'PHP ',
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _TotalEstimate(
                  serviceFee: _numberFrom(_serviceFeeController) ?? 0,
                  partsCost: _partsArrangement == ProposalPartsArrangement.technicianSupplies
                      ? _numberFrom(_partsCostController) ?? 0
                      : 0,
                  budgetLabel: widget.request.budgetLabel,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionCard(
            title: 'Schedule and warranty',
            subtitle: 'Set clear expectations about arrival, duration, and after-service support.',
            icon: Icons.event_available_outlined,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(_dateLabel(_earliestArrival)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.schedule_outlined),
                        label: Text(_arrivalTime.format(context)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: _durationMinutes,
                  decoration: const InputDecoration(labelText: 'Estimated repair duration'),
                  items: const [30, 60, 90, 120, 180, 240, 480]
                      .map(
                        (minutes) => DropdownMenuItem(
                          value: minutes,
                          child: Text(_durationLabel(minutes)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _durationMinutes = value;
                      _recordEdit();
                    });
                    _scheduleAutoSave();
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<ProposalWarrantyType>(
                  initialValue: _warrantyType,
                  decoration: const InputDecoration(labelText: 'Service warranty'),
                  items: ProposalWarrantyType.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _warrantyType = value;
                      _recordEdit();
                    });
                    _scheduleAutoSave();
                  },
                ),
                if (_warrantyType == ProposalWarrantyType.custom) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: _customWarrantyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Custom warranty period',
                      suffixText: 'days',
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionCard(
            title: 'Professional notes',
            subtitle: 'Use this space to build trust, clarify exclusions, or explain next steps.',
            icon: Icons.description_outlined,
            child: TextField(
              controller: _notesController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Message to customer',
                hintText: 'Example: I will confirm the diagnosis before replacing any component...',
                alignLabelWithHint: true,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _QualityCard(score: quality, draft: _buildDraft()),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SaveStatus extends StatelessWidget {
  final String label;

  const _SaveStatus({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: HDCColors.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: HDCColors.secondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: HDCColors.secondary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: HDCColors.secondary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: HDCColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _RequestSummary extends StatelessWidget {
  final ServiceRequest request;

  const _RequestSummary({required this.request});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CUSTOMER REQUEST',
              style: TextStyle(
                color: HDCColors.secondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              request.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(request.description, style: const TextStyle(height: 1.5)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MiniBadge(label: request.categoryName),
                _MiniBadge(label: request.urgency.label),
                _MiniBadge(label: request.budgetLabel),
                _MiniBadge(label: request.location),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;

  const _MiniBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: HDCColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: HDCColors.border),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _TotalEstimate extends StatelessWidget {
  final double serviceFee;
  final double partsCost;
  final String budgetLabel;

  const _TotalEstimate({
    required this.serviceFee,
    required this.partsCost,
    required this.budgetLabel,
  });

  @override
  Widget build(BuildContext context) {
    final total = serviceFee + partsCost;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HDCColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HDCColors.border),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text('Estimated total', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'PHP ${total.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: HDCColors.secondary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              Text(
                'Customer: $budgetLabel',
                style: const TextStyle(color: HDCColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QualityCard extends StatelessWidget {
  final int score;
  final ProposalDraft draft;

  const _QualityCard({required this.score, required this.draft});

  List<String> get suggestions {
    final values = <String>[];
    if (draft.serviceFee <= 0) values.add('Add a clear service fee.');
    if (draft.diagnosis.trim().length < 30) values.add('Explain your initial diagnosis in more detail.');
    if (draft.repairApproach.trim().length < 30) values.add('Describe your repair or diagnostic plan.');
    if (draft.professionalNotes.trim().length < 20) values.add('Add a professional customer message.');
    if (draft.warrantyType == ProposalWarrantyType.none) values.add('Consider adding a service warranty.');
    return values;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_outlined, color: HDCColors.secondary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Proposal quality', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                ),
                Text('$score%', style: const TextStyle(color: HDCColors.secondary, fontWeight: FontWeight.w900, fontSize: 20)),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(value: score / 100, minHeight: 9, borderRadius: BorderRadius.circular(999)),
            const SizedBox(height: 14),
            Text(
              score >= 85 ? 'Excellent proposal' : score >= 65 ? 'Strong proposal' : score >= 40 ? 'Ready, but can improve' : 'Add more detail before submitting',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...suggestions.take(3).map(
                    (suggestion) => Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline, size: 18, color: HDCColors.warning),
                          const SizedBox(width: 8),
                          Expanded(child: Text(suggestion)),
                        ],
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProposalPreview extends StatelessWidget {
  final ServiceRequest request;
  final ProposalDraft draft;
  final TechnicianReputationSnapshot reputation;
  final int qualityScore;
  final String Function(DateTime) dateLabel;
  final String Function(int) durationLabel;

  const _ProposalPreview({
    required this.request,
    required this.draft,
    required this.reputation,
    required this.qualityScore,
    required this.dateLabel,
    required this.durationLabel,
  });

  @override
  Widget build(BuildContext context) {
    final total = draft.serviceFee + (draft.estimatedPartsCost ?? 0);
    final warrantyDays = draft.warrantyType.fixedDays ?? draft.customWarrantyDays ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('LIVE CUSTOMER PREVIEW', style: TextStyle(color: HDCColors.secondary, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
            ),
            _MiniBadge(label: '$qualityScore% quality'),
          ],
        ),
        const SizedBox(height: 14),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: HDCColors.secondary.withValues(alpha: 0.10),
                      child: const Icon(Icons.engineering_outlined, color: HDCColors.secondary),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(reputation.technicianName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                          const SizedBox(height: 3),
                          Text('★ ${reputation.rating.toStringAsFixed(1)} • ${reputation.completedJobs} completed jobs', style: const TextStyle(color: HDCColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (reputation.isVerified)
                      const Icon(Icons.verified, color: HDCColors.secondary),
                  ],
                ),
                const SizedBox(height: 20),
                Text(request.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                _PreviewValue(label: 'Estimated total', value: 'PHP ${total.toStringAsFixed(0)}', emphasized: true),
                _PreviewValue(label: 'Earliest arrival', value: '${dateLabel(draft.earliestArrival)} • ${TimeOfDay.fromDateTime(draft.earliestArrival).format(context)}'),
                _PreviewValue(label: 'Estimated duration', value: durationLabel(draft.estimatedDurationMinutes)),
                _PreviewValue(label: 'Warranty', value: warrantyDays == 0 ? 'No warranty' : '$warrantyDays days'),
                _PreviewValue(label: 'Parts', value: draft.partsArrangement.label),
                const Divider(height: 30),
                _PreviewText(title: 'Initial diagnosis', text: draft.diagnosis, emptyText: 'Your diagnosis will appear here.'),
                const SizedBox(height: 17),
                _PreviewText(title: 'Repair plan', text: draft.repairApproach, emptyText: 'Your repair plan will appear here.'),
                const SizedBox(height: 17),
                _PreviewText(title: 'Message from technician', text: draft.professionalNotes, emptyText: 'Your customer message will appear here.'),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: HDCColors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    '${reputation.successRate.toStringAsFixed(0)}% success rate • Average response ${reputation.averageResponseMinutes} minutes',
                    style: const TextStyle(color: HDCColors.success, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewValue extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _PreviewValue({required this.label, required this.value, this.emphasized = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: HDCColors.textSecondary))),
          const SizedBox(width: 14),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: emphasized ? HDCColors.secondary : HDCColors.textPrimary,
              fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
              fontSize: emphasized ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewText extends StatelessWidget {
  final String title;
  final String text;
  final String emptyText;

  const _PreviewText({required this.title, required this.text, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    final empty = text.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          empty ? emptyText : text.trim(),
          style: TextStyle(
            color: empty ? HDCColors.textSecondary : HDCColors.textPrimary,
            fontStyle: empty ? FontStyle.italic : FontStyle.normal,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
