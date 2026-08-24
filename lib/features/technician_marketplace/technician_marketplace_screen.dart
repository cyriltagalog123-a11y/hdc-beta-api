import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/hdc_page_route.dart';
import '../../core/ui/hdc_colors.dart';
import '../../models/account_identity.dart';
import '../../models/proposal.dart';
import '../../models/proposal_request_summary.dart';
import '../../models/service_request.dart';
import '../../models/service_transaction.dart';
import '../../providers/hdc_auth_provider.dart';
import '../../providers/proposal_provider.dart';
import '../../providers/service_request_provider.dart';
import '../../providers/technician_marketplace_provider.dart';
import '../transactions/my_transactions_screen.dart';
import 'technician_request_details_screen.dart';

class TechnicianMarketplaceScreen extends StatefulWidget {
  const TechnicianMarketplaceScreen({super.key});

  @override
  State<TechnicianMarketplaceScreen> createState() =>
      _TechnicianMarketplaceScreenState();
}

class _TechnicianMarketplaceScreenState
    extends State<TechnicianMarketplaceScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ServiceRequest> _allRequests(BuildContext context) {
    final liveRequests = context
        .watch<ServiceRequestProvider>()
        .requests
        .where((request) => request.status.acceptsProposals)
        .toList(growable: false);
    return liveRequests;
  }

  Future<void> _openFilters(
    BuildContext context,
    List<String> categories,
  ) async {
    final provider = context.read<TechnicianMarketplaceProvider>();
    var selectedCategory = provider.category;
    var selectedUrgency = provider.urgency;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                22,
                4,
                22,
                22 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter opportunities',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Service category',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All categories'),
                      ),
                      ...categories.map(
                        (category) => DropdownMenuItem<String?>(
                          value: category,
                          child: Text(category),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setSheetState(() => selectedCategory = value);
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<ServiceRequestUrgency?>(
                    initialValue: selectedUrgency,
                    decoration: const InputDecoration(
                      labelText: 'Urgency',
                      prefixIcon: Icon(Icons.priority_high_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<ServiceRequestUrgency?>(
                        value: null,
                        child: Text('All urgency levels'),
                      ),
                      ...ServiceRequestUrgency.values.map(
                        (urgency) => DropdownMenuItem<ServiceRequestUrgency?>(
                          value: urgency,
                          child: Text(urgency.label),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setSheetState(() => selectedUrgency = value);
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            selectedCategory = null;
                            selectedUrgency = null;
                            provider
                              ..setCategory(null)
                              ..setUrgency(null);
                            Navigator.of(sheetContext).pop();
                          },
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            provider
                              ..setCategory(selectedCategory)
                              ..setUrgency(selectedUrgency);
                            Navigator.of(sheetContext).pop();
                          },
                          child: const Text('Apply Filters'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<HDCAuthProvider>();
    final identity = auth.identity;
    final canAccess = auth.authenticated &&
        identity != null &&
        identity.hasPlatformRole(HDCPlatformRole.technician);

    if (!canAccess) {
      return const _TechnicianAccessDenied();
    }

    final technicianId = identity.id;
    final marketplace = context.watch<TechnicianMarketplaceProvider>();
    final proposalProvider = context.watch<ProposalProvider>();
    final allRequests = _allRequests(context);
    final requests = marketplace.applyFilters(allRequests);
    final categories = allRequests
        .map((request) => request.categoryName)
        .toSet()
        .toList(growable: false)
      ..sort();

    return Scaffold(
      backgroundColor: HDCColors.background,
      appBar: AppBar(
        title: const Text('Technician Marketplace'),
        actions: [
          IconButton(
            tooltip: 'My Technician Jobs',
            onPressed: () {
              Navigator.of(context).push(
                HDCPageRoute<void>(
                  page: MyTransactionsScreen(
                    role: ServiceTransactionParticipantRole.technician,
                    actorId: technicianId,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.work_outline),
          ),
          IconButton(
            tooltip: marketplace.savedOnly
                ? 'Show all opportunities'
                : 'Show saved opportunities',
            onPressed: () => marketplace.setSavedOnly(!marketplace.savedOnly),
            icon: Badge(
              isLabelVisible: marketplace.savedCount > 0,
              label: Text('${marketplace.savedCount}'),
              child: Icon(
                marketplace.savedOnly
                    ? Icons.bookmark
                    : Icons.bookmark_border,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: marketplace.isLoading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding = constraints.maxWidth >= 900
                      ? 32.0
                      : 18.0;
                  return CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          24,
                          horizontalPadding,
                          12,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1180),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(22),
                                    decoration: BoxDecoration(
                                      color: HDCColors.primary,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Find your next service job',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        SizedBox(height: 7),
                                        Text(
                                          'Browse open customer requests, save '
                                          'good matches, and prepare to send an '
                                          'offer.',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            height: 1.45,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _searchController,
                                          onChanged: marketplace.setQuery,
                                          decoration: InputDecoration(
                                            hintText:
                                                'Search service, location, or keyword',
                                            prefixIcon:
                                                const Icon(Icons.search),
                                            suffixIcon: marketplace.query.isEmpty
                                                ? null
                                                : IconButton(
                                                    tooltip: 'Clear search',
                                                    onPressed: () {
                                                      _searchController.clear();
                                                      marketplace.setQuery('');
                                                    },
                                                    icon: const Icon(Icons.close),
                                                  ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      IconButton.filledTonal(
                                        tooltip: 'Filters',
                                        onPressed: () =>
                                            _openFilters(context, categories),
                                        icon: Badge(
                                          isLabelVisible:
                                              marketplace.category != null ||
                                                  marketplace.urgency != null,
                                          child: const Icon(Icons.tune),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          requests.length == 1
                                              ? '1 opportunity found'
                                              : '${requests.length} opportunities found',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      if (marketplace.hasActiveFilters)
                                        TextButton.icon(
                                          onPressed: () {
                                            _searchController.clear();
                                            marketplace.clearFilters();
                                          },
                                          icon: const Icon(Icons.restart_alt),
                                          label: const Text('Clear'),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (requests.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyMarketplace(
                            savedOnly: marketplace.savedOnly,
                            onClear: () {
                              _searchController.clear();
                              marketplace.clearFilters();
                            },
                          ),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            4,
                            horizontalPadding,
                            28,
                          ),
                          sliver: SliverLayoutBuilder(
                            builder: (context, constraints) {
                              final crossAxisCount =
                                  constraints.crossAxisExtent >= 980
                                      ? 3
                                      : constraints.crossAxisExtent >= 650
                                          ? 2
                                          : 1;
                              return SliverGrid(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  mainAxisExtent: 340,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final request = requests[index];
                                    return _OpportunityCard(
                                      request: request,
                                      summary: proposalProvider
                                          .summaryForRequest(request.id),
                                      ownProposal: proposalProvider
                                          .latestForTechnicianRequest(
                                        technicianId: technicianId,
                                        requestId: request.id,
                                      ),
                                      isSaved:
                                          marketplace.isSaved(request.id),
                                      onSave: () =>
                                          marketplace.toggleSaved(request.id),
                                      onOpen: () {
                                        Navigator.of(context).push(
                                          HDCPageRoute<void>(
                                            page:
                                                TechnicianRequestDetailsScreen(
                                              request: request,
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                  childCount: requests.length,
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _TechnicianAccessDenied extends StatelessWidget {
  const _TechnicianAccessDenied();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Technician Marketplace'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_person_outlined,
                  size: 58,
                  color: HDCColors.warning,
                ),
                SizedBox(height: 18),
                Text(
                  'Registered Technician Required',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Only authenticated HDC accounts with an active Technician '
                  'role can browse customer service opportunities or submit '
                  'professional proposals.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: HDCColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  final ServiceRequest request;
  final ProposalRequestSummary summary;
  final Proposal? ownProposal;
  final bool isSaved;
  final VoidCallback onSave;
  final VoidCallback onOpen;

  const _OpportunityCard({
    required this.request,
    required this.summary,
    required this.ownProposal,
    required this.isSaved,
    required this.onSave,
    required this.onOpen,
  });

  int get _displayProposalCount {
    if (summary.received > 0) return summary.received;
    if (request.id.startsWith('SR-MKT-')) return request.offerCount;
    return 0;
  }

  String get _marketplaceProposalLabel {
    if (summary.received > 0) return summary.technicianMarketplaceLabel;
    if (_displayProposalCount > 0) {
      return '$_displayProposalCount proposal${_displayProposalCount == 1 ? '' : 's'} submitted';
    }
    return summary.technicianMarketplaceLabel;
  }

  @override
  Widget build(BuildContext context) {
    final urgent = request.urgency == ServiceRequestUrgency.urgent ||
        request.urgency == ServiceRequestUrgency.emergency;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: (urgent ? HDCColors.danger : HDCColors.secondary)
                          .withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      request.urgency.label,
                      style: TextStyle(
                        color: urgent
                            ? HDCColors.danger
                            : HDCColors.secondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: isSaved ? 'Remove from saved' : 'Save request',
                    visualDensity: VisualDensity.compact,
                    onPressed: onSave,
                    icon: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                request.categoryName,
                style: const TextStyle(
                  color: HDCColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                request.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 11),
              _CompactInfo(
                icon: Icons.location_on_outlined,
                text: request.location,
              ),
              const SizedBox(height: 7),
              _CompactInfo(
                icon: Icons.payments_outlined,
                text: request.budgetLabel,
              ),
              const SizedBox(height: 7),
              _CompactInfo(
                icon: Icons.local_offer_outlined,
                text: _marketplaceProposalLabel,
              ),
              if (ownProposal != null) ...[
                const SizedBox(height: 7),
                _CompactInfo(
                  icon: Icons.description_outlined,
                  text: 'Your proposal: ${ownProposal!.status.label}',
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('View Opportunity'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const _CompactInfo({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: HDCColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: HDCColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyMarketplace extends StatelessWidget {
  final bool savedOnly;
  final VoidCallback onClear;

  const _EmptyMarketplace({
    required this.savedOnly,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              savedOnly ? Icons.bookmark_border : Icons.search_off,
              size: 54,
              color: HDCColors.textSecondary,
            ),
            const SizedBox(height: 14),
            Text(
              savedOnly ? 'No saved opportunities yet' : 'No matching requests',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              savedOnly
                  ? 'Save promising requests so you can return to them later.'
                  : 'Try a different search term or clear the active filters.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: HDCColors.textSecondary),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Show All Requests'),
            ),
          ],
        ),
      ),
    );
  }
}
