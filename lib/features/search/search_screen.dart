import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/maps/hdc_map_launcher.dart';
import '../../core/navigation/hdc_page_route.dart';
import '../../core/ui/hdc_brand.dart';
import '../../core/ui/hdc_card.dart';
import '../../core/ui/hdc_colors.dart';
import '../../core/ui/hdc_flow.dart';
import '../../core/ui/hdc_spacing.dart';
import '../../core/ui/hdc_status_badge.dart';
import '../../models/account_identity.dart';
import '../../models/service_request_draft.dart';
import '../../models/technician_directory_entry.dart';
import '../../providers/hdc_auth_provider.dart';
import '../../providers/hdc_profile_provider.dart';
import '../../providers/technician_discovery_provider.dart';
import '../profiles/profile_center_screen.dart';
import '../service_requests/create_service_request_screen.dart';

class SearchScreen extends StatefulWidget {
  final ServiceRequestDraft draft;

  const SearchScreen({super.key, required this.draft});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _queryController;
  final _areaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(
      text: widget.draft.category?.name ?? '',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          context.read<TechnicianDiscoveryProvider>().refreshDirectory(),
        );
      }
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _refresh() =>
      context.read<TechnicianDiscoveryProvider>().refreshDirectory();

  Future<void> _openMap(String location) async {
    final opened = await HdcMapLauncher.openServiceArea(location);
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('A map app could not be opened.')),
    );
  }

  void _useProfileArea(HdcProfileProvider profiles) {
    final location = profiles.memberProfile?.location.trim() ?? '';
    if (location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a location to your member profile first.'),
        ),
      );
      return;
    }
    setState(() => _areaController.text = location);
  }

  void _postRequest() {
    Navigator.of(
      context,
    ).push(HDCPageRoute<void>(page: const CreateServiceRequestScreen()));
  }

  void _showContact(TechnicianDirectoryEntry technician) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HDCStatusBadge(
                label: 'Technician-published details',
                tone: HDCStatusTone.info,
                icon: Icons.verified_user_outlined,
              ),
              const SizedBox(height: HDCSpacing.md),
              Text(
                technician.publicName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: HDCSpacing.xs),
              const Text(
                'These are the public contact details supplied by this '
                'technician. Private account information is not shown.',
                style: TextStyle(
                  color: HDCColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: HDCSpacing.md),
              if (technician.contactEmail.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Email'),
                  subtitle: SelectableText(technician.contactEmail),
                ),
              if (technician.contactPhone.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.phone_outlined),
                  title: const Text('Phone'),
                  subtitle: SelectableText(technician.contactPhone),
                ),
              if (technician.website.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.language_outlined),
                  title: const Text('Website'),
                  subtitle: SelectableText(technician.website),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _lastUpdated(DateTime? value) {
    if (value == null) return 'Not refreshed yet';
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return 'Updated $hour:$minute';
  }

  void _clearSearch() {
    _queryController.clear();
    _areaController.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<HDCAuthProvider>();
    final discovery = context.watch<TechnicianDiscoveryProvider>();
    final profiles = context.watch<HdcProfileProvider>();
    final authenticated =
        auth.authenticated && !auth.guestMode && auth.identity != null;

    if (!authenticated) {
      return const _DirectorySignInRequired();
    }

    final technicians = discovery.searchTechnicians(
      query: _queryController.text,
      serviceArea: _areaController.text,
    );
    final ownTechnicianProfile = profiles.profileFor(
      HDCPlatformRole.technician,
    );

    return Scaffold(
      backgroundColor: HDCColors.background,
      appBar: AppBar(
        title: const Text('Find a Technician'),
        actions: [
          if (discovery.isLoadingDirectory)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: HDCSpacing.md),
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Refresh technician directory',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: HDCSignalBackdrop(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              HDCSpacing.md,
              HDCSpacing.md,
              HDCSpacing.md,
              HDCSpacing.xxl,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: HDCSpacing.contentMaxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      HDCFlowHero(
                        eyebrow: 'Technician discovery',
                        title: 'Find the right expertise for your issue',
                        description:
                            'Search approved public profiles by name, skill, '
                            'specialty, or service area. Results use details '
                            'published by each technician.',
                        icon: Icons.person_search_outlined,
                        tags: const [
                          HDCFlowTag(
                            label: 'Approved technicians',
                            icon: Icons.verified_outlined,
                            color: HDCColors.success,
                          ),
                          HDCFlowTag(
                            label: 'Public profiles only',
                            icon: Icons.visibility_outlined,
                            color: HDCColors.info,
                          ),
                          HDCFlowTag(
                            label: 'Area-aware results',
                            icon: Icons.near_me_outlined,
                          ),
                        ],
                        action: FilledButton.icon(
                          key: const Key('hdc-discovery-post-request'),
                          onPressed: _postRequest,
                          icon: const Icon(Icons.campaign_outlined),
                          label: const Text('Post a Service Request'),
                        ),
                      ),
                      if (ownTechnicianProfile != null &&
                          !ownTechnicianProfile.isPublic) ...[
                        const SizedBox(height: HDCSpacing.md),
                        _PrivateTechnicianProfileNotice(
                          onPublish: () {
                            Navigator.of(context).push(
                              HDCPageRoute<void>(
                                page: const ProfileCenterScreen(
                                  initialRole: HDCPlatformRole.technician,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                      if (discovery.directoryError != null) ...[
                        const SizedBox(height: HDCSpacing.md),
                        _DirectoryError(onRetry: _refresh),
                      ],
                      const SizedBox(height: HDCSpacing.lg),
                      HDCSectionCard(
                        title: 'Search the directory',
                        subtitle:
                            'Area matches are prioritized; no estimated '
                            'distance or rating is invented.',
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth >= 720;
                            final query = TextField(
                              key: const Key('hdc-technician-query'),
                              controller: _queryController,
                              onChanged: (_) => setState(() {}),
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                labelText: 'Skill, specialty, or technician',
                                hintText: 'Example: laptop repair',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _queryController.text.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Clear search term',
                                        onPressed: () {
                                          _queryController.clear();
                                          setState(() {});
                                        },
                                        icon: const Icon(Icons.close),
                                      ),
                              ),
                            );
                            final area = TextField(
                              key: const Key('hdc-technician-area'),
                              controller: _areaController,
                              onChanged: (_) => setState(() {}),
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                labelText: 'Preferred service area',
                                hintText: 'Example: Cebu City',
                                prefixIcon: const Icon(
                                  Icons.location_on_outlined,
                                ),
                                suffixIcon: IconButton(
                                  tooltip: 'Use my profile location',
                                  onPressed: () => _useProfileArea(profiles),
                                  icon: const Icon(Icons.my_location),
                                ),
                              ),
                            );

                            if (!wide) {
                              return Column(
                                children: [
                                  query,
                                  const SizedBox(height: HDCSpacing.sm),
                                  area,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: query),
                                const SizedBox(width: HDCSpacing.sm),
                                Expanded(child: area),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: HDCSpacing.lg),
                      _ResultsHeader(
                        count: technicians.length,
                        lastUpdated: _lastUpdated(
                          discovery.directoryUpdatedAt,
                        ),
                        area: _areaController.text.trim(),
                        onMap: _areaController.text.trim().isEmpty
                            ? null
                            : () => _openMap(_areaController.text),
                        onClear:
                            _queryController.text.trim().isEmpty &&
                                _areaController.text.trim().isEmpty
                            ? null
                            : _clearSearch,
                      ),
                      const SizedBox(height: HDCSpacing.md),
                      if (discovery.isLoadingDirectory &&
                          discovery.technicians.isEmpty)
                        const _DirectoryLoading()
                      else if (technicians.isEmpty)
                        _EmptyDirectory(
                          directoryIsEmpty: discovery.technicians.isEmpty,
                          onClear: _clearSearch,
                          onPostRequest: _postRequest,
                        )
                      else
                        _TechnicianGrid(
                          technicians: technicians,
                          searchArea: _areaController.text,
                          onMap: _openMap,
                          onContact: _showContact,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  final int count;
  final String lastUpdated;
  final String area;
  final VoidCallback? onMap;
  final VoidCallback? onClear;

  const _ResultsHeader({
    required this.count,
    required this.lastUpdated,
    required this.area,
    required this.onMap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return HDCCard(
      padding: const EdgeInsets.all(HDCSpacing.md),
      child: Wrap(
        spacing: HDCSpacing.sm,
        runSpacing: HDCSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          HDCStatusBadge(
            label: count == 1 ? '1 technician found' : '$count technicians found',
            tone: count > 0 ? HDCStatusTone.success : HDCStatusTone.neutral,
            icon: Icons.groups_outlined,
          ),
          Text(
            lastUpdated,
            style: const TextStyle(
              color: HDCColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (area.isNotEmpty)
            OutlinedButton.icon(
              onPressed: onMap,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Open Area Map'),
            ),
          if (onClear != null)
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Clear Filters'),
            ),
        ],
      ),
    );
  }
}

class _TechnicianGrid extends StatelessWidget {
  final List<TechnicianDirectoryEntry> technicians;
  final String searchArea;
  final Future<void> Function(String location) onMap;
  final ValueChanged<TechnicianDirectoryEntry> onContact;

  const _TechnicianGrid({
    required this.technicians,
    required this.searchArea,
    required this.onMap,
    required this.onContact,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 960 ? 2 : 1;
        final width = columns == 2
            ? (constraints.maxWidth - HDCSpacing.md) / 2
            : constraints.maxWidth;

        return Wrap(
          key: const Key('hdc-technician-results'),
          spacing: HDCSpacing.md,
          runSpacing: HDCSpacing.md,
          children: [
            for (final technician in technicians)
              SizedBox(
                width: width,
                child: _TechnicianCard(
                  technician: technician,
                  areaRank: TechnicianDiscoveryProvider.areaMatchRank(
                    technician.location,
                    searchArea,
                  ),
                  onMap: technician.location.isEmpty
                      ? null
                      : () => onMap(technician.location),
                  onContact: technician.hasPublicContact
                      ? () => onContact(technician)
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TechnicianCard extends StatelessWidget {
  final TechnicianDirectoryEntry technician;
  final int areaRank;
  final VoidCallback? onMap;
  final VoidCallback? onContact;

  const _TechnicianCard({
    required this.technician,
    required this.areaRank,
    required this.onMap,
    required this.onContact,
  });

  @override
  Widget build(BuildContext context) {
    final skillLabels = <String>{
      ...technician.skills,
      ...technician.specialties,
    }.take(6).toList(growable: false);

    return HDCCard(
      key: Key('hdc-technician-${technician.profileId}'),
      elevated: areaRank > 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: HDCColors.secondary.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.engineering_outlined,
                  color: HDCColors.secondary,
                  size: 27,
                ),
              ),
              const SizedBox(width: HDCSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      technician.publicName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (technician.headline.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        technician.headline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      technician.publicMemberId,
                      style: const TextStyle(
                        color: HDCColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (areaRank > 0) ...[
            const SizedBox(height: HDCSpacing.sm),
            const HDCStatusBadge(
              label: 'Area match',
              tone: HDCStatusTone.success,
              icon: Icons.near_me_outlined,
            ),
          ],
          if (technician.description.isNotEmpty) ...[
            const SizedBox(height: HDCSpacing.md),
            Text(
              technician.description,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(height: 1.5),
            ),
          ],
          if (technician.location.isNotEmpty) ...[
            const SizedBox(height: HDCSpacing.md),
            _TechnicianFact(
              icon: Icons.location_on_outlined,
              label: technician.location,
            ),
          ],
          if (skillLabels.isNotEmpty) ...[
            const SizedBox(height: HDCSpacing.md),
            Wrap(
              spacing: HDCSpacing.xs,
              runSpacing: HDCSpacing.xs,
              children: [
                for (final skill in skillLabels)
                  Chip(
                    avatar: const Icon(Icons.build_outlined, size: 15),
                    label: Text(skill),
                  ),
              ],
            ),
          ],
          const SizedBox(height: HDCSpacing.md),
          Wrap(
            spacing: HDCSpacing.xs,
            runSpacing: HDCSpacing.xs,
            children: [
              if (technician.yearsExperience != null)
                _FactChip(
                  icon: Icons.workspace_premium_outlined,
                  label: '${technician.yearsExperience} years experience',
                ),
              if (technician.serviceRadiusKm != null)
                _FactChip(
                  icon: Icons.radar_outlined,
                  label:
                      '${technician.serviceRadiusKm!.toStringAsFixed(0)} km stated radius',
                ),
              if (technician.hourlyRate != null)
                _FactChip(
                  icon: Icons.payments_outlined,
                  label:
                      'PHP ${technician.hourlyRate!.toStringAsFixed(0)} stated hourly rate',
                ),
              if (technician.availability.isNotEmpty)
                _FactChip(
                  icon: Icons.schedule_outlined,
                  label: technician.availability,
                ),
              if (technician.emergencyService)
                const _FactChip(
                  icon: Icons.emergency_outlined,
                  label: 'Emergency service',
                ),
            ],
          ),
          const SizedBox(height: HDCSpacing.lg),
          HDCResponsiveActions(
            breakpoint: 430,
            actions: [
              OutlinedButton.icon(
                onPressed: onMap,
                icon: const Icon(Icons.map_outlined),
                label: Text(
                  onMap == null ? 'No public area' : 'View Service Area',
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: onContact,
                icon: const Icon(Icons.contact_page_outlined),
                label: Text(
                  onContact == null ? 'No Public Contact' : 'Public Contact',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TechnicianFact extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TechnicianFact({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: HDCColors.textSecondary),
        const SizedBox(width: HDCSpacing.xs),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: HDCColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _FactChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FactChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 16), label: Text(label));
  }
}

class _PrivateTechnicianProfileNotice extends StatelessWidget {
  final VoidCallback onPublish;

  const _PrivateTechnicianProfileNotice({required this.onPublish});

  @override
  Widget build(BuildContext context) {
    return HDCCard(
      color: HDCColors.warning.withValues(alpha: 0.08),
      borderColor: HDCColors.warning.withValues(alpha: 0.24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.visibility_off_outlined,
            color: HDCColors.warning,
          ),
          const SizedBox(width: HDCSpacing.sm),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Technician profile is private',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 5),
                Text(
                  'Enable “Publicly discoverable profile” before customers '
                  'can find it.',
                  style: TextStyle(
                    color: HDCColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: HDCSpacing.xs),
          TextButton(onPressed: onPublish, child: const Text('Edit')),
        ],
      ),
    );
  }
}

class _DirectoryError extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _DirectoryError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return HDCCard(
      color: HDCColors.danger.withValues(alpha: 0.06),
      borderColor: HDCColors.danger.withValues(alpha: 0.22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off_outlined, color: HDCColors.danger),
          const SizedBox(width: HDCSpacing.sm),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Technician directory could not be loaded',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 4),
                Text(
                  'Existing profile data was not changed. Check the '
                  'connection and try again.',
                  style: TextStyle(color: HDCColors.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _DirectoryLoading extends StatelessWidget {
  const _DirectoryLoading();

  @override
  Widget build(BuildContext context) {
    return const HDCCard(
      child: SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _EmptyDirectory extends StatelessWidget {
  final bool directoryIsEmpty;
  final VoidCallback onClear;
  final VoidCallback onPostRequest;

  const _EmptyDirectory({
    required this.directoryIsEmpty,
    required this.onClear,
    required this.onPostRequest,
  });

  @override
  Widget build(BuildContext context) {
    return HDCEmptyState(
      icon: Icons.person_search_outlined,
      title: directoryIsEmpty
          ? 'No public technicians yet'
          : 'No technicians match this search',
      description: directoryIsEmpty
          ? 'Approved technicians remain private until they enable '
                '“Publicly discoverable profile” in their Technician profile.'
          : 'Try another name, skill, specialty, or service area.',
      actions: [
        if (!directoryIsEmpty)
          OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Clear Search'),
          ),
        FilledButton.icon(
          onPressed: onPostRequest,
          icon: const Icon(Icons.campaign_outlined),
          label: const Text('Post a Service Request'),
        ),
      ],
    );
  }
}

class _DirectorySignInRequired extends StatelessWidget {
  const _DirectorySignInRequired();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find a Technician')),
      body: HDCSignalBackdrop(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(HDCSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: const HDCEmptyState(
                icon: Icons.lock_person_outlined,
                title: 'Registered Account Required',
                description:
                    'Sign in to search approved public Technician profiles. '
                    'Private profiles and internal account details are never '
                    'listed.',
                color: HDCColors.info,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
