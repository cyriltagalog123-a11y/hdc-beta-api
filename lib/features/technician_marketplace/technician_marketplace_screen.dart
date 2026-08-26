import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/maps/hdc_map_launcher.dart';
import '../../core/navigation/hdc_page_route.dart';
import '../../core/ui/hdc_colors.dart';
import '../../models/account_identity.dart';
import '../../models/proposal.dart';
import '../../models/proposal_request_summary.dart';
import '../../models/service_request.dart';
import '../../models/service_transaction.dart';
import '../../providers/hdc_auth_provider.dart';
import '../../providers/hdc_profile_provider.dart';
import '../../providers/proposal_provider.dart';
import '../../providers/technician_discovery_provider.dart';
import '../../providers/technician_marketplace_provider.dart';
import '../profiles/profile_center_screen.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refreshMarketplace());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshMarketplace() async {
    final discovery = context.read<TechnicianDiscoveryProvider>();
    final profiles = context.read<HdcProfileProvider>();
    await Future.wait<void>([
      discovery.refreshOpportunities(),
      profiles.refresh(),
    ]);
    if (!mounted || discovery.opportunitiesError == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('HDC could not refresh opportunities. Try again.'),
      ),
    );
  }

  Future<void> _openMap(String serviceArea) async {
    final opened = await HdcMapLauncher.openServiceArea(serviceArea);
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('A map app could not be opened on this device.'),
      ),
    );
  }

  String _technicianLocation(HdcProfileProvider profiles) {
    final roleLocation = profiles
        .profileFor(HDCPlatformRole.technician)
        ?.location
        .trim();
    if (roleLocation != null && roleLocation.isNotEmpty) return roleLocation;
    return profiles.memberProfile?.location.trim() ?? '';
  }

  String _lastUpdatedLabel(DateTime? value) {
    if (value == null) return 'Not refreshed yet';
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return 'Last updated $hour:$minute';
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
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
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
    final canAccess =
        auth.authenticated &&
        identity != null &&
        identity.hasPlatformRole(HDCPlatformRole.technician);

    if (!canAccess) {
      return const _TechnicianAccessDenied();
    }

    final technicianId = identity.id;
    final marketplace = context.watch<TechnicianMarketplaceProvider>();
    final proposalProvider = context.watch<ProposalProvider>();
    final discovery = context.watch<TechnicianDiscoveryProvider>();
    final profiles = context.watch<HdcProfileProvider>();
    final technicianLocation = _technicianLocation(profiles);
    final allRequests = discovery.opportunities;
    final requests = marketplace.applyFilters(
      allRequests,
      technicianId: technicianId,
      technicianLocation: technicianLocation,
    );
    final categories =
        allRequests
            .map((request) => request.categoryName)
            .toSet()
            .toList(growable: false)
          ..sort();

    return Scaffold(
      backgroundColor: HDCColors.background,
      appBar: AppBar(
        title: const Text('Technician Marketplace'),
        actions: [
          if (discovery.isLoadingOpportunities)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Refresh opportunities',
              onPressed: _refreshMarketplace,
              icon: const Icon(Icons.refresh),
            ),
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
                marketplace.savedOnly ? Icons.bookmark : Icons.bookmark_border,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child:
            marketplace.isLoading ||
                (discovery.isLoadingOpportunities && allRequests.isEmpty)
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding = constraints.maxWidth >= 900
                      ? 32.0
                      : 18.0;
                  return RefreshIndicator(
                    onRefresh: _refreshMarketplace,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
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
                                constraints: const BoxConstraints(
                                  maxWidth: 1180,
                                ),
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
                                    if (discovery.opportunitiesError !=
                                        null) ...[
                                      _MarketplaceRefreshError(
                                        onRetry: _refreshMarketplace,
                                      ),
                                      const SizedBox(height: 14),
                                    ],
                                    _ServiceAreaBanner(
                                      location: technicianLocation,
                                      onSetLocation: () {
                                        Navigator.of(context).push(
                                          HDCPageRoute<void>(
                                            page: const ProfileCenterScreen(
                                              initialRole:
                                                  HDCPlatformRole.technician,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 18),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _searchController,
                                            onChanged: marketplace.setQuery,
                                            decoration: InputDecoration(
                                              hintText: 'Search service, location, or keyword',
                                              prefixIcon: const Icon(
                                                Icons.search,
                                              ),
                                              suffixIcon:
                                                  marketplace.query.isEmpty
                                                  ? null
                                                  : IconButton(
                                                      tooltip: 'Clear search',
                                                      onPressed: () {
                                                        _searchController
                                                            .clear();
                                                        marketplace.setQuery(
                                                          '',
                                                        );
                                                      },
                                                      icon: const Icon(
                                                        Icons.close,
                                                      ),
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
                                        PopupMenuButton<
                                          TechnicianMarketplaceSort
                                        >(
                                          tooltip: 'Sort opportunities',
                                          initialValue: marketplace.sort,
                                          onSelected: marketplace.setSort,
                                          itemBuilder: (_) =>
                                              TechnicianMarketplaceSort.values
                                                  .map(
                                                    (sort) => PopupMenuItem(
                                                      value: sort,
                                                      child: Row(
                                                        children: [
                                                          if (sort ==
                                                              marketplace.sort)
                                                            const Icon(
                                                              Icons.check,
                                                              size: 18,
                                                            )
                                                          else
                                                            const SizedBox(
                                                              width: 18,
                                                            ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Text(sort.label),
                                                        ],
                                                      ),
                                                    ),
                                                  )
                                                  .toList(growable: false),
                                          child: Chip(
                                            avatar: const Icon(
                                              Icons.sort,
                                              size: 18,
                                            ),
                                            label: Text(marketplace.sort.label),
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
                                    const SizedBox(height: 4),
                                    Text(
                                      _lastUpdatedLabel(
                                        discovery.opportunitiesUpdatedAt,
                                      ),
                                      style: const TextStyle(
                                        color: HDCColors.textSecondary,
                                        fontSize: 12,
                                      ),
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
                                        mainAxisExtent: 360,
                                      ),
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
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
                                      isSaved: marketplace.isSaved(request.id),
                                      onSave: () =>
                                          marketplace.toggleSaved(request.id),
                                      onMap: () => _openMap(request.location),
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
                                  }, childCount: requests.length),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
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
      appBar: AppBar(title: const Text('Technician Marketplace')),
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
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 10),
                Text(
                  'Only authenticated HDC accounts with an active Technician '
                  'role can browse customer service opportunities or submit '
                  'professional proposals.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: HDCColors.textSecondary, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MarketplaceRefreshError extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _MarketplaceRefreshError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: HDCColors.danger.withValues(alpha: 0.08),
      child: ListTile(
        leading: const Icon(Icons.cloud_off_outlined, color: HDCColors.danger),
        title: const Text(
          'Latest opportunities could not be loaded',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: const Text('Your existing list is still available.'),
        trailing: TextButton(onPressed: onRetry, child: const Text('Retry')),
      ),
    );
  }
}

class _ServiceAreaBanner extends StatelessWidget {
  final String location;
  final VoidCallback onSetLocation;

  const _ServiceAreaBanner({
    required this.location,
    required this.onSetLocation,
  });

  @override
  Widget build(BuildContext context) {
    final configured = location.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (configured ? HDCColors.success : HDCColors.warning).withValues(
          alpha: 0.09,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (configured ? HDCColors.success : HDCColors.warning)
              .withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          Icon(
            configured ? Icons.near_me_outlined : Icons.location_off_outlined,
            color: configured ? HDCColors.success : HDCColors.warning,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  configured
                      ? 'Nearby area: $location'
                      : 'Set your Technician service area',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  configured
                      ? 'Matching service areas are shown first. Exact distance '
                            'requires location coordinates in a future update.'
                      : 'Add a location to your Technician profile so HDC can '
                            'prioritize matching customer areas.',
                  style: const TextStyle(
                    color: HDCColors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: onSetLocation,
            child: Text(configured ? 'Change' : 'Set area'),
          ),
        ],
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
  final VoidCallback onMap;
  final VoidCallback onOpen;

  const _OpportunityCard({
    required this.request,
    required this.summary,
    required this.ownProposal,
    required this.isSaved,
    required this.onSave,
    required this.onMap,
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
    final urgent =
        request.urgency == ServiceRequestUrgency.urgent ||
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: (urgent ? HDCColors.danger : HDCColors.secondary)
                          .withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      request.urgency.label,
                      style: TextStyle(
                        color: urgent ? HDCColors.danger : HDCColors.secondary,
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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onMap,
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Map'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.tonalIcon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('View'),
                    ),
                  ),
                ],
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

  const _EmptyMarketplace({required this.savedOnly, required this.onClear});

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
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
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
