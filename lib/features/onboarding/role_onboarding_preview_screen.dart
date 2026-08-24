import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/onboarding/onboarding_role.dart';
import '../../core/ui/hdc_colors.dart';
import '../../providers/onboarding_provider.dart';
import 'role_onboarding_gate.dart';

class RoleOnboardingPreviewScreen extends StatelessWidget {
  const RoleOnboardingPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final onboarding = context.watch<OnboardingProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Role Welcome Preview'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Test role-specific onboarding',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          Text(
            'Open a role below. Its welcome screen appears once, then HDC '
            'remembers the completion for this account.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: HDCColors.textSecondary,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 24),
          ...OnboardingRole.values.map(
            (role) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _RolePreviewCard(
                role: role,
                completed: onboarding.hasCompleted(role.flowId),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RolePreviewCard extends StatelessWidget {
  final OnboardingRole role;
  final bool completed;

  const _RolePreviewCard({
    required this.role,
    required this.completed,
  });

  Future<void> _reset(BuildContext context) async {
    await context.read<OnboardingProvider>().reset(role.flowId);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${role.title} welcome was reset.'),
      ),
    );
  }

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoleOnboardingGate(
          role: role,
          child: _RoleWorkspacePlaceholder(role: role),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: HDCColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.badge_outlined,
                color: HDCColors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    completed ? 'Welcome completed' : 'First-time welcome ready',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: completed
                              ? HDCColors.success
                              : HDCColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            if (completed)
              IconButton(
                tooltip: 'Reset welcome',
                onPressed: () => _reset(context),
                icon: const Icon(Icons.restart_alt),
              ),
            FilledButton(
              onPressed: () => _open(context),
              child: Text(completed ? 'Open' : 'Preview'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleWorkspacePlaceholder extends StatelessWidget {
  final OnboardingRole role;

  const _RoleWorkspacePlaceholder({
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(role.title),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_outlined,
                  size: 72,
                  color: HDCColors.success,
                ),
                const SizedBox(height: 20),
                Text(
                  '${role.title} workspace',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'The role welcome is complete. This placeholder will later '
                  'be replaced by the real role dashboard or setup screen.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
