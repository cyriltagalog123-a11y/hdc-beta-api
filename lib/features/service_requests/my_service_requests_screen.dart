import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/hdc_page_route.dart';
import '../../core/ui/hdc_colors.dart';
import '../../models/service_request.dart';
import '../../models/service_transaction.dart';
import '../../providers/proposal_provider.dart';
import '../../providers/service_request_provider.dart';
import '../../providers/service_transaction_provider.dart';
import 'create_service_request_screen.dart';
import 'service_request_details_screen.dart';

class MyServiceRequestsScreen extends StatelessWidget {
  const MyServiceRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ServiceRequestProvider>();
    final requests = provider.requests;

    return Scaffold(
      appBar: AppBar(title: const Text('My Service Requests')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            HDCPageRoute<void>(
              page: const CreateServiceRequestScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Request'),
      ),
      body: provider.isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : provider.lastError != null && requests.isEmpty
              ? _LoadError(
                  onRetry: provider.initialize,
                )
              : requests.isEmpty
                  ? const _EmptyRequests()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        20,
                        20,
                        100,
                      ),
                      itemCount: requests.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final request = requests[index];

                        return _RequestCard(
                          request: request,
                        );
                      },
                    ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _LoadError({
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
            const Icon(
              Icons.cloud_off_outlined,
              size: 52,
              color: HDCColors.danger,
            ),
            const SizedBox(height: 16),
            const Text(
              'Service requests could not be loaded.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                'Try Again',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRequests extends StatelessWidget {
  const _EmptyRequests();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 460,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: HDCColors.secondary.withValues(
                    alpha: 0.10,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.campaign_outlined,
                  size: 46,
                  color: HDCColors.secondary,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'No service requests yet',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium,
              ),
              const SizedBox(height: 10),
              const Text(
                'Create a request to describe the work you need and prepare '
                'it for the HDC technician marketplace.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: HDCColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    HDCPageRoute<void>(
                      page:
                          const CreateServiceRequestScreen(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.add_task,
                ),
                label: const Text(
                  'Post First Request',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final ServiceRequest request;

  const _RequestCard({
    required this.request,
  });

  @override
  Widget build(BuildContext context) {
    final summary = context
        .watch<ProposalProvider>()
        .summaryForRequest(
          request.id,
        );

    final transaction = context
        .watch<ServiceTransactionProvider>()
        .forRequest(
          request.id,
        );

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            HDCPageRoute<void>(
              page: ServiceRequestDetailsScreen(
                requestId: request.id,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: HDCColors.secondary.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.home_repair_service_outlined,
                  color: HDCColors.secondary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            request.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _CompactStatus(
                          status: request.status,
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${request.categoryName} • '
                      '${request.location}',
                      style: const TextStyle(
                        color:
                            HDCColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 14,
                      runSpacing: 8,
                      children: [
                        _Meta(
                          icon:
                              Icons.local_offer_outlined,
                          label:
                              '${summary.received} proposals',
                        ),
                        if (summary.viewedOrBeyond > 0)
                          _Meta(
                            icon:
                                Icons.visibility_outlined,
                            label:
                                '${summary.viewedOrBeyond} viewed',
                          ),
                        if (summary.shortlisted > 0)
                          _Meta(
                            icon:
                                Icons.favorite_outline,
                            label:
                                '${summary.shortlisted} shortlisted',
                          ),
                        if (transaction != null)
                          _Meta(
                            icon:
                                Icons.handshake_outlined,
                            label:
                                transaction.status.label,
                          ),
                        _Meta(
                          icon:
                              Icons.payments_outlined,
                          label:
                              request.budgetLabel,
                        ),
                        _Meta(
                          icon:
                              Icons.priority_high,
                          label:
                              request.urgency.label,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactStatus extends StatelessWidget {
  final ServiceRequestStatus status;

  const _CompactStatus({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        status == ServiceRequestStatus.cancelled
            ? HDCColors.danger
            : HDCColors.success;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.10,
        ),
        borderRadius:
            BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Meta({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color: HDCColors.textSecondary,
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: HDCColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}