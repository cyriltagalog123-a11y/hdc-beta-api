import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/startup/startup_manager.dart';
import '../../providers/hdc_auth_provider.dart';
import '../authentication/legal_acceptance_screen.dart';
import '../authentication/login_screen.dart';
import '../onboarding/onboarding_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startApp();
  }

  Future<void> _startApp() async {
    const startupManager = StartupManager();
    await startupManager.initialize();

    if (!mounted) return;

    final auth = context.read<HDCAuthProvider>();
    await auth.initialize();

    if (!mounted) return;

    final identity = auth.identity;
    final page = auth.authenticated && identity != null
        ? identity.legalAcceptanceRequired
              ? const LegalAcceptanceScreen()
              : OnboardingGate(userId: identity.id)
        : const LoginScreen();

    Navigator.of(context)
        .pushReplacement(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1F3A),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.support_agent, size: 100, color: Colors.white),
            SizedBox(height: 20),
            Text(
              'HelpDesk Connect',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Building the future of technical support',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            SizedBox(height: 40),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
