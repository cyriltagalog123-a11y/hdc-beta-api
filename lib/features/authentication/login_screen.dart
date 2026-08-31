import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_exception.dart';
import '../../core/config/app_config.dart';
import '../../core/ui/hdc_brand.dart';
import '../../core/ui/hdc_button.dart';
import '../../core/ui/hdc_card.dart';
import '../../core/ui/hdc_colors.dart';
import '../../core/ui/hdc_spacing.dart';
import '../../core/ui/hdc_textfield.dart';
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

  void _setAccountMode(bool creatingAccount) {
    if (_creatingAccount == creatingAccount) return;
    setState(() => _creatingAccount = creatingAccount);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<HDCAuthProvider>();
    final busy = auth.isBusy;

    return Scaffold(
      body: HDCSignalBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              final horizontalPadding = wide ? 36.0 : 18.0;

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: wide ? 36 : 20,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Expanded(flex: 5, child: _AuthBrandPanel()),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 6,
                                child: _buildAuthCard(context, busy: busy),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _AuthBrandPanel(compact: true),
                              const SizedBox(height: 16),
                              _buildAuthCard(context, busy: busy),
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAuthCard(BuildContext context, {required bool busy}) {
    return HDCCard(
      elevated: true,
      padding: const EdgeInsets.all(0),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _creatingAccount ? 'NEW HDC MEMBER' : 'ACCOUNT ACCESS',
                    style: const TextStyle(
                      color: HDCColors.secondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    _creatingAccount
                        ? 'Create your support identity'
                        : 'Welcome back',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _creatingAccount
                        ? 'One secure account connects your Customer profile and every role approved later.'
                        : 'Sign in to continue your requests, offers, active services, and account records.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: _AuthenticationModeSwitch(
                creatingAccount: _creatingAccount,
                enabled: !busy,
                onChanged: _setAccountMode,
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_creatingAccount) ...[
                    HDCTextField(
                      key: const Key('hdc-display-name-field'),
                      controller: _displayNameController,
                      label: 'Display Name',
                      icon: Icons.badge_outlined,
                      enabled: !busy,
                      textInputAction: TextInputAction.next,
                      maxLength: 80,
                    ),
                    const SizedBox(height: 12),
                  ],
                  HDCTextField(
                    key: const Key('hdc-email-field'),
                    controller: _emailController,
                    label: 'Email Address',
                    icon: Icons.email_outlined,
                    enabled: !busy,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                  ),
                  const SizedBox(height: 16),
                  HDCTextField(
                    key: const Key('hdc-password-field'),
                    controller: _passwordController,
                    label: 'Password',
                    icon: Icons.lock_outline,
                    enabled: !busy,
                    obscureText: _hidePassword,
                    helperText: _creatingAccount
                        ? 'Use 12 to 128 characters.'
                        : null,
                    autofillHints: [
                      _creatingAccount
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    onSubmitted: (_) {
                      if (!busy && !_creatingAccount) _submit();
                    },
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
                          : () =>
                                setState(() => _hidePassword = !_hidePassword),
                    ),
                  ),
                  if (_creatingAccount) ...[
                    const SizedBox(height: 24),
                    _buildRecoverySection(context, busy: busy),
                    const SizedBox(height: 24),
                    _buildLegalSection(context, busy: busy),
                  ],
                  const SizedBox(height: 24),
                  HDCButton(
                    key: const Key('hdc-auth-submit'),
                    label: _creatingAccount ? 'Create Account' : 'Sign In',
                    icon: _creatingAccount
                        ? Icons.person_add_alt_1_rounded
                        : Icons.arrow_forward_rounded,
                    onPressed: _submit,
                    busy: busy,
                    expanded: true,
                  ),
                  if (!_creatingAccount)
                    Align(
                      child: TextButton(
                        onPressed: busy ? null : _forgotPassword,
                        child: const Text('Forgot Password?'),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'PREVIEW ACCESS',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                              ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  HDCButton(
                    label: 'Continue as Guest',
                    icon: Icons.visibility_outlined,
                    onPressed: busy ? null : _continueAsGuest,
                    expanded: true,
                    style: HDCButtonStyle.secondary,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Guest mode is preview-only. Posting requests, booking services, and account actions require registration or sign-in.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: HDCColors.textSecondary,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: HDCColors.signal,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Version ${AppConfig.version}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecoverySection(BuildContext context, {required bool busy}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: HDCColors.signal.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.key_outlined,
                color: HDCColors.success,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Private account recovery',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Three protected answers restore access safely.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: _hideRecoveryAnswers
                  ? 'Show recovery answers'
                  : 'Hide recovery answers',
              onPressed: busy
                  ? null
                  : () => setState(
                      () => _hideRecoveryAnswers = !_hideRecoveryAnswers,
                    ),
              icon: Icon(
                _hideRecoveryAnswers
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Use three different answers you can remember. HDC stores only protected hashes and never shows the answers to reviewers.',
          style: TextStyle(color: HDCColors.textSecondary, height: 1.45),
        ),
        const SizedBox(height: 16),
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
              prefixIcon: const Icon(Icons.shield_outlined),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildLegalSection(BuildContext context, {required bool busy}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HDCColors.surfaceMuted,
        borderRadius: BorderRadius.circular(HDCSpacing.radiusMedium),
        border: Border.all(color: HDCColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                color: HDCColors.secondary,
              ),
              const SizedBox(width: 10),
              Text(
                'Legal documents',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => _openLegalDocument(HDCLegalDocument.terms),
                icon: const Icon(Icons.description_outlined),
                label: const Text('Read Terms'),
              ),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => _openLegalDocument(HDCLegalDocument.privacy),
                icon: const Icon(Icons.privacy_tip_outlined),
                label: const Text('Read Privacy'),
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
              'HDC records version $hdcCurrentLegalVersion and the content fingerprints with this account.',
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthenticationModeSwitch extends StatelessWidget {
  final bool creatingAccount;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _AuthenticationModeSwitch({
    required this.creatingAccount,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: HDCColors.surfaceStrong,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              label: 'Sign In',
              icon: Icons.login_rounded,
              selected: !creatingAccount,
              onTap: enabled ? () => onChanged(false) : null,
            ),
          ),
          Expanded(
            child: _ModeButton(
              label: 'Create Account',
              icon: Icons.person_add_alt_1_rounded,
              selected: creatingAccount,
              onTap: enabled ? () => onChanged(true) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? HDCColors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? HDCColors.secondary : HDCColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? HDCColors.textPrimary
                        : HDCColors.textSecondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthBrandPanel extends StatelessWidget {
  final bool compact;

  const _AuthBrandPanel({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(HDCSpacing.radiusLarge),
      child: HDCSignalBackdrop(
        dark: true,
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 236 : 650),
          padding: EdgeInsets.all(compact ? 22 : 38),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              HDCBrandLockup(
                light: true,
                compact: compact,
                markSize: compact ? 42 : 58,
              ),
              if (!compact) ...[
                const SizedBox(height: 72),
                const HDCSignalPill(
                  label: 'CONTROLLED BETA • BUILD 23',
                  icon: Icons.bolt_rounded,
                  light: true,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Less searching.\nMore solving.',
                  style: TextStyle(
                    color: HDCColors.textLight,
                    fontSize: 42,
                    height: 1.06,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'A connected workspace for technical requests, qualified help, transaction records, and safer resolutions.',
                  style: TextStyle(
                    color: HDCColors.textLight.withValues(alpha: 0.74),
                    fontSize: 16,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 32),
                const _AuthFeature(
                  icon: Icons.manage_search_rounded,
                  title: 'Describe once',
                  description: 'Reach technicians through one tracked request.',
                ),
                const SizedBox(height: 14),
                const _AuthFeature(
                  icon: Icons.hub_outlined,
                  title: 'Keep the full context',
                  description:
                      'Offers, chat, receipts, and disputes stay connected.',
                ),
                const SizedBox(height: 14),
                const _AuthFeature(
                  icon: Icons.shield_outlined,
                  title: 'Backend-authoritative',
                  description:
                      'Account and transaction history is not device-only.',
                ),
              ] else ...[
                const SizedBox(height: 24),
                const Text(
                  'Less searching. More solving.',
                  style: TextStyle(
                    color: HDCColors.textLight,
                    fontSize: 26,
                    height: 1.12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your connected technical support workspace.',
                  style: TextStyle(
                    color: HDCColors.textLight.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 18),
                const HDCSignalPill(
                  label: 'CONTROLLED BETA • BUILD 23',
                  light: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _AuthFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: HDCColors.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: HDCColors.accent.withValues(alpha: 0.20)),
          ),
          child: Icon(icon, color: HDCColors.accent, size: 21),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: HDCColors.textLight,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: TextStyle(
                  color: HDCColors.textLight.withValues(alpha: 0.64),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
