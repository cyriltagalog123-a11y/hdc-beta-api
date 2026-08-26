import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/maps/hdc_map_launcher.dart';
import '../../core/navigation/hdc_page_route.dart';
import '../../core/ui/hdc_colors.dart';
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

  void _showContact(TechnicianDirectoryEntry technician) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                technician.publicName,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Public contact details supplied by this technician.',
                style: TextStyle(color: HDCColors.textSecondary),
              ),
              const SizedBox(height: 18),
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
    return 'Last updated $hour:$minute';
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
              padding: EdgeInsets.symmetric(horizontal: 16),
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
      body: discovery.isLoadingDirectory && discovery.technicians.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _DirectoryIntroduction(),
                          if (ownTechnicianProfile != null &&
                              !ownTechnicianProfile.isPublic) ...[
                            const SizedBox(height: 14),
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
                            const SizedBox(height: 14),
                            _DirectoryError(onRetry: _refresh),
                          ],
                          const SizedBox(height: 18),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final wide = constraints.maxWidth >= 720;
                              final query = TextField(
                                controller: _queryController,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: 'Manual search',
                                  hintText:
                                      'Name, skill, specialty, or keyword',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: _queryController.text.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: 'Clear search',
                                          onPressed: () {
                                            _queryController.clear();
                                            setState(() {});
                                          },
                                          icon: const Icon(Icons.close),
                                        ),
                                ),
                              );
                              final area = TextField(
                                controller: _areaController,
                                onChanged: (_) => setState(() {}),
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
                                    const SizedBox(height: 12),
                                    area,
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(child: query),
                                  const SizedBox(width: 12),
                                  Expanded(child: area),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                technicians.length == 1
                                    ? '1 technician found'
                                    : '${technicians.length} technicians found',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                _lastUpdated(discovery.directoryUpdatedAt),
                                style: const TextStyle(
                                  color: HDCColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              if (_areaController.text.trim().isNotEmpty)
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _openMap(_areaController.text),
                                  icon: const Icon(Icons.map_outlined),
                                  label: const Text('Open area map'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (technicians.isEmpty)
                            _EmptyDirectory(
                              directoryIsEmpty: discovery.technicians.isEmpty,
                              onClear: () {
                                _queryController.clear();
                                _areaController.clear();
                                setState(() {});
                              },
                              onPostRequest: () {
                                Navigator.of(context).push(
                                  HDCPageRoute<void>(
                                    page: const CreateServiceRequestScreen(),
                                  ),
                                );
                              },
                            )
                          else
                            ...technicians.map(
                              (technician) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _TechnicianCard(
                                  technician: technician,
                                  areaRank:
                                      TechnicianDiscoveryProvider.areaMatchRank(
                                        technician.location,
                                        _areaController.text,
                                      ),
                                  onMap: technician.location.isEmpty
                                      ? null
                                      : () => _openMap(technician.location),
                                  onContact: technician.hasPublicContact
                                      ? () => _showContact(technician)
                                      : null,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _DirectoryIntroduction extends StatelessWidget {
  const _DirectoryIntroduction();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: HDCColors.primary,
      child: const Padding(
        padding: EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search approved technicians',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Search manually by name, skill, specialty, or service area. '
              'Area matches are shown first, and each listed location can be '
              'opened on the map.',
              style: TextStyle(color: Colors.white70, height: 1.45),
            ),
          ],
        ),
      ),
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
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: HDCColors.secondary.withValues(alpha: 0.12),
                  child: const Icon(Icons.engineering_outlined),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        technician.publicName,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (technician.headline.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(technician.headline),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        technician.publicMemberId,
                        style: const TextStyle(
                          color: HDCColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (areaRank > 0)
                  const Chip(
                    avatar: Icon(Icons.near_me_outlined, size: 17),
                    label: Text('Area match'),
                  ),
              ],
            ),
            if (technician.description.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(technician.description),
            ],
            if (technician.location.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: HDCColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(technician.location)),
                ],
              ),
            ],
            if (skillLabels.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: skillLabels
                    .map((skill) => Chip(label: Text(skill)))
                    .toList(growable: false),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
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
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onMap,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('View service area'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onContact,
                  icon: const Icon(Icons.contact_page_outlined),
                  label: Text(
                    onContact == null ? 'No public contact' : 'Public contact',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FactChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FactChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 17), label: Text(label));
  }
}

class _PrivateTechnicianProfileNotice extends StatelessWidget {
  final VoidCallback onPublish;

  const _PrivateTechnicianProfileNotice({required this.onPublish});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: HDCColors.warning.withValues(alpha: 0.10),
      child: ListTile(
        leading: const Icon(Icons.visibility_off_outlined),
        title: const Text(
          'Your Technician profile is private',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: const Text(
          'Enable “Publicly discoverable profile” before customers can find it.',
        ),
        trailing: TextButton(onPressed: onPublish, child: const Text('Edit')),
      ),
    );
  }
}

class _DirectoryError extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _DirectoryError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: HDCColors.danger.withValues(alpha: 0.08),
      child: ListTile(
        leading: const Icon(Icons.cloud_off_outlined, color: HDCColors.danger),
        title: const Text(
          'Technician directory could not be loaded',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: const Text('Check the connection and try again.'),
        trailing: TextButton(onPressed: onRetry, child: const Text('Retry')),
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
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const Icon(Icons.person_search_outlined, size: 54),
            const SizedBox(height: 14),
            Text(
              directoryIsEmpty
                  ? 'No public technicians yet'
                  : 'No technicians match this search',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              directoryIsEmpty
                  ? 'Approved technicians remain private until they enable '
                        '“Publicly discoverable profile” in their Technician profile.'
                  : 'Try another name, skill, specialty, or service area.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: HDCColors.textSecondary),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (!directoryIsEmpty)
                  OutlinedButton.icon(
                    onPressed: onClear,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Clear search'),
                  ),
                FilledButton.icon(
                  onPressed: onPostRequest,
                  icon: const Icon(Icons.campaign_outlined),
                  label: const Text('Post a Service Request'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectorySignInRequired extends StatelessWidget {
  const _DirectorySignInRequired();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find a Technician')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_person_outlined, size: 58),
                SizedBox(height: 18),
                Text(
                  'Registered Account Required',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10),
                Text(
                  'Sign in to search approved public Technician profiles. '
                  'Private profiles and internal account details are never listed.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
