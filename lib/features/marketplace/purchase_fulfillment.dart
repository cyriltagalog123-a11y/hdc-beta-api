import 'package:flutter/material.dart';

import '../../models/marketplace_purchase.dart';

class PurchaseFulfillment extends StatelessWidget {
  final ProductPurchaseRequest request;

  const PurchaseFulfillment({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final proposal = request.fulfillment;
    if (proposal == null) {
      return const Text('Fulfillment terms were not recorded for this earlier request.');
    }
    final agreed = request.status == ProductPurchaseStatus.accepted ||
        request.status == ProductPurchaseStatus.fulfilled ||
        request.status == ProductPurchaseStatus.completed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(agreed ? 'Accepted fulfillment terms' : 'Proposed fulfillment terms',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        Text('${proposal.methodLabel} • ${proposal.location}'),
        Text('Time: ${proposal.timing}'),
        Text('Fulfillment fee: ${request.fulfillmentFeeLabel} • '
            '${agreed ? 'Agreed' : 'Proposed'} total: ${request.proposedTotalLabel}'),
      ],
    );
  }
}
