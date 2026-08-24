import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/onboarding/onboarding_flow_ids.dart';
import '../../providers/onboarding_provider.dart';
import '../dashboard/dashboard_screen.dart';
import 'platform_onboarding_screen.dart';

class OnboardingGate extends StatefulWidget {
  final String userId;

  const OnboardingGate({
    required this.userId,
    super.key,
  });

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OnboardingProvider>().loadForUser(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingProvider>(
      builder: (context, onboarding, child) {
        if (onboarding.isLoading || onboarding.userId != widget.userId) {
          return const _OnboardingLoadingScreen();
        }

        if (onboarding.error != null) {
          return _OnboardingErrorScreen(
            onRetry: () => onboarding.loadForUser(widget.userId),
          );
        }

        if (!onboarding.hasCompleted(OnboardingFlowIds.platform)) {
          return const PlatformOnboardingScreen();
        }

        return const DashboardScreen();
      },
    );
  }
}

class _OnboardingLoadingScreen extends StatelessWidget {
  const _OnboardingLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _OnboardingErrorScreen extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _OnboardingErrorScreen({
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 64,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'We could not load your HDC welcome experience.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Check the app storage and try again.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: onRetry,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
