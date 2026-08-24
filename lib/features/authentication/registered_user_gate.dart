import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/hdc_auth_provider.dart';
import 'login_screen.dart';

Future<bool> requireRegisteredUser(
  BuildContext context, {
  required String action,
}) async {
  final auth = context.read<HDCAuthProvider>();
  if (auth.authenticated && !auth.guestMode && auth.identity != null) {
    return true;
  }

  final goToAccount = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Account required'),
      content: Text(
        'Guest mode is for exploring HelpDesk Connect only. '
        'Create an account or sign in to $action.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Keep Browsing'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Sign In / Register'),
        ),
      ],
    ),
  );

  if (goToAccount == true && context.mounted) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  return false;
}
