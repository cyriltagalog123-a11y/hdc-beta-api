import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/onboarding/onboarding_role.dart';
import '../../providers/onboarding_provider.dart';
import 'role_onboarding_screen.dart';

class RoleOnboardingGate extends StatelessWidget {
  final OnboardingRole role;
  final Widget child;

  const RoleOnboardingGate({
    required this.role,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final onboarding = context.watch<OnboardingProvider>();

    if (onboarding.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!onboarding.hasCompleted(role.flowId)) {
      return RoleOnboardingScreen(
        role: role,
        destination: child,
      );
    }

    return child;
  }
}
