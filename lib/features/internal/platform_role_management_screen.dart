import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui/hdc_colors.dart';
import '../../models/account_identity.dart';
import '../../models/platform_role_admin_member.dart';
import '../../providers/platform_role_admin_provider.dart';

class PlatformRoleManagementScreen extends StatefulWidget {
  const PlatformRoleManagementScreen({super.key});

  @override
  State<PlatformRoleManagementScreen> createState() =>
      _PlatformRoleManagementScreenState();
}

class _PlatformRoleManagementScreenState
    extends State<PlatformRoleManagementScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_search());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    try {
      await context
          .read<PlatformRoleAdminProvider>()
          .search(_searchController.text);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Member search failed: $error')),
      );
    }
  }

  Future<void> _changeRole(
    PlatformRoleAdminMember member,
    HDCPlatformRole role,
    bool assign,
  ) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(assign ? 'Assign ${role.label} role?' : 'Remove ${role.label} role?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${member.displayName}\n${member.email}\n\n'
              'This is an audited administrative action. It changes platform '
              'capability only; it does not grant an internal HDC staff role.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              autofocus: true,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Audit reason',
                hintText: 'Why is this role being assigned or removed?',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (reasonController.text.trim().length < 3) return;
              Navigator.of(dialogContext).pop(true);
            },
            child: Text(assign ? 'Assign Role' : 'Remove Role'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      reasonController.dispose();
      return;
    }
    final reason = reasonController.text;
    reasonController.dispose();

    try {
      await context.read<PlatformRoleAdminProvider>().changeRole(
            member: member,
            role: role,
            assign: assign,
            reason: reason,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            assign
                ? '${role.label} assigned to ${member.displayName}.'
                : '${role.label} removed from ${member.displayName}.',
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Role change failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlatformRoleAdminProvider>();
    return Scaffold(
      backgroundColor: HDCColors.background,
      appBar: AppBar(
        title: const Text('Platform Role Management'),
        actions: [
          IconButton(
            tooltip: 'Refresh members',
            onPressed: provider.isLoading ? null : _search,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: !provider.hasAccess
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Owner, Super Admin, or approved Admin access is required.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      labelText: 'Find member',
                      hintText: 'Name, email, or HDC member ID',
                      prefixIcon: const Icon(Icons.manage_search_outlined),
                      suffixIcon: IconButton(
                        tooltip: 'Search',
                        onPressed: provider.isLoading ? null : _search,
                        icon: const Icon(Icons.search),
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('Customer is the locked baseline role'),
                      subtitle: Text(
                        'You can assign or revoke Technician, Seller, Business, '
                        'Supplier, and Store. Internal staff roles are managed '
                        'separately and are never changed here.',
                      ),
                    ),
                  ),
                ),
                if (provider.isLoading) const LinearProgressIndicator(),
                Expanded(
                  child: provider.members.isEmpty
                      ? Center(
                          child: Text(
                            provider.lastError == null
                                ? 'No members found.'
                                : '${provider.lastError}',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: provider.members.length,
                          itemBuilder: (context, index) => _MemberRoleCard(
                            member: provider.members[index],
                            saving: provider.isSaving,
                            onChangeRole: _changeRole,
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

class _MemberRoleCard extends StatelessWidget {
  final PlatformRoleAdminMember member;
  final bool saving;
  final Future<void> Function(
    PlatformRoleAdminMember member,
    HDCPlatformRole role,
    bool assign,
  ) onChangeRole;

  const _MemberRoleCard({
    required this.member,
    required this.saving,
    required this.onChangeRole,
  });

  @override
  Widget build(BuildContext context) {
    const manageable = [
      HDCPlatformRole.technician,
      HDCPlatformRole.seller,
      HDCPlatformRole.business,
      HDCPlatformRole.supplier,
      HDCPlatformRole.store,
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              member.displayName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '${member.email} · ${member.publicMemberId}',
              style: const TextStyle(color: HDCColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                const Chip(
                  avatar: Icon(Icons.lock_outline, size: 16),
                  label: Text('Customer'),
                ),
                ...manageable.map((role) {
                  final active = member.platformRoles.contains(role);
                  return FilterChip(
                    selected: active,
                    label: Text(role.label),
                    avatar: Icon(
                      active ? Icons.check_circle_outline : Icons.add_circle_outline,
                      size: 16,
                    ),
                    onSelected: saving
                        ? null
                        : (_) => onChangeRole(member, role, !active),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
