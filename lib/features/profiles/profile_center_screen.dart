import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui/hdc_colors.dart';
import '../../models/account_identity.dart';
import '../../models/hdc_profile.dart';
import '../../providers/hdc_auth_provider.dart';
import '../../providers/hdc_profile_provider.dart';
import '../authentication/account_security_screen.dart';
import 'member_profile_edit_screen.dart';
import 'role_profile_edit_screen.dart';

class ProfileCenterScreen extends StatefulWidget {
  final HDCPlatformRole? initialRole;

  const ProfileCenterScreen({
    this.initialRole,
    super.key,
  });

  @override
  State<ProfileCenterScreen> createState() => _ProfileCenterScreenState();
}

class _ProfileCenterScreenState extends State<ProfileCenterScreen> {
  bool _startedInitialLoad = false;
  bool _appliedInitialRole = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startedInitialLoad) return;
    _startedInitialLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_refresh());
    });
  }

  void _selectInitialRoleWhenAvailable(HdcProfileProvider profiles) {
    if (_appliedInitialRole) return;
    final initialRole = widget.initialRole;
    if (initialRole == null) {
      _appliedInitialRole = true;
      return;
    }
    if (!profiles.activeRoles.contains(initialRole)) return;

    _appliedInitialRole = true;
    if (profiles.selectedRole == initialRole) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HdcProfileProvider>().selectRole(initialRole);
    });
  }

  Future<void> _refresh() async {
    final auth = context.read<HDCAuthProvider>();
    try {
      await auth.refreshIdentity();
    } on Object {
      // The profile request below reports the actionable session/API error.
    }
    if (!mounted) return;
    await context.read<HdcProfileProvider>().refresh();
  }

  Future<void> _editMemberProfile(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const MemberProfileEditScreen(),
      ),
    );
  }

  Future<void> _openAccountSecurity(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AccountSecurityScreen(),
      ),
    );
  }

  Future<void> _editRoleProfile(
    BuildContext context,
    HDCPlatformRole role,
  ) async {
    context.read<HdcProfileProvider>().selectRole(role);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoleProfileEditScreen(role: role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profiles = context.watch<HdcProfileProvider>();
    _selectInitialRoleWhenAvailable(profiles);
    final member = profiles.memberProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profiles & Workspaces'),
        actions: [
          IconButton(
            tooltip: 'Refresh profiles',
            onPressed: profiles.isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _OneAccountBanner(),
            const SizedBox(height: 18),
            if (member != null)
              _MemberProfileCard(
                profile: member,
                onEdit: () => _editMemberProfile(context),
              ),
            const SizedBox(height: 12),
            _AccountSecurityCard(
              publicMemberId:
                  context.watch<HDCAuthProvider>().identity?.publicMemberId,
              onOpen: () => _openAccountSecurity(context),
            ),
            const SizedBox(height: 24),
            Text(
              'Choose a workspace profile',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Switch profiles here without signing out. Your email, password, '
              'security, and account ID stay the same.',
            ),
            const SizedBox(height: 14),
            if (profiles.activeRoles.isEmpty)
              const _EmptyActiveRolesCard()
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: HDCPlatformRole.values
                    .where(profiles.activeRoles.contains)
                    .map(
                      (role) => ChoiceChip(
                        avatar: Icon(_roleIcon(role), size: 18),
                        label: Text(role.label),
                        selected: profiles.selectedRole == role,
                        onSelected: (_) => profiles.selectRole(role),
                      ),
                    )
                    .toList(growable: false),
              ),
            const SizedBox(height: 16),
            if (profiles.selectedRole != null)
              _SelectedWorkspaceCard(
                role: profiles.selectedRole!,
                profile: profiles.profileFor(profiles.selectedRole!),
                loading: profiles.isLoading,
                onOpen: () => _editRoleProfile(
                  context,
                  profiles.selectedRole!,
                ),
              ),
            const SizedBox(height: 26),
            Text(
              'All platform profiles',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            ...HDCPlatformRole.values.map(
              (role) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RoleProfileTile(
                  role: role,
                  active: profiles.activeRoles.contains(role),
                  profile: profiles.profileFor(role),
                  onOpen: () => _editRoleProfile(context, role),
                ),
              ),
            ),
            if (!profiles.backendAvailable) ...[
              const SizedBox(height: 16),
              const _LocalModeCard(),
            ],
            if (profiles.lastError != null) ...[
              const SizedBox(height: 16),
              _ProfileErrorCard(
                message: '${profiles.lastError}',
                onRetry: profiles.refresh,
              ),
            ],
            if (profiles.isLoading) ...[
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator()),
            ],
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

class _OneAccountBanner extends StatelessWidget {
  const _OneAccountBanner();

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
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.hub_outlined, color: HDCColors.primary),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'One HDC account. Multiple profiles.',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: HDCColors.textPrimary,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'The shared member profile is your master identity. Each '
                  'active platform role has its own public name, information, '
                  'and workspace settings under that same login.',
                  style: TextStyle(height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberProfileCard extends StatelessWidget {
  final HDCMemberProfile profile;
  final VoidCallback onEdit;

  const _MemberProfileCard({
    required this.profile,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: HDCColors.primary.withValues(alpha: 0.10),
                  child: Text(
                    _initials(profile.displayName),
                    style: const TextStyle(
                      color: HDCColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.displayName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        profile.email,
                        style: const TextStyle(
                          color: HDCColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Chip(label: Text('Master')),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _CompletionBar(value: profile.completionPercent),
                ),
                const SizedBox(width: 18),
                FilledButton.tonalIcon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountSecurityCard extends StatelessWidget {
  final String? publicMemberId;
  final VoidCallback onOpen;

  const _AccountSecurityCard({
    required this.publicMemberId,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: HDCColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.shield_outlined, color: HDCColors.primary),
        ),
        title: const Text('Account Security'),
        subtitle: Text(
          publicMemberId == null
              ? 'Set or replace your private recovery answers.'
              : '$publicMemberId · Set or replace private recovery answers.',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onOpen,
      ),
    );
  }
}

class _SelectedWorkspaceCard extends StatelessWidget {
  final HDCPlatformRole role;
  final HDCPlatformRoleProfile? profile;
  final bool loading;
  final VoidCallback onOpen;

  const _SelectedWorkspaceCard({
    required this.role,
    required this.profile,
    required this.loading,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = profile?.publicName ?? role.label;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HDCColors.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(_roleIcon(role), color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${role.label} workspace',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 3),
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (profile?.headline.isNotEmpty == true) ...[
                  const SizedBox(height: 3),
                  Text(
                    profile!.headline,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: HDCColors.primary,
            ),
            onPressed: loading ? null : onOpen,
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }
}

class _RoleProfileTile extends StatelessWidget {
  final HDCPlatformRole role;
  final bool active;
  final HDCPlatformRoleProfile? profile;
  final VoidCallback onOpen;

  const _RoleProfileTile({
    required this.role,
    required this.active,
    required this.profile,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: (active ? HDCColors.success : HDCColors.textSecondary)
                .withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            _roleIcon(role),
            color: active ? HDCColors.success : HDCColors.textSecondary,
          ),
        ),
        title: Text(profile?.publicName ?? '${role.label} profile'),
        subtitle: Text(
          active
              ? '${profile?.completionPercent ?? 17}% complete · ${role.label} is active'
              : 'Not active · Apply or obtain approval in Role Center',
        ),
        trailing: active
            ? IconButton(
                tooltip: 'Open ${role.label} profile',
                onPressed: onOpen,
                icon: const Icon(Icons.chevron_right),
              )
            : const Icon(Icons.lock_outline, color: HDCColors.textSecondary),
        onTap: active ? onOpen : null,
      ),
    );
  }
}

class _CompletionBar extends StatelessWidget {
  final int value;

  const _CompletionBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Shared profile $value% complete',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 7),
        LinearProgressIndicator(
          value: value / 100,
          minHeight: 7,
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    );
  }
}

class _EmptyActiveRolesCard extends StatelessWidget {
  const _EmptyActiveRolesCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.hourglass_empty),
        title: Text('No active platform profile'),
        subtitle: Text('Refresh your session or manage roles in Role Center.'),
      ),
    );
  }
}

class _LocalModeCard extends StatelessWidget {
  const _LocalModeCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.cloud_off_outlined),
        title: Text('Profile saving is unavailable in local mode'),
        subtitle: Text('Connect the authenticated HDC API to save profiles.'),
      ),
    );
  }
}

class _ProfileErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ProfileErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: HDCColors.danger.withValues(alpha: 0.06),
      child: ListTile(
        leading: const Icon(Icons.error_outline, color: HDCColors.danger),
        title: const Text('Profiles could not refresh'),
        subtitle: Text(message),
        trailing: TextButton(onPressed: onRetry, child: const Text('Retry')),
      ),
    );
  }
}

String _initials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((value) => value.isNotEmpty)
      .take(2);
  final result = words.map((word) => word[0].toUpperCase()).join();
  return result.isEmpty ? 'H' : result;
}

IconData _roleIcon(HDCPlatformRole role) {
  switch (role) {
    case HDCPlatformRole.customer:
      return Icons.person_outline;
    case HDCPlatformRole.technician:
      return Icons.build_outlined;
    case HDCPlatformRole.business:
      return Icons.business_outlined;
    case HDCPlatformRole.seller:
      return Icons.sell_outlined;
    case HDCPlatformRole.supplier:
      return Icons.inventory_2_outlined;
    case HDCPlatformRole.store:
      return Icons.storefront_outlined;
  }
}
