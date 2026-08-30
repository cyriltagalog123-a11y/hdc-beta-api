import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_exception.dart';
import '../../core/ui/hdc_colors.dart';
import '../../models/legal_document.dart';
import '../../providers/hdc_auth_provider.dart';
import '../onboarding/onboarding_gate.dart';
import 'legal_document_screen.dart';

class LegalAcceptanceScreen extends StatefulWidget {
  const LegalAcceptanceScreen({super.key});

  @override
  State<LegalAcceptanceScreen> createState() => _LegalAcceptanceScreenState();
}

class _LegalAcceptanceScreenState extends State<LegalAcceptanceScreen> {
  bool _termsAccepted = false;
  bool _privacyAcknowledged = false;

  Future<void> _open(HDCLegalDocument document) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(document: document),
      ),
    );
  }

  Future<void> _accept() async {
    if (!_termsAccepted || !_privacyAcknowledged) return;
    try {
      final identity = await context
          .read<HDCAuthProvider>()
          .acceptCurrentLegalDocuments();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => OnboardingGate(userId: identity.id),
        ),
        (_) => false,
      );
    } on Object catch (error) {
      if (!mounted) return;
      final message = error is HDCAuthException
          ? error.message
          : 'HDC could not record the legal acknowledgement. Try again.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _signOut() async {
    await context.read<HDCAuthProvider>().signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<HDCAuthProvider>().isBusy;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: HDCColors.background,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Review required'),
          actions: [
            TextButton(
              onPressed: busy ? null : _signOut,
              child: const Text('Sign out'),
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.gavel_outlined,
                        size: 52,
                        color: HDCColors.primary,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'HDC legal documents were updated',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Review both complete documents. HDC records the '
                        'document version and content fingerprints with your '
                        'acknowledgement.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Version $hdcCurrentLegalVersion',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: HDCColors.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => _open(HDCLegalDocument.terms),
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('Read Terms of Service'),
                      ),
                      CheckboxListTile(
                        value: _termsAccepted,
                        enabled: !busy,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (value) =>
                            setState(() => _termsAccepted = value == true),
                        title: const Text(
                          'I have read and accept the current Terms of Service.',
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => _open(HDCLegalDocument.privacy),
                        icon: const Icon(Icons.privacy_tip_outlined),
                        label: const Text('Read Privacy Notice'),
                      ),
                      CheckboxListTile(
                        value: _privacyAcknowledged,
                        enabled: !busy,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (value) => setState(
                          () => _privacyAcknowledged = value == true,
                        ),
                        title: const Text(
                          'I have read and acknowledge the current Privacy Notice.',
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed:
                            busy || !_termsAccepted || !_privacyAcknowledged
                            ? null
                            : _accept,
                        child: busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                ),
                              )
                            : const Text('Accept and continue'),
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
