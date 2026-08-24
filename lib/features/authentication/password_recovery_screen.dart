import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_exception.dart';
import '../../core/ui/hdc_colors.dart';
import '../../models/account_recovery.dart';
import '../../providers/hdc_auth_provider.dart';

enum _RecoveryStage {
  email,
  questions,
  reset,
  manualReview,
  complete,
}

class PasswordRecoveryScreen extends StatefulWidget {
  final String initialEmail;

  const PasswordRecoveryScreen({
    this.initialEmail = '',
    super.key,
  });

  @override
  State<PasswordRecoveryScreen> createState() =>
      _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  late final TextEditingController _emailController;
  final _answerControllers = List.generate(3, (_) => TextEditingController());
  final _resetCodeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _RecoveryStage _stage = _RecoveryStage.email;
  List<AccountRecoveryQuestion> _questions = const [];
  bool _hideAnswers = true;
  bool _hidePassword = true;
  DateTime? _expiresAt;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    for (final controller in _answerControllers) {
      controller.dispose();
    }
    _resetCodeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final questions = await context
          .read<HDCAuthProvider>()
          .startPasswordRecovery(_emailController.text);
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _stage = _RecoveryStage.questions;
      });
    } on Object catch (error) {
      _showError(error);
    }
  }

  Future<void> _verify() async {
    if (_questions.length != _answerControllers.length) return;
    final answers = [
      for (var index = 0; index < _questions.length; index += 1)
        AccountRecoveryAnswer(
          questionCode: _questions[index].questionCode,
          answer: _answerControllers[index].text,
        ),
    ];
    try {
      final verification = await context
          .read<HDCAuthProvider>()
          .verifyRecoveryAnswers(
            email: _emailController.text,
            answers: answers,
          );
      if (!mounted) return;
      for (final controller in _answerControllers) {
        controller.clear();
      }
      if (verification.isVerified) {
        _resetCodeController.text = verification.resetToken!;
        setState(() {
          _expiresAt = verification.expiresAt;
          _stage = _RecoveryStage.reset;
        });
      } else {
        setState(() => _stage = _RecoveryStage.manualReview);
      }
    } on Object catch (error) {
      _showError(error);
    }
  }

  Future<void> _reset() async {
    final password = _passwordController.text;
    if (password.length < 12 || password.length > 128) {
      _showMessage('Your new password must contain 12 to 128 characters.');
      return;
    }
    if (password != _confirmPasswordController.text) {
      _showMessage('The new passwords do not match.');
      return;
    }
    if (_resetCodeController.text.trim().length < 32) {
      _showMessage('Enter the complete one-time reset code.');
      return;
    }

    try {
      await context.read<HDCAuthProvider>().resetPassword(
            resetToken: _resetCodeController.text,
            newPassword: password,
          );
      if (!mounted) return;
      setState(() => _stage = _RecoveryStage.complete);
    } on Object catch (error) {
      _showError(error);
    }
  }

  void _useManualCode() {
    _resetCodeController.clear();
    setState(() {
      _expiresAt = null;
      _stage = _RecoveryStage.reset;
    });
  }

  void _showError(Object error) {
    if (!mounted) return;
    final message = error is HDCAuthException
        ? error.message
        : 'HDC could not complete account recovery. Please try again.';
    _showMessage(message);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<HDCAuthProvider>().isBusy;
    return Scaffold(
      appBar: AppBar(title: const Text('Recover HDC Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _content(busy),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(bool busy) {
    switch (_stage) {
      case _RecoveryStage.email:
        return _EmailStep(
          key: const ValueKey('email'),
          controller: _emailController,
          busy: busy,
          onContinue: _start,
        );
      case _RecoveryStage.questions:
        return Column(
          key: const ValueKey('questions'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _StepHeader(
              icon: Icons.shield_outlined,
              title: 'Answer all three questions',
              message:
                  'Two or three correct answers create a 15-minute one-time reset code. HDC never reveals which answers matched.',
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: busy
                    ? null
                    : () => setState(() => _hideAnswers = !_hideAnswers),
                icon: Icon(
                  _hideAnswers
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                label: Text(_hideAnswers ? 'Show answers' : 'Hide answers'),
              ),
            ),
            for (var index = 0; index < _questions.length; index += 1) ...[
              TextField(
                controller: _answerControllers[index],
                enabled: !busy,
                obscureText: _hideAnswers,
                maxLength: 160,
                decoration: InputDecoration(
                  labelText: '${index + 1}. ${_questions[index].prompt}',
                  helperText: '4 to 160 characters',
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
            ],
            FilledButton.icon(
              onPressed: busy ? null : _verify,
              icon: const Icon(Icons.verified_user_outlined),
              label: Text(busy ? 'Checking…' : 'Verify Answers'),
            ),
          ],
        );
      case _RecoveryStage.reset:
        return Column(
          key: const ValueKey('reset'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StepHeader(
              icon: Icons.password_outlined,
              title: 'Create a new password',
              message: _expiresAt == null
                  ? 'Enter the one-time code provided after manual owner review.'
                  : 'Your answers were verified. This one-time authorization expires at ${_timeLabel(_expiresAt!)}.',
            ),
            TextField(
              controller: _resetCodeController,
              enabled: !busy,
              obscureText: true,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'One-time reset code',
                helperText: _expiresAt == null
                    ? 'Enter the complete code exactly as provided.'
                    : 'Secure code received from HDC',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _passwordController,
              enabled: !busy,
              obscureText: _hidePassword,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'New password',
                helperText: '12 to 128 characters',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: busy
                      ? null
                      : () => setState(
                            () => _hidePassword = !_hidePassword,
                          ),
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _confirmPasswordController,
              enabled: !busy,
              obscureText: _hidePassword,
              decoration: const InputDecoration(
                labelText: 'Confirm new password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: busy ? null : _reset,
              icon: const Icon(Icons.lock_reset),
              label: Text(busy ? 'Updating…' : 'Set New Password'),
            ),
          ],
        );
      case _RecoveryStage.manualReview:
        return Column(
          key: const ValueKey('manual'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _StepHeader(
              icon: Icons.manage_search_outlined,
              title: 'Manual security review requested',
              message:
                  'HDC did not issue a reset code. A private request is now waiting for the Owner or an authorized security reviewer. Your answers and match count were not included.',
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: HDCColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'After your identity is confirmed, the reviewer can create a short-lived, one-use reset code. Contact HDC through the approved support channel to receive it.',
                style: TextStyle(height: 1.45),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              onPressed: busy ? null : _useManualCode,
              icon: const Icon(Icons.key_outlined),
              label: const Text('I Have an Approved Reset Code'),
            ),
            TextButton(
              onPressed: busy ? null : () => Navigator.of(context).pop(),
              child: const Text('Return to Sign In'),
            ),
          ],
        );
      case _RecoveryStage.complete:
        return Column(
          key: const ValueKey('complete'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _StepHeader(
              icon: Icons.check_circle_outline,
              title: 'Password updated',
              message:
                  'Your reset code has been consumed and all earlier HDC sessions were revoked. Sign in again with the new password.',
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Return to Sign In'),
            ),
          ],
        );
    }
  }
}

class _EmailStep extends StatelessWidget {
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onContinue;

  const _EmailStep({
    required this.controller,
    required this.busy,
    required this.onContinue,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHeader(
          icon: Icons.lock_reset,
          title: 'Forgot your password?',
          message:
              'Enter your registered email. HDC shows the same questions for every request so this step does not reveal whether an account exists.',
        ),
        TextField(
          controller: controller,
          enabled: !busy,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (_) {
            if (!busy) onContinue();
          },
          decoration: const InputDecoration(
            labelText: 'Registered email address',
            prefixIcon: Icon(Icons.email_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: busy ? null : onContinue,
          icon: const Icon(Icons.arrow_forward),
          label: Text(busy ? 'Loading…' : 'Continue'),
        ),
      ],
    );
  }
}

class _StepHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _StepHeader({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 42, color: HDCColors.primary),
        const SizedBox(height: 14),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: const TextStyle(
            color: HDCColors.textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

String _timeLabel(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
