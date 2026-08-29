import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui/hdc_colors.dart';
import '../../core/workflow/hdc_workflow_refresh.dart';
import '../../models/service_transaction.dart';
import '../../models/transaction_toolbox.dart';
import '../../providers/hdc_transaction_tools_provider.dart';
import '../../providers/service_transaction_provider.dart';

enum TransactionToolSection { service, payment, documents, dispute }

class TransactionToolsScreen extends StatefulWidget {
  final String transactionId;
  final String actorId;
  final ServiceTransactionParticipantRole role;
  final TransactionToolSection initialSection;

  const TransactionToolsScreen({
    required this.transactionId,
    required this.actorId,
    required this.role,
    this.initialSection = TransactionToolSection.service,
    super.key,
  });

  @override
  State<TransactionToolsScreen> createState() => _TransactionToolsScreenState();
}

class _TransactionToolsScreenState extends State<TransactionToolsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      await context
          .read<HdcTransactionToolsProvider>()
          .refresh(widget.transactionId);
    } on Object {
      // The provider exposes the load error in the screen body.
    }
  }

  Future<void> _run(
    Future<HdcTransactionToolbox> Function() action,
    String successMessage,
  ) async {
    try {
      await action();
      if (!mounted) return;
      await refreshHdcWorkflow(context);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<HdcTransactionToolsProvider>();
    final transaction = context
        .watch<ServiceTransactionProvider>()
        .byId(widget.transactionId);
    final toolbox = tools.forTransaction(widget.transactionId);

    return DefaultTabController(
      length: 4,
      initialIndex: widget.initialSection.index,
      child: Scaffold(
        backgroundColor: HDCColors.background,
        appBar: AppBar(
          title: const Text('Service Tools'),
          actions: [
            IconButton(
              tooltip: 'Refresh service tools',
              onPressed: tools.isLoading ? null : _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.event_note_outlined), text: 'Service'),
              Tab(icon: Icon(Icons.payments_outlined), text: 'Payment'),
              Tab(icon: Icon(Icons.folder_outlined), text: 'Documents'),
              Tab(icon: Icon(Icons.gavel_outlined), text: 'Dispute'),
            ],
          ),
        ),
        body: transaction == null
            ? const Center(child: Text('Service transaction was not found.'))
            : tools.isLoading && toolbox == null
                ? const Center(child: CircularProgressIndicator())
                : toolbox == null
                    ? _LoadFailure(
                        error: tools.lastError,
                        backendAvailable: tools.backendAvailable,
                        onRetry: _refresh,
                      )
                    : TabBarView(
                        children: [
                          _serviceTab(transaction, toolbox, tools),
                          _paymentTab(transaction, toolbox, tools),
                          _documentsTab(transaction, toolbox, tools),
                          _disputeTab(transaction, toolbox, tools),
                        ],
                      ),
      ),
    );
  }

  Widget _serviceTab(
    ServiceTransaction transaction,
    HdcTransactionToolbox toolbox,
    HdcTransactionToolsProvider provider,
  ) {
    final schedule = toolbox.pendingSchedule;
    final change = toolbox.pendingChangeOrder;
    final locked = transaction.status == ServiceTransactionStatus.disputed ||
        transaction.status.isTerminal;
    return _ToolList(
      onRefresh: _refresh,
      children: [
        const _ToolIntro(
          icon: Icons.event_available_outlined,
          title: 'Schedule, price, and service issues',
          message:
              'Schedule changes require the other participant’s decision. '
              'Only the technician can propose a revised price, and only the '
              'customer can approve it.',
        ),
        _SectionCard(
          title: 'Schedule',
          action: FilledButton.tonalIcon(
            onPressed: locked || schedule != null || provider.isSaving
                ? null
                : () => _proposeSchedule(provider),
            icon: const Icon(Icons.edit_calendar_outlined),
            label: const Text('Propose change'),
          ),
          children: [
            if (schedule == null)
              const _EmptyLine('No schedule change is awaiting a decision.')
            else
              _RecordTile(
                title: _dateTime(schedule.proposedFor),
                subtitle: schedule.note.isEmpty
                    ? 'No additional note'
                    : schedule.note,
                status: schedule.status,
                actions: [
                  if (schedule.proposedBy == widget.actorId)
                    TextButton(
                      onPressed: provider.isSaving
                          ? null
                          : () => _run(
                                () => provider.decideSchedule(
                                  transactionId: widget.transactionId,
                                  scheduleId: schedule.id,
                                  action: 'withdraw',
                                ),
                                'Schedule request withdrawn.',
                              ),
                      child: const Text('Withdraw'),
                    )
                  else ...[
                    TextButton(
                      onPressed: provider.isSaving
                          ? null
                          : () => _run(
                                () => provider.decideSchedule(
                                  transactionId: widget.transactionId,
                                  scheduleId: schedule.id,
                                  action: 'decline',
                                ),
                                'Schedule request declined.',
                              ),
                      child: const Text('Decline'),
                    ),
                    FilledButton(
                      onPressed: provider.isSaving
                          ? null
                          : () => _run(
                                () => provider.decideSchedule(
                                  transactionId: widget.transactionId,
                                  scheduleId: schedule.id,
                                  action: 'accept',
                                ),
                                'Schedule updated.',
                              ),
                      child: const Text('Accept'),
                    ),
                  ],
                ],
              ),
            if (toolbox.schedules.length > 1)
              _HistoryLine('${toolbox.schedules.length} schedule records'),
          ],
        ),
        _SectionCard(
          title: 'Approved price',
          action: widget.role == ServiceTransactionParticipantRole.technician
              ? FilledButton.tonalIcon(
                  onPressed: locked || change != null || provider.isSaving
                      ? null
                      : () => _proposePrice(provider, toolbox),
                  icon: const Icon(Icons.price_change_outlined),
                  label: const Text('Revise price'),
                )
              : null,
          children: [
            _MoneySummary(
              label: 'Current approved total',
              amountMinor: toolbox.authorizedTotalMinor,
              currency: toolbox.currency,
            ),
            if (change != null) ...[
              const Divider(height: 24),
              _RecordTile(
                title: _money(change.totalMinor, change.currency),
                subtitle: change.reason,
                status: change.status,
                actions: [
                  if (change.proposedBy == widget.actorId)
                    TextButton(
                      onPressed: provider.isSaving
                          ? null
                          : () => _run(
                                () => provider.decideChangeOrder(
                                  transactionId: widget.transactionId,
                                  changeOrderId: change.id,
                                  action: 'withdraw',
                                ),
                                'Price change withdrawn.',
                              ),
                      child: const Text('Withdraw'),
                    )
                  else ...[
                    TextButton(
                      onPressed: provider.isSaving
                          ? null
                          : () => _run(
                                () => provider.decideChangeOrder(
                                  transactionId: widget.transactionId,
                                  changeOrderId: change.id,
                                  action: 'decline',
                                ),
                                'Price change declined.',
                              ),
                      child: const Text('Decline'),
                    ),
                    FilledButton(
                      onPressed: provider.isSaving
                          ? null
                          : () => _run(
                                () => provider.decideChangeOrder(
                                  transactionId: widget.transactionId,
                                  changeOrderId: change.id,
                                  action: 'accept',
                                ),
                                'Revised price approved.',
                              ),
                      child: const Text('Approve'),
                    ),
                  ],
                ],
              ),
            ],
            if (toolbox.changeOrders.isNotEmpty)
              _HistoryLine('${toolbox.changeOrders.length} price-change records'),
          ],
        ),
        _SectionCard(
          title: 'Cancellation and issue records',
          action: FilledButton.tonalIcon(
            onPressed: transaction.status.isTerminal ||
                    transaction.status == ServiceTransactionStatus.disputed ||
                    provider.isSaving
                ? null
                : () => _recordIssue(provider, transaction),
            icon: const Icon(Icons.report_problem_outlined),
            label: const Text('Record issue'),
          ),
          children: [
            if (toolbox.exceptions.isEmpty)
              const _EmptyLine('No service exceptions have been recorded.')
            else
              for (final item in toolbox.exceptions.take(5))
                _RecordTile(
                  title: _label(item.exceptionType),
                  subtitle: item.reason,
                  status: item.status,
                ),
          ],
        ),
      ],
    );
  }

  Widget _paymentTab(
    ServiceTransaction transaction,
    HdcTransactionToolbox toolbox,
    HdcTransactionToolsProvider provider,
  ) {
    final isCustomer = widget.role == ServiceTransactionParticipantRole.customer;
    return _ToolList(
      onRefresh: _refresh,
      children: [
        const _ToolIntro(
          icon: Icons.receipt_long_outlined,
          title: 'Payment record and receipts',
          message:
              'HDC does not process or hold money in this build. The customer '
              'records an external payment and the technician confirms only '
              'after receiving it. Receipts are participant-confirmed, not '
              'payment-provider verified.',
          warning: true,
        ),
        _SectionCard(
          title: 'Balance',
          action: isCustomer
              ? FilledButton.tonalIcon(
                  onPressed: toolbox.balanceMinor <= 0 ||
                          transaction.status == ServiceTransactionStatus.disputed ||
                          provider.isSaving
                      ? null
                      : () => _recordPayment(provider, toolbox),
                  icon: const Icon(Icons.add_card_outlined),
                  label: const Text('Record payment'),
                )
              : null,
          children: [
            _MoneySummary(
              label: 'Approved total',
              amountMinor: toolbox.authorizedTotalMinor,
              currency: toolbox.currency,
            ),
            _MoneySummary(
              label: 'Confirmed paid',
              amountMinor: toolbox.confirmedPaidMinor,
              currency: toolbox.currency,
            ),
            _MoneySummary(
              label: 'Remaining balance',
              amountMinor: toolbox.balanceMinor,
              currency: toolbox.currency,
              strong: true,
            ),
          ],
        ),
        _SectionCard(
          title: 'Payment records',
          children: [
            if (toolbox.payments.isEmpty)
              const _EmptyLine('No payment has been recorded.')
            else
              for (final payment in toolbox.payments)
                _PaymentTile(
                  payment: payment,
                  events: toolbox.paymentEvents
                      .where((event) => event.paymentId == payment.id)
                      .toList(growable: false),
                  actorId: widget.actorId,
                  role: widget.role,
                  saving: provider.isSaving,
                  frozen:
                      transaction.status == ServiceTransactionStatus.disputed,
                  onAction: (action, amountMinor) => _run(
                    () => provider.updatePayment(
                      transactionId: widget.transactionId,
                      paymentId: payment.id,
                      action: action,
                      amountMinor: amountMinor,
                    ),
                    _paymentSuccess(action),
                  ),
                  onRefund: () => _recordRefund(provider, payment),
                ),
          ],
        ),
        _SectionCard(
          title: 'Receipts',
          children: [
            if (toolbox.receipts.isEmpty)
              const _EmptyLine('A receipt appears after participant confirmation.')
            else
              for (final receipt in toolbox.receipts)
                _RecordTile(
                  title: '${_label(receipt.receiptType)} receipt • '
                      '${_money(receipt.amountMinor, receipt.currency)}',
                  subtitle:
                      '${receipt.id}\nParticipant-confirmed • ${_dateTime(receipt.issuedAt)}',
                  status: receipt.verificationLevel,
                ),
          ],
        ),
      ],
    );
  }

  Widget _documentsTab(
    ServiceTransaction transaction,
    HdcTransactionToolbox toolbox,
    HdcTransactionToolsProvider provider,
  ) {
    return _ToolList(
      onRefresh: _refresh,
      children: [
        const _ToolIntro(
          icon: Icons.description_outlined,
          title: 'Structured service documents',
          message:
              'Create service reports, warranty terms, payment evidence, and '
              'dispute evidence as protected text records. Binary uploads stay '
              'disabled until an object-storage provider is connected.',
        ),
        _SectionCard(
          title: 'Documents',
          action: FilledButton.tonalIcon(
            onPressed: provider.isSaving
                ? null
                : () => _createDocument(provider, toolbox),
            icon: const Icon(Icons.note_add_outlined),
            label: const Text('New document'),
          ),
          children: [
            if (toolbox.documents.isEmpty)
              const _EmptyLine('No structured documents have been added.')
            else
              for (final document in toolbox.documents)
                _DocumentTile(
                  document: document,
                  canRemove: document.createdBy == widget.actorId &&
                      document.disputeId == null,
                  saving: provider.isSaving,
                  onRemove: () => _run(
                    () => provider.removeDocument(
                      transactionId: widget.transactionId,
                      documentId: document.id,
                    ),
                    'Document removed.',
                  ),
                ),
          ],
        ),
      ],
    );
  }

  Widget _disputeTab(
    ServiceTransaction transaction,
    HdcTransactionToolbox toolbox,
    HdcTransactionToolsProvider provider,
  ) {
    final dispute = toolbox.activeDispute;
    return _ToolList(
      onRefresh: _refresh,
      children: [
        const _ToolIntro(
          icon: Icons.balance_outlined,
          title: 'Dispute handling',
          message:
              'Opening a dispute freezes service and payment changes. Both '
              'participants can add notes; only the opener can withdraw. An '
              'HDC Owner or Super Admin records the final resolution.',
          warning: true,
        ),
        if (dispute == null)
          _SectionCard(
            title: 'No active dispute',
            action: FilledButton.icon(
              onPressed: provider.isSaving
                  ? null
                  : () => _openDispute(provider),
              icon: const Icon(Icons.gavel_outlined),
              label: const Text('Open dispute'),
            ),
            children: const [
              _EmptyLine(
                'Use a dispute for work quality, scope, payment, conduct, '
                'completion, or a late cancellation that needs review.',
              ),
            ],
          )
        else
          _SectionCard(
            title: 'Active dispute',
            children: [
              _RecordTile(
                title: _label(dispute.reasonCode),
                subtitle:
                    '${dispute.summary}\nRequested: ${_label(dispute.requestedOutcome)}',
                status: dispute.status,
                actions: [
                  TextButton.icon(
                    onPressed: provider.isSaving
                        ? null
                        : () => _addDisputeNote(provider, dispute),
                    icon: const Icon(Icons.add_comment_outlined),
                    label: const Text('Add note'),
                  ),
                  if (dispute.openedBy == widget.actorId)
                    TextButton.icon(
                      onPressed: provider.isSaving
                          ? null
                          : () => _withdrawDispute(provider, dispute),
                      icon: const Icon(Icons.undo),
                      label: const Text('Withdraw'),
                    ),
                ],
              ),
              const Divider(height: 26),
              Text(
                'Case history',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              for (final event in toolbox.disputeEvents
                  .where((item) => item.disputeId == dispute.id))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history),
                  title: Text(_label(event.eventType)),
                  subtitle: Text(event.message),
                  trailing: Text(
                    _shortDate(event.createdAt),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
        if (toolbox.disputes.where((item) => !item.isActive).isNotEmpty)
          _SectionCard(
            title: 'Closed cases',
            children: [
              for (final item in toolbox.disputes.where((item) => !item.isActive))
                _RecordTile(
                  title: _label(item.reasonCode),
                  subtitle: item.resolutionNote.isEmpty
                      ? item.summary
                      : item.resolutionNote,
                  status: item.status,
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _proposeSchedule(HdcTransactionToolsProvider provider) async {
    var selected = DateTime.now().add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: selected,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(selected),
    );
    if (time == null || !mounted) return;
    selected = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final note = await _textDialog(
      title: 'Schedule note',
      label: 'Optional note',
      minimum: 0,
      maximum: 1000,
    );
    if (note == null || !mounted) return;
    await _run(
      () => provider.proposeSchedule(
        transactionId: widget.transactionId,
        proposedFor: selected,
        note: note,
      ),
      'Schedule change sent for approval.',
    );
  }

  Future<void> _proposePrice(
    HdcTransactionToolsProvider provider,
    HdcTransactionToolbox toolbox,
  ) async {
    final input = await showDialog<_PriceInput>(
      context: context,
      builder: (_) => _PriceDialog(
        initialTotalMinor: toolbox.authorizedTotalMinor,
      ),
    );
    if (input == null || !mounted) return;
    await _run(
      () => provider.proposeChangeOrder(
        transactionId: widget.transactionId,
        serviceFeeMinor: input.serviceFeeMinor,
        partsCostMinor: input.partsCostMinor,
        reason: input.reason,
      ),
      'Price change sent for customer approval.',
    );
  }

  Future<void> _recordIssue(
    HdcTransactionToolsProvider provider,
    ServiceTransaction transaction,
  ) async {
    final input = await showDialog<_IssueInput>(
      context: context,
      builder: (_) => _IssueDialog(
        role: widget.role,
        cancellationAvailable: ![
          ServiceTransactionStatus.inProgress,
          ServiceTransactionStatus.awaitingCustomerConfirmation,
          ServiceTransactionStatus.disputed,
        ].contains(transaction.status),
      ),
    );
    if (input == null || !mounted) return;
    await _run(
      () => provider.recordException(
        transactionId: widget.transactionId,
        exceptionType: input.type,
        reason: input.reason,
      ),
      input.type == 'cancellation'
          ? 'Service cancelled with a recorded reason.'
          : 'Service issue recorded.',
    );
  }

  Future<void> _recordPayment(
    HdcTransactionToolsProvider provider,
    HdcTransactionToolbox toolbox,
  ) async {
    final input = await showDialog<_PaymentInput>(
      context: context,
      builder: (_) => _PaymentDialog(maximumMinor: toolbox.balanceMinor),
    );
    if (input == null || !mounted) return;
    await _run(
      () => provider.recordPayment(
        transactionId: widget.transactionId,
        amountMinor: input.amountMinor,
        paymentMethod: input.method,
        note: input.note,
        externalReference: input.reference,
      ),
      'Payment recorded for technician confirmation.',
    );
  }

  Future<void> _recordRefund(
    HdcTransactionToolsProvider provider,
    HdcServicePayment payment,
  ) async {
    final value = await _amountDialog(
      title: 'Record refund',
      maximumMinor: payment.remainingRefundableMinor,
    );
    if (value == null || !mounted) return;
    await _run(
      () => provider.updatePayment(
        transactionId: widget.transactionId,
        paymentId: payment.id,
        action: 'recordRefund',
        amountMinor: value,
      ),
      'Refund recorded for customer confirmation.',
    );
  }

  Future<void> _createDocument(
    HdcTransactionToolsProvider provider,
    HdcTransactionToolbox toolbox,
  ) async {
    final input = await showDialog<_DocumentInput>(
      context: context,
      builder: (_) => _DocumentDialog(
        activeDisputeId: toolbox.activeDispute?.id,
      ),
    );
    if (input == null || !mounted) return;
    await _run(
      () => provider.createDocument(
        transactionId: widget.transactionId,
        documentType: input.type,
        title: input.title,
        content: input.content,
        disputeId: input.type == 'disputeEvidence'
            ? toolbox.activeDispute?.id
            : null,
      ),
      'Service document added.',
    );
  }

  Future<void> _openDispute(HdcTransactionToolsProvider provider) async {
    final input = await showDialog<_DisputeInput>(
      context: context,
      builder: (_) => const _DisputeDialog(),
    );
    if (input == null || !mounted) return;
    await _run(
      () => provider.openDispute(
        transactionId: widget.transactionId,
        reasonCode: input.reason,
        summary: input.summary,
        requestedOutcome: input.outcome,
      ),
      'Dispute opened. The service is now frozen for review.',
    );
  }

  Future<void> _addDisputeNote(
    HdcTransactionToolsProvider provider,
    HdcServiceDispute dispute,
  ) async {
    final note = await _textDialog(
      title: 'Add dispute note',
      label: 'Case note',
      minimum: 2,
      maximum: 5000,
    );
    if (note == null || !mounted) return;
    await _run(
      () => provider.updateDispute(
        transactionId: widget.transactionId,
        disputeId: dispute.id,
        action: 'addNote',
        message: note,
      ),
      'Dispute note added.',
    );
  }

  Future<void> _withdrawDispute(
    HdcTransactionToolsProvider provider,
    HdcServiceDispute dispute,
  ) async {
    final reason = await _textDialog(
      title: 'Withdraw dispute',
      label: 'Reason for withdrawal',
      minimum: 5,
      maximum: 5000,
    );
    if (reason == null || !mounted) return;
    await _run(
      () => provider.updateDispute(
        transactionId: widget.transactionId,
        disputeId: dispute.id,
        action: 'withdraw',
        message: reason,
      ),
      'Dispute withdrawn and previous service status restored.',
    );
  }

  Future<String?> _textDialog({
    required String title,
    required String label,
    required int minimum,
    required int maximum,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => _TextEntryDialog(
        title: title,
        label: label,
        minimum: minimum,
        maximum: maximum,
      ),
    );
  }

  Future<int?> _amountDialog({
    required String title,
    required int maximumMinor,
  }) {
    return showDialog<int>(
      context: context,
      builder: (_) => _AmountDialog(
        title: title,
        maximumMinor: maximumMinor,
      ),
    );
  }
}

class _ToolList extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final List<Widget> children;

  const _ToolList({required this.onRefresh, required this.children});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < children.length; index++) ...[
                    children[index],
                    if (index != children.length - 1)
                      const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolIntro extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final bool warning;

  const _ToolIntro({
    required this.icon,
    required this.title,
    required this.message,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = warning ? HDCColors.warning : HDCColors.secondary;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(message, style: const TextStyle(height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget? action;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children, this.action});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                if (action != null) action!,
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String status;
  final List<Widget> actions;

  const _RecordTile({
    required this.title,
    required this.subtitle,
    required this.status,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: HDCColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HDCColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              Chip(label: Text(_label(status))),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(color: HDCColors.textSecondary, height: 1.4),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final HdcServicePayment payment;
  final List<HdcPaymentEvent> events;
  final String actorId;
  final ServiceTransactionParticipantRole role;
  final bool saving;
  final bool frozen;
  final void Function(String action, int? amountMinor) onAction;
  final VoidCallback onRefund;

  const _PaymentTile({
    required this.payment,
    required this.events,
    required this.actorId,
    required this.role,
    required this.saving,
    required this.frozen,
    required this.onAction,
    required this.onRefund,
  });

  @override
  Widget build(BuildContext context) {
    final pendingRefunds = events.where((event) {
      if (event.eventType != 'refundRecorded') return false;
      return !events.any(
        (candidate) => candidate.eventType == 'refundConfirmed' &&
            candidate.relatedEventId == event.id,
      );
    }).toList(growable: false);
    final actions = <Widget>[];
    if (role == ServiceTransactionParticipantRole.technician &&
        payment.status == 'recorded') {
      actions.addAll([
        TextButton(
          onPressed: saving || frozen ? null : () => onAction('reject', null),
          child: const Text('Reject'),
        ),
        FilledButton(
          onPressed:
              saving || frozen ? null : () => onAction('confirm', null),
          child: const Text('Confirm received'),
        ),
      ]);
    }
    if (role == ServiceTransactionParticipantRole.customer &&
        payment.status == 'recorded' &&
        payment.recordedBy == actorId) {
      actions.add(
        TextButton(
          onPressed: saving || frozen
              ? null
              : () => onAction('cancel', null),
          child: const Text('Cancel record'),
        ),
      );
    }
    if (role == ServiceTransactionParticipantRole.technician &&
        ['confirmed', 'partiallyRefunded'].contains(payment.status) &&
        payment.remainingRefundableMinor > 0 &&
        pendingRefunds.isEmpty) {
      actions.add(
        TextButton(
          onPressed: saving || frozen ? null : onRefund,
          child: const Text('Record refund'),
        ),
      );
    }
    if (role == ServiceTransactionParticipantRole.customer &&
        pendingRefunds.isNotEmpty) {
      final amount = pendingRefunds.last.amountMinor;
      actions.add(
        FilledButton.tonal(
          onPressed: saving || frozen || amount == null
              ? null
              : () => onAction('confirmRefund', amount),
          child: Text(
            amount == null
                ? 'Confirm refund'
                : 'Confirm refund ${_money(amount, payment.currency)}',
          ),
        ),
      );
    }
    return _RecordTile(
      title: _money(payment.amountMinor, payment.currency),
      subtitle:
          '${_label(payment.paymentMethod)} • ${_dateTime(payment.createdAt)}'
          '${payment.note.isEmpty ? '' : '\n${payment.note}'}',
      status: payment.status,
      actions: actions,
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final HdcServiceDocument document;
  final bool canRemove;
  final bool saving;
  final VoidCallback onRemove;

  const _DocumentTile({
    required this.document,
    required this.canRemove,
    required this.saving,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(document.title),
      subtitle: Text(
        '${_label(document.documentType)} • ${document.byteSize} bytes • '
        '${_shortDate(document.createdAt)}',
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SelectableText(document.content),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Integrity: ${document.contentSha256.substring(0, 12)}…',
            style: const TextStyle(fontSize: 11, color: HDCColors.textSecondary),
          ),
        ),
        if (canRemove)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: saving ? null : onRemove,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove'),
            ),
          ),
      ],
    );
  }
}

class _MoneySummary extends StatelessWidget {
  final String label;
  final int amountMinor;
  final String currency;
  final bool strong;

  const _MoneySummary({
    required this.label,
    required this.amountMinor,
    required this.currency,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            _money(amountMinor, currency),
            style: TextStyle(
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
              fontSize: strong ? 17 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  final String message;
  const _EmptyLine(this.message);

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: const TextStyle(color: HDCColors.textSecondary, height: 1.4),
    );
  }
}

class _HistoryLine extends StatelessWidget {
  final String message;
  const _HistoryLine(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        message,
        style: const TextStyle(color: HDCColors.textSecondary, fontSize: 12),
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  final Object? error;
  final bool backendAvailable;
  final Future<void> Function() onRetry;

  const _LoadFailure({
    required this.error,
    required this.backendAvailable,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 56),
            const SizedBox(height: 12),
            Text(
              backendAvailable
                  ? 'Service tools could not be loaded.'
                  : 'Service tools require the HDC API.',
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text('$error', textAlign: TextAlign.center),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextEntryDialog extends StatefulWidget {
  final String title;
  final String label;
  final int minimum;
  final int maximum;

  const _TextEntryDialog({
    required this.title,
    required this.label,
    required this.minimum,
    required this.maximum,
  });

  @override
  State<_TextEntryDialog> createState() => _TextEntryDialogState();
}

class _TextEntryDialogState extends State<_TextEntryDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: controller,
        minLines: 3,
        maxLines: 8,
        maxLength: widget.maximum,
        decoration: InputDecoration(labelText: widget.label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();
            if (value.length < widget.minimum) return;
            Navigator.of(context).pop(value);
          },
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _AmountDialog extends StatefulWidget {
  final String title;
  final int maximumMinor;

  const _AmountDialog({required this.title, required this.maximumMinor});

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(
      text: (widget.maximumMinor / 100).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Amount in PHP',
          helperText: 'Maximum ${_money(widget.maximumMinor, 'PHP')}',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final amount = double.tryParse(controller.text.trim());
            final minor = amount == null ? 0 : (amount * 100).round();
            if (minor <= 0 || minor > widget.maximumMinor) return;
            Navigator.of(context).pop(minor);
          },
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _PriceInput {
  final int serviceFeeMinor;
  final int partsCostMinor;
  final String reason;
  const _PriceInput(this.serviceFeeMinor, this.partsCostMinor, this.reason);
}

class _PriceDialog extends StatefulWidget {
  final int initialTotalMinor;
  const _PriceDialog({required this.initialTotalMinor});

  @override
  State<_PriceDialog> createState() => _PriceDialogState();
}

class _PriceDialogState extends State<_PriceDialog> {
  late final TextEditingController service;
  final parts = TextEditingController(text: '0.00');
  final reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    service = TextEditingController(
      text: (widget.initialTotalMinor / 100).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    service.dispose();
    parts.dispose();
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Propose revised price'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: service,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Service fee (PHP)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: parts,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Parts cost (PHP)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              maxLength: 2000,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final fee = double.tryParse(service.text.trim());
            final part = double.tryParse(parts.text.trim());
            final explanation = reason.text.trim();
            if (fee == null || part == null || fee < 0 || part < 0 ||
                fee + part <= 0 || explanation.length < 5) {
              return;
            }
            Navigator.of(context).pop(
              _PriceInput((fee * 100).round(), (part * 100).round(), explanation),
            );
          },
          child: const Text('Send for approval'),
        ),
      ],
    );
  }
}

class _IssueInput {
  final String type;
  final String reason;
  const _IssueInput(this.type, this.reason);
}

class _IssueDialog extends StatefulWidget {
  final ServiceTransactionParticipantRole role;
  final bool cancellationAvailable;
  const _IssueDialog({required this.role, required this.cancellationAvailable});

  @override
  State<_IssueDialog> createState() => _IssueDialogState();
}

class _IssueDialogState extends State<_IssueDialog> {
  late String type;
  final reason = TextEditingController();

  List<String> get types => [
        if (widget.cancellationAvailable) 'cancellation',
        if (widget.role == ServiceTransactionParticipantRole.customer)
          'technicianNoShow',
        if (widget.role == ServiceTransactionParticipantRole.technician) ...[
          'customerNoShow',
          'customerNonResponse',
        ],
        'other',
      ];

  @override
  void initState() {
    super.initState();
    type = types.first;
  }

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record service issue'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: type,
              items: types
                  .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text(_label(value)),
                      ))
                  .toList(growable: false),
              onChanged: (value) => setState(() => type = value ?? type),
              decoration: const InputDecoration(labelText: 'Issue type'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              minLines: 3,
              maxLines: 7,
              maxLength: 2000,
              decoration: const InputDecoration(labelText: 'What happened?'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final text = reason.text.trim();
            final minimum = type.contains('NoShow') ||
                    type == 'customerNonResponse'
                ? 20
                : 5;
            if (text.length < minimum) return;
            Navigator.pop(context, _IssueInput(type, text));
          },
          child: const Text('Record'),
        ),
      ],
    );
  }
}

class _PaymentInput {
  final int amountMinor;
  final String method;
  final String note;
  final String? reference;
  const _PaymentInput(this.amountMinor, this.method, this.note, this.reference);
}

class _PaymentDialog extends StatefulWidget {
  final int maximumMinor;
  const _PaymentDialog({required this.maximumMinor});

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final TextEditingController amount;
  final note = TextEditingController();
  final reference = TextEditingController();
  String method = 'cash';

  @override
  void initState() {
    super.initState();
    amount = TextEditingController(
      text: (widget.maximumMinor / 100).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const methods = ['cash', 'bankTransfer', 'eWallet', 'cardExternal', 'other'];
    return AlertDialog(
      title: const Text('Record external payment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Record only after you have paid outside HDC. The technician '
              'must independently confirm receipt.',
              style: TextStyle(color: HDCColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount (PHP)',
                helperText: 'Maximum ${_money(widget.maximumMinor, 'PHP')}',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: method,
              items: methods
                  .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text(_label(value)),
                      ))
                  .toList(growable: false),
              onChanged: (value) => setState(() => method = value ?? method),
              decoration: const InputDecoration(labelText: 'Payment method'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reference,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'External reference (optional)',
              ),
            ),
            TextField(
              controller: note,
              maxLength: 2000,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final major = double.tryParse(amount.text.trim());
            final minor = major == null ? 0 : (major * 100).round();
            if (minor <= 0 || minor > widget.maximumMinor) return;
            Navigator.pop(
              context,
              _PaymentInput(
                minor,
                method,
                note.text.trim(),
                reference.text.trim().isEmpty ? null : reference.text.trim(),
              ),
            );
          },
          child: const Text('Record payment'),
        ),
      ],
    );
  }
}

class _DocumentInput {
  final String type;
  final String title;
  final String content;
  const _DocumentInput(this.type, this.title, this.content);
}

class _DocumentDialog extends StatefulWidget {
  final String? activeDisputeId;
  const _DocumentDialog({this.activeDisputeId});

  @override
  State<_DocumentDialog> createState() => _DocumentDialogState();
}

class _DocumentDialogState extends State<_DocumentDialog> {
  String type = 'serviceReport';
  final title = TextEditingController();
  final content = TextEditingController();

  @override
  void dispose() {
    title.dispose();
    content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final types = [
      'serviceReport',
      'warranty',
      'paymentEvidence',
      'receiptNote',
      if (widget.activeDisputeId != null) 'disputeEvidence',
      'other',
    ];
    return AlertDialog(
      title: const Text('New structured document'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: type,
                items: types
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(_label(value)),
                        ))
                    .toList(growable: false),
                onChanged: (value) => setState(() => type = value ?? type),
                decoration: const InputDecoration(labelText: 'Document type'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: title,
                maxLength: 160,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: content,
                minLines: 5,
                maxLines: 12,
                maxLength: 20000,
                decoration: const InputDecoration(labelText: 'Document text'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final heading = title.text.trim();
            final body = content.text.trim();
            if (heading.length < 3 || body.length < 2) return;
            Navigator.pop(context, _DocumentInput(type, heading, body));
          },
          child: const Text('Add document'),
        ),
      ],
    );
  }
}

class _DisputeInput {
  final String reason;
  final String summary;
  final String outcome;
  const _DisputeInput(this.reason, this.summary, this.outcome);
}

class _DisputeDialog extends StatefulWidget {
  const _DisputeDialog();

  @override
  State<_DisputeDialog> createState() => _DisputeDialogState();
}

class _DisputeDialogState extends State<_DisputeDialog> {
  String reason = 'workQuality';
  String outcome = 'continueService';
  final summary = TextEditingController();

  @override
  void dispose() {
    summary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const reasons = [
      'workQuality', 'scopeOrPrice', 'payment', 'noShow',
      'conductOrSafety', 'completion', 'other',
    ];
    const outcomes = [
      'continueService', 'cancelService', 'partialRefund', 'fullRefund', 'other',
    ];
    return AlertDialog(
      title: const Text('Open service dispute'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This immediately freezes service and payment changes until '
                'the case is withdrawn or resolved.',
                style: TextStyle(color: HDCColors.textSecondary),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: reason,
                items: reasons
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(_label(value)),
                        ))
                    .toList(growable: false),
                onChanged: (value) => setState(() => reason = value ?? reason),
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: outcome,
                items: outcomes
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(_label(value)),
                        ))
                    .toList(growable: false),
                onChanged: (value) => setState(() => outcome = value ?? outcome),
                decoration: const InputDecoration(labelText: 'Requested outcome'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: summary,
                minLines: 4,
                maxLines: 10,
                maxLength: 5000,
                decoration: const InputDecoration(
                  labelText: 'Explain the issue (minimum 20 characters)',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final text = summary.text.trim();
            if (text.length < 20) return;
            Navigator.pop(context, _DisputeInput(reason, text, outcome));
          },
          child: const Text('Open and freeze service'),
        ),
      ],
    );
  }
}

String _money(int minor, String currency) =>
    '$currency ${(minor / 100).toStringAsFixed(2)}';

String _dateTime(DateTime value) {
  final local = value.toLocal();
  return '${local.month}/${local.day}/${local.year} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String _shortDate(DateTime value) {
  final local = value.toLocal();
  return '${local.month}/${local.day}/${local.year}';
}

String _label(String value) {
  final spaced = value.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  if (spaced.isEmpty) return spaced;
  return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
}

String _paymentSuccess(String action) => switch (action) {
      'confirm' => 'Payment confirmed and receipt issued.',
      'reject' => 'Payment record rejected.',
      'cancel' => 'Pending payment record cancelled.',
      'confirmRefund' => 'Refund confirmed and receipt issued.',
      _ => 'Payment record updated.',
    };
