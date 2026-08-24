import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/ui/hdc_colors.dart';
import '../../models/account_identity.dart';
import '../../models/platform_role_application.dart';
import '../../models/platform_role_application_form.dart';
import '../../providers/hdc_role_center_provider.dart';

class PlatformRoleApplicationFormScreen extends StatefulWidget {
  final HDCPlatformRole role;
  final PlatformRoleApplication? previousApplication;

  const PlatformRoleApplicationFormScreen({
    required this.role,
    this.previousApplication,
    super.key,
  });

  @override
  State<PlatformRoleApplicationFormScreen> createState() =>
      _PlatformRoleApplicationFormScreenState();
}

class _PlatformRoleApplicationFormScreenState
    extends State<PlatformRoleApplicationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  late final List<HDCPlatformRoleApplicationField> _fields;
  final _controllers = <String, TextEditingController>{};
  final _confirmations = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _fields = platformRoleApplicationFields(widget.role);
    final previous = widget.previousApplication;
    _noteController.text = previous?.applicantNote ?? '';
    for (final field in _fields) {
      final value = previous?.answers[field.key];
      if (field.type == HDCPlatformRoleApplicationFieldType.confirmation) {
        _confirmations[field.key] = value == true;
      } else {
        _controllers[field.key] = TextEditingController(
          text: value == null ? '' : '$value',
        );
      }
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    final missingConfirmation = _fields.any(
      (field) =>
          field.type == HDCPlatformRoleApplicationFieldType.confirmation &&
          field.isRequired &&
          _confirmations[field.key] != true,
    );
    if (missingConfirmation) {
      _showMessage('Complete every required confirmation before submitting.');
      return;
    }

    final answers = <String, Object?>{};
    for (final field in _fields) {
      if (field.type == HDCPlatformRoleApplicationFieldType.confirmation) {
        answers[field.key] = _confirmations[field.key] == true;
        continue;
      }
      final value = _controllers[field.key]!.text.trim();
      answers[field.key] =
          field.type == HDCPlatformRoleApplicationFieldType.integer
              ? int.parse(value)
              : value;
    }

    try {
      await context.read<HdcRoleCenterProvider>().applyForRole(
            widget.role,
            answers: answers,
            note: _noteController.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object catch (error) {
      _showMessage('$error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String? _validateField(
    HDCPlatformRoleApplicationField field,
    String? rawValue,
  ) {
    final value = rawValue?.trim() ?? '';
    if (value.isEmpty) {
      return field.isRequired ? '${field.label} is required.' : null;
    }
    if (field.type == HDCPlatformRoleApplicationFieldType.integer) {
      final number = int.tryParse(value);
      if (number == null) return 'Enter a whole number.';
      if (field.minimumInteger != null && number < field.minimumInteger!) {
        return 'Enter ${field.minimumInteger} or more.';
      }
      if (field.maximumInteger != null && number > field.maximumInteger!) {
        return 'Enter ${field.maximumInteger} or less.';
      }
      return null;
    }
    if (value.length < field.minimumLength) {
      return 'Enter at least ${field.minimumLength} characters.';
    }
    if (value.length > field.maximumLength) {
      return 'Use no more than ${field.maximumLength} characters.';
    }
    if (field.type == HDCPlatformRoleApplicationFieldType.url) {
      final uri = Uri.tryParse(value);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        return 'Enter a complete HTTPS URL.';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final center = context.watch<HdcRoleCenterProvider>();
    final changesRequested = widget.previousApplication?.needsChanges == true;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.role.label} Application'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ApplicationHeader(
                      role: widget.role,
                      updating: changesRequested,
                    ),
                    if (changesRequested &&
                        widget.previousApplication!.reviewNote.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _ChangesRequestedCard(
                        note: widget.previousApplication!.reviewNote,
                      ),
                    ],
                    const SizedBox(height: 22),
                    for (final field in _fields) ...[
                      _buildField(field, center.isSubmitting),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _noteController,
                      enabled: !center.isSubmitting,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        labelText: 'Additional note (optional)',
                        hintText:
                            'Add context that does not fit the required fields.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _PrivateReviewNotice(),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: center.isSubmitting ? null : _submit,
                      icon: const Icon(Icons.send_outlined),
                      label: Text(
                        center.isSubmitting
                            ? 'Submitting…'
                            : changesRequested
                                ? 'Resubmit Application'
                                : 'Submit for Private Review',
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    HDCPlatformRoleApplicationField field,
    bool busy,
  ) {
    if (field.type == HDCPlatformRoleApplicationFieldType.confirmation) {
      final accepted = _confirmations[field.key] == true;
      return Card(
        margin: EdgeInsets.zero,
        child: CheckboxListTile(
          value: accepted,
          enabled: !busy,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(field.label),
          subtitle: field.isRequired ? const Text('Required') : null,
          onChanged: (value) => setState(
            () => _confirmations[field.key] = value == true,
          ),
        ),
      );
    }

    final multiline =
        field.type == HDCPlatformRoleApplicationFieldType.multiline;
    final integer = field.type == HDCPlatformRoleApplicationFieldType.integer;
    return TextFormField(
      controller: _controllers[field.key],
      enabled: !busy,
      minLines: multiline ? 3 : 1,
      maxLines: multiline ? 6 : 1,
      maxLength: integer ? null : field.maximumLength,
      keyboardType: integer
          ? TextInputType.number
          : field.type == HDCPlatformRoleApplicationFieldType.url
              ? TextInputType.url
              : field.key == 'phone'
                  ? TextInputType.phone
                  : TextInputType.text,
      inputFormatters: integer
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      validator: (value) => _validateField(field, value),
      decoration: InputDecoration(
        labelText: field.label,
        helperText: field.helperText.isEmpty
            ? field.isRequired
                ? 'Required'
                : 'Optional'
            : field.helperText,
        alignLabelWithHint: multiline,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _ApplicationHeader extends StatelessWidget {
  final HDCPlatformRole role;
  final bool updating;

  const _ApplicationHeader({
    required this.role,
    required this.updating,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HDCColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HDCColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.assignment_outlined, color: HDCColors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  updating
                      ? 'Update your ${role.label} application'
                      : 'Apply for the ${role.label} workspace',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Complete every required field accurately. Approval adds '
                  'this public workspace to your existing HDC account; it '
                  'never creates another login or changes your account UUID.',
                  style: TextStyle(height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangesRequestedCard extends StatelessWidget {
  final String note;

  const _ChangesRequestedCard({required this.note});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: HDCColors.warning.withValues(alpha: 0.08),
      child: ListTile(
        leading: const Icon(Icons.edit_note, color: HDCColors.warning),
        title: const Text('Reviewer requested changes'),
        subtitle: Text(note),
      ),
    );
  }
}

class _PrivateReviewNotice extends StatelessWidget {
  const _PrivateReviewNotice();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.lock_outline, color: HDCColors.primary),
        title: Text('Private application data'),
        subtitle: Text(
          'These answers are available only to the Owner, Super Admin, or a '
          'reviewer explicitly granted access to this role. They are not '
          'shown on your public profile.',
        ),
      ),
    );
  }
}
