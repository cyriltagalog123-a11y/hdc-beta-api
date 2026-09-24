import 'package:flutter/material.dart';

import '../../models/marketplace_purchase.dart';

class PurchaseTimeline extends StatelessWidget {
  final ProductPurchaseRequest request;

  const PurchaseTimeline({required this.request, super.key});

  @override
  Widget build(BuildContext context) {
    if (request.events.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      key: ValueKey('purchase-history-${request.id}'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: const Text('Recorded history'),
      subtitle: Text('${request.events.length} recorded update(s)'),
      children: request.events.map((event) {
        final time = event.occurredAt.toLocal().toString().split('.').first;
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.history_outlined, size: 20),
          title: Text(event.typeLabel),
          subtitle: Text(
            event.note.isEmpty ? time : '$time\n${event.note}',
          ),
        );
      }).toList(growable: false),
    );
  }
}
