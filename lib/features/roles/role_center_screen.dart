import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui/hdc_colors.dart';
import '../../models/account_identity.dart';
import '../../models/platform_role_application.dart';
import '../../providers/hdc_role_center_provider.dart';
import '../profiles/profile_center_screen.dart';
import 'platform_role_application_form_screen.dart';

class RoleCenterScreen extends StatelessWidget {
  const RoleCenterScreen({super.key});

  Future<void> _apply(
    BuildContext context,
    HDCPlatformRole role,
    PlatformRoleApplication? application,
  ) async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PlatformRoleApplicationFormScreen(
          role: role,
          previousApplication: application,
        ),
      ),
    );
    if (submitted != true || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${role.label} application submitted for review.'),
      ),
    );
  }

  void _openProfile(BuildContext context, HDCPlatformRole role) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileCenterScreen(initialRole: role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roles = context.watch<HdcRoleCenterProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Role Center'),
        actions: [
          IconButton(
            tooltip: 'Refresh roles',
            onPressed: roles.isLoading ? null : roles.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: roles.refresh,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _RoleBoundaryBanner(backendAvailable: roles.backendAvailable),
            const SizedBox(height: 22),
            Text(
              'Platform roles',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Platform roles unlock HDC product workspaces. Registration '
              'starts with Customer; elevated roles require approval.',
            ),
            const SizedBox(height: 16),
            ...HDCPlatformRole.values.map(
              (role) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PlatformRoleCard(
                  role: role,
                  active: roles.platformRoles.contains(role),
                  application: roles.latestApplicationFor(role),
                  busy: roles.isSubmitting,
                  backendAvailable: roles.backendAvailable,
                  onApply: () => _apply(
                    context,
                    role,
                    roles.latestApplicationFor(role),
                  ),
                  onOpenProfile: () => _openProfile(context, role),
                ),
              ),
            ),
            if (roles.notifications.isNotEmpty) ...[
              const SizedBox(height: 22),
              Text(
                'Role notifications',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              ...roles.notifications.take(5).map(
                    (notification) => _RoleNotificationTile(
                      notification: notification,
                    ),
                  ),
            ],
            if (roles.lastError != null) ...[
              const SizedBox(height: 16),
              _ErrorCard(
                message: '${roles.lastError}',
                onRetry: roles.refresh,
              ),
            ],
            if (roles.isLoading) ...[
              const SizedBox(height: 18),
              const Center(child: CircularProgressIndicator()),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _RoleBoundaryBanner extends StatelessWidget {
  final bool backendAvailable;

  const _RoleBoundaryBanner({required this.backendAvailable});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: HDCColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: HDCColors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.account_tree_outlined, color: HDCColors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Platform workspaces',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Choose which public HDC workspaces this account can use. '
                  'Registration starts with Customer; additional platform '
                  'roles require HDC review.'
                  '${backendAvailable ? '' : ' Role applications are disabled in local mode.'}',
                  style: const TextStyle(height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformRoleCard extends StatelessWidget {
  final HDCPlatformRole role;
  final bool active;
  final PlatformRoleApplication? application;
  final bool busy;
  final bool backendAvailable;
  final VoidCallback onApply;
  final VoidCallback onOpenProfile;

  const _PlatformRoleCard({
    required this.role,
    required this.active,
    required this.application,
    required this.busy,
    required this.backendAvailable,
    required this.onApply,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final status = _status();
    final canApply = role.requiresApproval &&
        !active &&
        application?.isPending != true &&
        backendAvailable &&
        !busy;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (active ? HDCColors.success : HDCColors.primary)
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _iconFor(role),
                color: active ? HDCColors.success : HDCColors.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status.$1,
                    style: TextStyle(color: status.$2),
                  ),
                  if (application?.reviewNote.isNotEmpty == true) ...[
                    const SizedBox(height: 5),
                    Text(
                      application!.reviewNote,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (active || !role.requiresApproval)
              FilledButton.tonal(
                onPressed: onOpenProfile,
                child: const Text('Profile'),
              )
            else if (application?.isPending == true)
              const Chip(label: Text('Pending'))
            else
              FilledButton.tonal(
                onPressed: canApply ? onApply : null,
                child: Text(
                  application?.needsChanges == true
                      ? 'Update'
                      : application?.status ==
                              HDCPlatformRoleApplicationStatus.rejected
                          ? 'Apply Again'
                          : 'Apply',
                ),
              ),
          ],
        ),
      ),
    );
  }

  (String, Color) _status() {
    if (active) return ('Active platform role', HDCColors.success);
    if (!role.requiresApproval) {
      return ('Granted automatically after registration', HDCColors.success);
    }
    switch (application?.status) {
      case HDCPlatformRoleApplicationStatus.submitted:
        return ('Awaiting HDC review', HDCColors.warning);
      case HDCPlatformRoleApplicationStatus.underReview:
        return ('Under private HDC review', HDCColors.warning);
      case HDCPlatformRoleApplicationStatus.changesRequested:
        return ('Changes requested by reviewer', HDCColors.warning);
      case HDCPlatformRoleApplicationStatus.approved:
        return ('Approved; refresh your session to activate', HDCColors.success);
      case HDCPlatformRoleApplicationStatus.rejected:
        return ('Previous application was not approved', HDCColors.danger);
      case HDCPlatformRoleApplicationStatus.withdrawn:
      case null:
        return ('Approval required', HDCColors.textSecondary);
    }
  }
}

class _RoleNotificationTile extends StatelessWidget {
  final RoleCenterNotification notification;

  const _RoleNotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          notification.priority == 'high'
              ? Icons.priority_high
              : Icons.notifications_none,
          color: notification.priority == 'high'
              ? HDCColors.warning
              : HDCColors.primary,
        ),
        title: Text(notification.title),
        subtitle: Text(notification.message),
        trailing: notification.isUnread
            ? const Icon(Icons.circle, size: 10, color: HDCColors.primary)
            : null,
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: HDCColors.danger.withValues(alpha: 0.06),
      child: ListTile(
        leading: const Icon(Icons.error_outline, color: HDCColors.danger),
        title: const Text('Role Center could not refresh'),
        subtitle: Text(message),
        trailing: TextButton(onPressed: onRetry, child: const Text('Retry')),
      ),
    );
  }
}

IconData _iconFor(HDCPlatformRole role) {
  switch (role) {
    case HDCPlatformRole.customer:
      return Icons.person_outline;
    case HDCPlatformRole.technician:
      return Icons.build_outlined;
    case HDCPlatformRole.seller:
      return Icons.sell_outlined;
    case HDCPlatformRole.business:
      return Icons.business_outlined;
    case HDCPlatformRole.supplier:
      return Icons.inventory_2_outlined;
    case HDCPlatformRole.store:
      return Icons.storefront_outlined;
  }
}
