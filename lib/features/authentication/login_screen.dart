import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_exception.dart';
import '../../core/config/app_config.dart';
import '../../core/ui/hdc_colors.dart';
import '../../models/account_recovery.dart';
import '../../models/legal_document.dart';
import '../../providers/hdc_auth_provider.dart';
import '../onboarding/onboarding_gate.dart';
import 'legal_acceptance_screen.dart';
import 'legal_document_screen.dart';
import 'password_recovery_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _recoveryControllers = List.generate(
    hdcRegistrationRecoveryQuestions.length,
    (_) => TextEditingController(),
  );

  bool _hidePassword = true;
  bool _hideRecoveryAnswers = true;
  bool _creatingAccount = false;
  bool _termsAccepted = false;
  bool _privacyAcknowledged = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    for (final controller in _recoveryControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  List<AccountRecoveryAnswer> _recoveryAnswers() {
    return [
      for (
        var index = 0;
        index < hdcRegistrationRecoveryQuestions.length;
        index += 1
      )
        AccountRecoveryAnswer(
          questionCode: hdcRegistrationRecoveryQuestions[index].questionCode,
          answer: _recoveryControllers[index].text,
        ),
    ];
  }

  Future<void> _submit() async {
    final auth = context.read<HDCAuthProvider>();

    try {
      final identity = _creatingAccount
          ? await auth.signUp(
              email: _emailController.text,
              password: _passwordController.text,
              displayName: _displayNameController.text,
              recoveryAnswers: _recoveryAnswers(),
              termsAccepted: _termsAccepted,
              privacyAcknowledged: _privacyAcknowledged,
            )
          : await auth.signIn(
              identifier: _emailController.text,
              password: _passwordController.text,
            );

      if (!mounted) return;

      if (_creatingAccount && !auth.authenticated) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Account created'),
            content: const Text(
              'Your unique HDC account and Customer profile were created. '
              'You can now sign in with the email address and password you '
              'registered.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Sign In'),
              ),
            ],
          ),
        );
        if (mounted) {
          _passwordController.clear();
          _displayNameController.clear();
          for (final controller in _recoveryControllers) {
            controller.clear();
          }
          setState(() {
            _creatingAccount = false;
            _termsAccepted = false;
            _privacyAcknowledged = false;
          });
        }
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => identity.legalAcceptanceRequired
              ? const LegalAcceptanceScreen()
              : OnboardingGate(userId: identity.id),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    }
  }

  Future<void> _openLegalDocument(HDCLegalDocument document) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(document: document),
      ),
    );
  }

  void _continueAsGuest() {
    context.read<HDCAuthProvider>().continueAsGuest();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const OnboardingGate(userId: 'guest-local'),
      ),
    );
  }

  Future<void> _forgotPassword() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PasswordRecoveryScreen(initialEmail: _emailController.text.trim()),
      ),
    );
  }

  String _friendlyError(Object error) {
    if (error is HDCAuthException) return error.message;
    if (error is ArgumentError) {
      final message = error.message;
      return message is String && message.isNotEmpty
          ? message
          : 'Check the information you entered and try again.';
    }
    if (error is StateError) return error.message;
    return 'HDC could not complete that authentication request. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<HDCAuthProvider>();
    final busy = auth.isBusy;

    return Scaffold(
      backgroundColor: HDCColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.support_agent,
                    size: 82,
                    color: HDCColors.primary,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'HelpDesk Connect',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _creatingAccount
                        ? 'Create one secure account for all HDC profiles'
                        : 'Technical Support Platform',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: HDCColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 36),
                  if (_creatingAccount) ...[
                    TextField(
                      controller: _displayNameController,
                      enabled: !busy,
                      textInputAction: TextInputAction.next,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _emailController,
                    enabled: !busy,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _passwordController,
                    enabled: !busy,
                    obscureText: _hidePassword,
                    autofillHints: [
                      _creatingAccount
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    onSubmitted: (_) {
                      if (!busy && !_creatingAccount) _submit();
                    },
                    decoration: InputDecoration(
                      labelText: 'Password',
                      helperText: _creatingAccount
                          ? 'Use 12 to 128 characters.'
                          : null,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: _hidePassword
                            ? 'Show password'
                            : 'Hide password',
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: busy
                            ? null
                            : () => setState(
                                () => _hidePassword = !_hidePassword,
                              ),
                      ),
                    ),
                  ),
                  if (_creatingAccount) ...[
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Private account recovery',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: _hideRecoveryAnswers
                              ? 'Show recovery answers'
                              : 'Hide recovery answers',
                          onPressed: busy
                              ? null
                              : () => setState(
                                  () => _hideRecoveryAnswers =
                                      !_hideRecoveryAnswers,
                                ),
                          icon: Icon(
                            _hideRecoveryAnswers
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'Use three different answers you can remember. HDC stores '
                      'only protected hashes and never shows the answers to reviewers.',
                      style: TextStyle(
                        color: HDCColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (
                      var index = 0;
                      index < hdcRegistrationRecoveryQuestions.length;
                      index += 1
                    ) ...[
                      TextField(
                        controller: _recoveryControllers[index],
                        enabled: !busy,
                        obscureText: _hideRecoveryAnswers,
                        maxLength: 160,
                        textInputAction:
                            index == hdcRegistrationRecoveryQuestions.length - 1
                            ? TextInputAction.done
                            : TextInputAction.next,
                        decoration: InputDecoration(
                          labelText:
                              'Question ${index + 1}: ${hdcRegistrationRecoveryQuestions[index].prompt}',
                          helperText: '4 to 160 characters',
                          alignLabelWithHint: true,
                          prefixIcon: const Icon(Icons.key_outlined),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const Text(
                      'Legal documents',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () =>
                                    _openLegalDocument(HDCLegalDocument.terms),
                          icon: const Icon(Icons.description_outlined),
                          label: const Text('Read Terms'),
                        ),
                        OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () => _openLegalDocument(
                                  HDCLegalDocument.privacy,
                                ),
                          icon: const Icon(Icons.privacy_tip_outlined),
                          label: const Text('Read Privacy Notice'),
                        ),
                      ],
                    ),
                    CheckboxListTile(
                      value: _termsAccepted,
                      enabled: !busy,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (value) =>
                          setState(() => _termsAccepted = value == true),
                      title: const Text(
                        'I have read and accept the HDC Beta Terms of Service.',
                      ),
                    ),
                    CheckboxListTile(
                      value: _privacyAcknowledged,
                      enabled: !busy,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (value) =>
                          setState(() => _privacyAcknowledged = value == true),
                      title: const Text(
                        'I have read and acknowledge the HDC Beta Privacy Notice.',
                      ),
                      subtitle: const Text(
                        'HDC records version $hdcCurrentLegalVersion and the '
                        'content fingerprints with this account.',
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: busy ? null : _submit,
                      child: busy
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            )
                          : Text(
                              _creatingAccount ? 'Create Account' : 'Sign In',
                              style: const TextStyle(fontSize: 18),
                            ),
                    ),
                  ),
                  if (!_creatingAccount)
                    TextButton(
                      onPressed: busy ? null : _forgotPassword,
                      child: const Text('Forgot Password?'),
                    ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(
                            () => _creatingAccount = !_creatingAccount,
                          ),
                    child: Text(
                      _creatingAccount
                          ? 'Already have an account? Sign In'
                          : 'Create a Beta Account',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : _continueAsGuest,
                    child: const Text('Continue as Guest'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Guest mode is preview-only. Posting requests, booking '
                    'services, and account actions require registration or sign-in.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: HDCColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Version ${AppConfig.version}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: HDCColors.textSecondary),
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
