import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/onboarding/onboarding_role.dart';
import '../../core/ui/hdc_colors.dart';
import '../../providers/onboarding_provider.dart';

class RoleOnboardingScreen extends StatefulWidget {
  final OnboardingRole role;
  final Widget destination;

  const RoleOnboardingScreen({
    required this.role,
    required this.destination,
    super.key,
  });

  @override
  State<RoleOnboardingScreen> createState() =>
      _RoleOnboardingScreenState();
}

class _RoleOnboardingScreenState extends State<RoleOnboardingScreen> {
  bool _isCompleting = false;

  Future<void> _complete() async {
    if (_isCompleting) {
      return;
    }

    setState(() {
      _isCompleting = true;
    });

    try {
      await context.read<OnboardingProvider>().complete(
        widget.role.flowId,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => widget.destination,
        ),
      );
    } on Object {
      if (!mounted) return;

      setState(() {
        _isCompleting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'HDC could not save this welcome flow. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.role;

    return Scaffold(
      backgroundColor: HDCColors.background,
      appBar: AppBar(
        title: Text(role.title),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RoleIcon(role: role),
                      const SizedBox(height: 24),
                      Text(
                        role.welcomeTitle,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        role.description,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: HDCColors.textSecondary,
                              height: 1.5,
                            ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Your first steps',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      ...role.checklist.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.check_circle_outline,
                                  color: HDCColors.success,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: _isCompleting ? null : _complete,
                          icon: _isCompleting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward),
                          label: Text(role.primaryActionLabel),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'This introduction appears only the first time '
                          'this role is opened.',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: HDCColors.textSecondary,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleIcon extends StatelessWidget {
  final OnboardingRole role;

  const _RoleIcon({
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;

    switch (role) {
      case OnboardingRole.buyer:
        icon = Icons.shopping_bag_outlined;
      case OnboardingRole.technician:
        icon = Icons.handyman_outlined;
      case OnboardingRole.seller:
        icon = Icons.storefront_outlined;
      case OnboardingRole.store:
        icon = Icons.business_outlined;
    }

    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: HDCColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Icon(
        icon,
        size: 44,
        color: HDCColors.primary,
      ),
    );
  }
}
