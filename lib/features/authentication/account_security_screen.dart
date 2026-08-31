import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_exception.dart';
import '../../core/ui/hdc_colors.dart';
import '../../models/account_recovery.dart';
import '../../providers/hdc_auth_provider.dart';
import 'privacy_center_screen.dart';

class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  final _currentPasswordController = TextEditingController();
  final _answerControllers = List.generate(
    hdcRegistrationRecoveryQuestions.length,
    (_) => TextEditingController(),
  );
  bool _hidePassword = true;
  bool _hideAnswers = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    for (final controller in _answerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  List<AccountRecoveryAnswer> _answers() {
    return [
      for (
        var index = 0;
        index < hdcRegistrationRecoveryQuestions.length;
        index += 1
      )
        AccountRecoveryAnswer(
          questionCode: hdcRegistrationRecoveryQuestions[index].questionCode,
          answer: _answerControllers[index].text,
        ),
    ];
  }

  String? _localValidation() {
    if (_currentPasswordController.text.isEmpty) {
      return 'Enter your current HDC password.';
    }
    final normalized = <String>{};
    for (final controller in _answerControllers) {
      final answer = controller.text.trim().toLowerCase().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
      if (answer.length < 4 || answer.length > 160) {
        return 'Each recovery answer must contain 4 to 160 characters.';
      }
      normalized.add(answer);
    }
    if (normalized.length != _answerControllers.length) {
      return 'Use a different answer for each recovery question.';
    }
    return null;
  }

  Future<void> _save() async {
    final validation = _localValidation();
    if (validation != null) {
      _showMessage(validation);
      return;
    }

    try {
      await context.read<HDCAuthProvider>().updateRecoveryAnswers(
        currentPassword: _currentPasswordController.text,
        recoveryAnswers: _answers(),
      );
      if (!mounted) return;
      _currentPasswordController.clear();
      for (final controller in _answerControllers) {
        controller.clear();
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Recovery answers updated'),
          content: const Text(
            'Your three protected answers are now active. Any unused password '
            'reset codes and pending manual recovery request were revoked.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } on Object catch (error) {
      final message = error is HDCAuthException
          ? error.message
          : 'HDC could not update account security. Please try again.';
      _showMessage(message);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<HDCAuthProvider>();
    final busy = auth.isBusy;

    return Scaffold(
      appBar: AppBar(title: const Text('Account Security')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: HDCColors.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined, color: HDCColors.primary),
                        SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Set or replace the three private answers used by '
                            'Forgot Password. This is required for accounts '
                            'created before Build 12. HDC stores only protected '
                            'hashes; nobody can view the original answers.',
                            style: TextStyle(height: 1.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _currentPasswordController,
                    enabled: !busy,
                    obscureText: _hidePassword,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Current password',
                      helperText: 'Required to authorize this security change',
                      prefixIcon: const Icon(Icons.lock_outline),
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
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'New recovery answers',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: busy
                            ? null
                            : () =>
                                  setState(() => _hideAnswers = !_hideAnswers),
                        icon: Icon(
                          _hideAnswers
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        label: Text(
                          _hideAnswers ? 'Show answers' : 'Hide answers',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (
                    var index = 0;
                    index < hdcRegistrationRecoveryQuestions.length;
                    index += 1
                  ) ...[
                    TextField(
                      controller: _answerControllers[index],
                      enabled: !busy,
                      obscureText: _hideAnswers,
                      maxLength: 160,
                      decoration: InputDecoration(
                        labelText:
                            '${index + 1}. ${hdcRegistrationRecoveryQuestions[index].prompt}',
                        helperText:
                            'Use a unique answer of 4 to 160 characters',
                        alignLabelWithHint: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  FilledButton.icon(
                    onPressed: busy ? null : _save,
                    icon: const Icon(Icons.security_update_good_outlined),
                    label: Text(
                      busy ? 'Saving Securely…' : 'Save Recovery Answers',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'For your safety, answer updates are rate-limited and '
                    'recorded in the private security audit without plaintext answers.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: HDCColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Divider(),
                  const SizedBox(height: 18),
                  const Text(
                    'Privacy rights and requests',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Read the current Privacy Notice, submit a rights request, '
                    'and track its private review status with a permanent '
                    'reference number.',
                    style: TextStyle(height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PrivacyCenterScreen(),
                            ),
                          ),
                    icon: const Icon(Icons.privacy_tip_outlined),
                    label: const Text('Open Privacy Center'),
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
