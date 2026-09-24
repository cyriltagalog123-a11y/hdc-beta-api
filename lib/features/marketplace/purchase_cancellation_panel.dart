import 'package:flutter/material.dart';

import '../../models/marketplace_purchase.dart';

class PurchaseCancellationPanel extends StatelessWidget {
  final ProductPurchaseRequest request;
  final bool isBuyer;
  final bool isSaving;
  final Future<void> Function(String action, String note) onAction;

  const PurchaseCancellationPanel({super.key, required this.request,
    required this.isBuyer, required this.isSaving, required this.onAction});

  Future<void> _request(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Request cancellation?'),
        content: Form(key: formKey, child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('The other participant must agree before stock is restored. '
                'This request does not process a payment or refund.'),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller, maxLength: 500, minLines: 2, maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Reason (shared with the other participant)',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value?.trim().length ?? 0) < 10
                  ? 'Enter at least 10 characters.' : null,
            ),
          ]),
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Keep Order')),
          FilledButton(onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(dialogContext, controller.text.trim());
            }
          }, child: const Text('Send Request')),
        ],
      ),
    );
    controller.dispose();
    if (reason != null && context.mounted) await onAction('request', reason);
  }

  Future<void> _respond(BuildContext context, String action) async {
    final controller = TextEditingController();
    final agreed = action == 'approve';
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(agreed ? 'Agree to cancel?' : 'Keep this order?'),
        content: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reason: ${request.cancellationReason ?? ''}'),
            const SizedBox(height: 10),
            Text(agreed
                ? 'Approval closes this order and restores its allocated stock once. '
                  'A sold-out listing becomes paused until its seller republishes it. '
                  'Any external payment or refund still needs separate resolution.'
                : 'Declining leaves this accepted order and its stock allocation in place.'),
            const SizedBox(height: 12),
            TextField(controller: controller, minLines: 2, maxLines: 4,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Response (optional)', border: OutlineInputBorder(),
              )),
          ],
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Back')),
          FilledButton(onPressed: () => Navigator.pop(
            dialogContext, controller.text.trim()),
            child: Text(agreed ? 'Agree & Restore Stock' : 'Decline Cancellation')),
        ],
      ),
    );
    controller.dispose();
    if (note != null && context.mounted) await onAction(action, note);
  }

  @override
  Widget build(BuildContext context) {
    if (request.stockReleasedAt != null) {
      return const Text('Cancellation agreed. Allocated stock was restored; '
          'external payment or refund remains separate.');
    }
    if (request.status != ProductPurchaseStatus.accepted) {
      return const SizedBox.shrink();
    }
    final requestedBy = request.cancellationRequestedBy;
    if (requestedBy == null) {
      return OutlinedButton.icon(
        onPressed: isSaving ? null : () => _request(context),
        icon: const Icon(Icons.assignment_return_outlined),
        label: const Text('Request Cancellation'),
      );
    }
    final mine = requestedBy == (isBuyer ? 'buyer' : 'seller');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Cancellation requested by ${mine ? 'you' : 'the other participant'}.',
          style: const TextStyle(fontWeight: FontWeight.w700)),
      if (request.cancellationReason != null)
        Text('Reason: ${request.cancellationReason}'),
      if (mine)
        const Text('The order remains accepted until the other participant responds.'),
      if (!mine) ...[
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton(onPressed: isSaving ? null : () => _respond(context, 'approve'),
              child: const Text('Agree & Restore Stock')),
          OutlinedButton(onPressed: isSaving ? null : () => _respond(context, 'decline'),
              child: const Text('Keep Order')),
        ]),
      ],
    ]);
  }
}
