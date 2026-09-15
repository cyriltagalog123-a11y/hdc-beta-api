import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/hdc_page_route.dart';
import '../../core/ui/hdc_colors.dart';
import '../../core/ui/hdc_flow.dart';
import '../../core/ui/hdc_profile_avatar.dart';
import '../../models/technician_public_profile.dart';
import '../../providers/technician_discovery_provider.dart';
import '../authentication/registered_user_gate.dart';
import '../service_requests/create_service_request_screen.dart';

class PublicTechnicianProfileScreen extends StatefulWidget {
  final String profileId;

  const PublicTechnicianProfileScreen({required this.profileId, super.key});

  @override
  State<PublicTechnicianProfileScreen> createState() =>
      _PublicTechnicianProfileScreenState();
}

class _PublicTechnicianProfileScreenState
    extends State<PublicTechnicianProfileScreen> {
  TechnicianPublicProfile? _profile;
  Object? _error;
  bool _loading = true;
  int _requestVersion = 0;
  int _reviewPage = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PublicTechnicianProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId) {
      _reviewPage = 0;
      _load();
    }
  }

  Future<void> _load() async {
    final version = ++_requestVersion;
    final id = widget.profileId;
    setState(() {
      _loading = true;
      _profile = null;
      _error = null;
    });
    try {
      final profile = await context.read<TechnicianDiscoveryProvider>()
          .fetchPublicProfile(id, reviewPage: _reviewPage);
      if (!mounted || version != _requestVersion || id != widget.profileId) {
        return;
      }
      setState(() => _profile = profile);
    } on Object catch (error) {
      if (mounted && version == _requestVersion) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted && version == _requestVersion) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _postRequest() async {
    if (!await requireRegisteredUser(context, action: 'post a service request')) {
      return;
    }
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      HDCPageRoute<void>(page: const CreateServiceRequestScreen()),
    );
  }

  void _changeReviewPage(int page) {
    _reviewPage = page;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return Scaffold(
      backgroundColor: HDCColors.background,
      appBar: AppBar(
        title: const Text('Technician Profile'),
        actions: [
          IconButton(
            tooltip: 'Refresh public profile',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || profile == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'This public profile is unavailable. It may no longer '
                      'be listed, or the connection could not be completed.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(onPressed: _load, child: const Text('Try Again')),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 880),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: _contents(profile),
                  ),
                ),
              ),
            ),
    );
  }

  List<Widget> _contents(TechnicianPublicProfile profile) {
    final technician = profile.technician;
    final shared = <String, String>{
      'Headline': technician.headline,
      'About': technician.description,
      'Service area': technician.location,
      'Contact email': technician.contactEmail,
      'Contact phone': technician.contactPhone,
      'Website': technician.website,
      'Skills': technician.skills.join(', '),
      'Specialties': technician.specialties.join(', '),
      if (technician.serviceRadiusKm != null)
        'Service radius': '${technician.serviceRadiusKm} km (stated)',
      if (technician.hourlyRate != null)
        'Hourly rate': 'PHP ${technician.hourlyRate!.toStringAsFixed(2)} (stated)',
      'Availability': technician.availability,
      if (technician.details.containsKey('emergencyService'))
        'Emergency service': technician.emergencyService ? 'Available' : 'Not offered',
    }..removeWhere((key, value) => value.isEmpty);
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HdcProfileAvatar(avatarUrl: technician.avatarUrl, name: technician.publicName, size: 64),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(technician.publicName, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(technician.publicMemberId),
                const Text('Approved technician'),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      HDCSectionCard(
        title: 'Experience & service ratings',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(technician.ratingLabel, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(technician.yearsExperience == null
                ? 'Experience not provided'
                : '${technician.yearsExperience} years experience (stated)'),
            Text('${technician.completedServices} completed HDC services'),
            const SizedBox(height: 8),
            const Text('Ratings and reviews come from customers of completed HDC services.'),
          ],
        ),
      ),
      if (shared.isNotEmpty) ...[
        const SizedBox(height: 16),
        HDCSectionCard(
          title: 'Details shared by this technician',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in shared.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.key, style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 4),
                      SelectableText(entry.value),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 16),
      HDCSectionCard(
        title: 'Customer reviews',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (profile.reviews.isEmpty)
              Text(profile.reviewPage == 0 ? 'No reviews yet.' : 'No more reviews on this page.'),
            for (final review in profile.reviews)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${review.score} / 5 · Completed service customer',
                        style: Theme.of(context).textTheme.labelLarge),
                    if (review.createdAt != null)
                      Text('${review.createdAt!.year}-${review.createdAt!.month.toString().padLeft(2, '0')}-${review.createdAt!.day.toString().padLeft(2, '0')}'),
                    const SizedBox(height: 6),
                    Text(review.review.isEmpty ? 'Rating only' : review.review),
                  ],
                ),
              ),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (profile.reviewPage > 0)
                  OutlinedButton(
                    onPressed: () => _changeReviewPage(profile.reviewPage - 1),
                    child: const Text('Previous Reviews'),
                  ),
                if (profile.hasMoreReviews)
                  OutlinedButton(
                    onPressed: () => _changeReviewPage(profile.reviewPage + 1),
                    child: const Text('More Reviews'),
                  ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: _postRequest,
        icon: const Icon(Icons.add),
        label: const Text('Post a Service Request'),
      ),
    ];
  }
}
