import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui/hdc_colors.dart';
import '../../models/hdc_internal_dashboard.dart';
import '../../providers/hdc_internal_dashboard_provider.dart';
import '../roles/internal_role_application_review_screen.dart';
import 'account_recovery_review_screen.dart';

class InternalDashboardScreen extends StatefulWidget {
  const InternalDashboardScreen({super.key});

  @override
  State<InternalDashboardScreen> createState() =>
      _InternalDashboardScreenState();
}

class _InternalDashboardScreenState extends State<InternalDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<HdcInternalDashboardProvider>().refresh());
    });
  }

  Future<void> _openApprovalQueue(BuildContext context) async {
    await context
        .read<HdcInternalDashboardProvider>()
        .loadReviewQueue();
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const InternalRoleApplicationReviewScreen(),
      ),
    );
  }

  Future<void> _openRecoveryQueue(BuildContext context) async {
    await context
        .read<HdcInternalDashboardProvider>()
        .loadRecoveryReviewQueue();
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AccountRecoveryReviewScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<HdcInternalDashboardProvider>();

    return Scaffold(
      backgroundColor: HDCColors.background,
      appBar: AppBar(
        title: const Text('Private HDC Operations'),
        actions: [
          IconButton(
            tooltip: 'Refresh private dashboard',
            onPressed: workspace.isLoading ? null : workspace.refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Switch to Public Dashboard',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.swap_horizontal_circle_outlined),
          ),
        ],
      ),
      body: !workspace.hasAccess
          ? const _AccessUnavailable()
          : RefreshIndicator(
              onRefresh: workspace.refresh,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PrivateWorkspaceBanner(
                            displayName: workspace.snapshot?.displayName,
                            onSwitchToPublic: () =>
                                Navigator.of(context).pop(),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Authorized statistics',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Only information permitted for this account is '
                            'included in the private response.',
                            style: TextStyle(color: HDCColors.textSecondary),
                          ),
                          const SizedBox(height: 14),
                          if (workspace.statistics.isEmpty)
                            _StatisticsPlaceholder(
                              loading: workspace.isLoading,
                              backendAvailable: workspace.backendAvailable,
                            )
                          else
                            _StatisticsGrid(
                              statistics: workspace.statistics,
                            ),
                          const SizedBox(height: 26),
                          _AuthorizedScope(
                            permissions: workspace.permissions,
                            pendingApplications: workspace.statistics[
                                    'pendingRoleApplications'] ??
                                0,
                            pendingRecoveryReviews: workspace.statistics[
                                    'pendingRecoveryReviews'] ??
                                0,
                            loading: workspace.isLoading,
                            onOpenApprovalQueue: () =>
                                _openApprovalQueue(context),
                            onOpenRecoveryQueue: () =>
                                _openRecoveryQueue(context),
                          ),
                          if (workspace.assignments.isNotEmpty) ...[
                            const SizedBox(height: 26),
                            _AssignmentsSection(
                              assignments: workspace.assignments,
                            ),
                          ],
                          if (workspace.recentActivities.isNotEmpty) ...[
                            const SizedBox(height: 26),
                            _ActivitySection(
                              activities: workspace.recentActivities,
                            ),
                          ],
                          if (workspace.lastError != null) ...[
                            const SizedBox(height: 20),
                            _PrivateErrorCard(
                              message: '${workspace.lastError}',
                              onRetry: workspace.refresh,
                            ),
                          ],
                          if (workspace.isLoading) ...[
                            const SizedBox(height: 20),
                            const Center(child: CircularProgressIndicator()),
                          ],
                          const SizedBox(height: 28),
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

class _PrivateWorkspaceBanner extends StatelessWidget {
  final String? displayName;
  final VoidCallback onSwitchToPublic;

  const _PrivateWorkspaceBanner({
    required this.displayName,
    required this.onSwitchToPublic,
  });

  @override
  Widget build(BuildContext context) {
    final name = displayName?.trim();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: HDCColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final icon = Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Colors.white,
              size: 29,
            ),
          );
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name == null || name.isEmpty
                    ? 'Private operations workspace'
                    : 'Private workspace for $name',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Statistics and actions are filtered by server-enforced '
                'permissions. This workspace is not part of the public app.',
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: HDCColors.primary,
                ),
                onPressed: onSwitchToPublic,
                icon: const Icon(Icons.public),
                label: const Text('Switch to Public Dashboard'),
              ),
            ],
          );
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                icon,
                const SizedBox(height: 14),
                details,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              icon,
              const SizedBox(width: 16),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}

class _StatisticsGrid extends StatelessWidget {
  final Map<String, int> statistics;

  const _StatisticsGrid({required this.statistics});

  @override
  Widget build(BuildContext context) {
    final entries = statistics.entries.toList(growable: false)
      ..sort(
        (a, b) => _statisticOrder(a.key).compareTo(_statisticOrder(b.key)),
      );

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 920
            ? 4
            : constraints.maxWidth >= 600
                ? 3
                : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: entries.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: constraints.maxWidth < 420
                ? 0.95
                : columns == 2
                    ? 1.25
                    : 1.45,
          ),
          itemBuilder: (context, index) {
            final entry = entries[index];
            final details = _statisticDetails(entry.key);
            return Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(details.$2, color: details.$3),
                    const Spacer(),
                    Text(
                      '${entry.value}',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      details.$1,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HDCColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StatisticsPlaceholder extends StatelessWidget {
  final bool loading;
  final bool backendAvailable;

  const _StatisticsPlaceholder({
    required this.loading,
    required this.backendAvailable,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          backendAvailable ? Icons.query_stats : Icons.cloud_off_outlined,
        ),
        title: Text(
          loading
              ? 'Loading authorized statistics…'
              : backendAvailable
                  ? 'Statistics are not available yet'
                  : 'Private API connection is unavailable',
        ),
        subtitle: const Text(
          'No operational data is stored in the public dashboard.',
        ),
      ),
    );
  }
}

class _AuthorizedScope extends StatelessWidget {
  final HDCInternalDashboardPermissions permissions;
  final int pendingApplications;
  final int pendingRecoveryReviews;
  final bool loading;
  final VoidCallback onOpenApprovalQueue;
  final VoidCallback onOpenRecoveryQueue;

  const _AuthorizedScope({
    required this.permissions,
    required this.pendingApplications,
    required this.pendingRecoveryReviews,
    required this.loading,
    required this.onOpenApprovalQueue,
    required this.onOpenRecoveryQueue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Authorized tools',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        if (permissions.canApprovePlatformRoles)
          _ScopeTile(
            icon: Icons.fact_check_outlined,
            title: 'Platform role approvals',
            subtitle: pendingApplications == 0
                ? 'The approval queue is clear.'
                : '$pendingApplications application(s) waiting for review.',
            action: FilledButton.tonalIcon(
              onPressed: loading ? null : onOpenApprovalQueue,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Open Queue'),
            ),
          ),
        if (permissions.canReviewAccountRecovery)
          _ScopeTile(
            icon: Icons.security_outlined,
            title: 'Manual account recovery',
            subtitle: pendingRecoveryReviews == 0
                ? 'The security review queue is clear.'
                : '$pendingRecoveryReviews recovery request(s) waiting for review.',
            action: FilledButton.tonalIcon(
              onPressed: loading ? null : onOpenRecoveryQueue,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Open Queue'),
            ),
          ),
        if (permissions.canManageInternalStructure)
          const _ScopeTile(
            icon: Icons.account_tree_outlined,
            title: 'Organization structure',
            subtitle:
                'Department, section, and staff-assignment reporting is active.',
          ),
        if (permissions.hasPrivilegedResourceAccess)
          const _ScopeTile(
            icon: Icons.analytics_outlined,
            title: 'Operational reporting',
            subtitle:
                'Member, service-request, and transaction statistics are active.',
          ),
        if (permissions.canModerateCommunity)
          const _ScopeTile(
            icon: Icons.forum_outlined,
            title: 'Community moderation',
            subtitle: 'Community oversight scope is active for this account.',
          ),
      ],
    );
  }
}

class _ScopeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const _ScopeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Icon(icon, color: HDCColors.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: action,
      ),
    );
  }
}

class _AssignmentsSection extends StatelessWidget {
  final List<HDCInternalStaffAssignment> assignments;

  const _AssignmentsSection({required this.assignments});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My staff assignments',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        ...assignments.map(
          (assignment) => Card(
            child: ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text(assignment.departmentName),
              subtitle: Text(
                [assignment.sectionName, assignment.title]
                    .whereType<String>()
                    .where((value) => value.isNotEmpty)
                    .join(' · '),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivitySection extends StatelessWidget {
  final List<HDCInternalActivity> activities;

  const _ActivitySection({required this.activities});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent private activity',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: activities.indexed.map((entry) {
              final index = entry.$1;
              final activity = entry.$2;
              return Column(
                children: [
                  if (index > 0) const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      activity.eventStatus == 'success'
                          ? Icons.check_circle_outline
                          : Icons.history,
                      color: activity.eventStatus == 'success'
                          ? HDCColors.success
                          : HDCColors.info,
                    ),
                    title: Text(_activityTitle(activity.eventType)),
                    subtitle: Text(_dateTimeLabel(activity.createdAt)),
                  ),
                ],
              );
            }).toList(growable: false),
          ),
        ),
      ],
    );
  }
}

class _PrivateErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _PrivateErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: HDCColors.danger.withValues(alpha: 0.06),
      child: ListTile(
        leading: const Icon(Icons.error_outline, color: HDCColors.danger),
        title: const Text('Private dashboard could not refresh'),
        subtitle: Text(message),
        trailing: TextButton(onPressed: onRetry, child: const Text('Retry')),
      ),
    );
  }
}

class _AccessUnavailable extends StatelessWidget {
  const _AccessUnavailable();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 64),
            const SizedBox(height: 16),
            Text(
              'Private access is unavailable',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'This account does not have an active private operations scope.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.public),
              label: const Text('Return to Public Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}

(String, IconData, Color) _statisticDetails(String key) {
  switch (key) {
    case 'myAssignments':
      return ('My assignments', Icons.badge_outlined, HDCColors.info);
    case 'pendingRoleApplications':
      return ('Pending applications', Icons.fact_check_outlined, HDCColors.warning);
    case 'pendingRecoveryReviews':
      return ('Recovery reviews', Icons.security_outlined, HDCColors.danger);
    case 'activeDepartments':
      return ('Active departments', Icons.account_tree_outlined, HDCColors.primary);
    case 'activeSections':
      return ('Active sections', Icons.schema_outlined, HDCColors.secondary);
    case 'activeStaffAssignments':
      return ('Staff assignments', Icons.groups_outlined, HDCColors.info);
    case 'activeMembers':
      return ('Active members', Icons.people_outline, HDCColors.success);
    case 'openServiceRequests':
      return ('Open service requests', Icons.campaign_outlined, HDCColors.warning);
    case 'activeServiceTransactions':
      return ('Active transactions', Icons.handshake_outlined, HDCColors.primary);
    default:
      return ('Authorized statistic', Icons.query_stats, HDCColors.primary);
  }
}

int _statisticOrder(String key) {
  const order = <String>[
    'myAssignments',
    'pendingRoleApplications',
    'pendingRecoveryReviews',
    'activeMembers',
    'openServiceRequests',
    'activeServiceTransactions',
    'activeDepartments',
    'activeSections',
    'activeStaffAssignments',
  ];
  final index = order.indexOf(key);
  return index == -1 ? order.length : index;
}

String _activityTitle(String eventType) {
  final normalized = eventType
      .replaceAll('roles.', '')
      .replaceAll('internal.', '')
      .replaceAll('_', ' ')
      .replaceAll('.', ' ')
      .trim();
  if (normalized.isEmpty) return 'Private workspace activity';
  return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
}

String _dateTimeLabel(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}
