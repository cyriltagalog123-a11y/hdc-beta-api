import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/startup/startup_manager.dart';
import '../../core/ui/hdc_brand.dart';
import '../../core/ui/hdc_colors.dart';
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
      body: HDCSignalBackdrop(
        dark: true,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HDCBrandMark(size: 88, darkSurface: true),
                  SizedBox(height: 28),
                  Text(
                    'HELPDESK CONNECT',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 29,
                      height: 1.12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.2,
                      color: HDCColors.textLight,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Technical support, connected.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: HDCColors.textMuted,
                    ),
                  ),
                  SizedBox(height: 32),
                  SizedBox(
                    width: 152,
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      borderRadius: BorderRadius.all(Radius.circular(99)),
                      color: HDCColors.signal,
                      backgroundColor: HDCColors.primarySoft,
                    ),
                  ),
                  SizedBox(height: 14),
                  Text(
                    'SECURELY OPENING YOUR WORKSPACE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: HDCColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.3,
                    ),
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
