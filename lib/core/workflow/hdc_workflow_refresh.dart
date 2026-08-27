import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../providers/hdc_workflow_sync_provider.dart';
import '../../providers/proposal_provider.dart';
import '../../providers/service_request_provider.dart';
import '../../providers/service_transaction_provider.dart';

Future<void> refreshHdcWorkflow(BuildContext context) async {
  final sync = Provider.of<HdcWorkflowSyncProvider?>(
    context,
    listen: false,
  );
  if (sync != null) {
    await sync.refresh();
    return;
  }

  await context.read<ServiceRequestProvider>().refresh();
  if (!context.mounted) return;
  context.read<ProposalProvider>().refreshFromRepository();
  context.read<ServiceTransactionProvider>().refreshFromRepository();
}
