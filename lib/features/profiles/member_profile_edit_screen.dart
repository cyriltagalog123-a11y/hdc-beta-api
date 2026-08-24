import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui/hdc_colors.dart';
import '../../providers/hdc_auth_provider.dart';
import '../../providers/hdc_profile_provider.dart';

class MemberProfileEditScreen extends StatefulWidget {
  const MemberProfileEditScreen({super.key});

  @override
  State<MemberProfileEditScreen> createState() =>
      _MemberProfileEditScreenState();
}

class _MemberProfileEditScreenState
    extends State<MemberProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;
  late final TextEditingController _locationController;
  late final TextEditingController _avatarUrlController;
  late String _contactPreference;

  @override
  void initState() {
    super.initState();
    final profile = context.read<HdcProfileProvider>().memberProfile;
    _displayNameController = TextEditingController(
      text: profile?.displayName ?? '',
    );
    _bioController = TextEditingController(text: profile?.bio ?? '');
    _locationController = TextEditingController(text: profile?.location ?? '');
    _avatarUrlController = TextEditingController(
      text: profile?.avatarUrl ?? '',
    );
    _contactPreference = profile?.contactPreference ?? 'in_app';
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    final profiles = context.read<HdcProfileProvider>();
    try {
      final saved = await profiles.saveMember(
        displayName: _displayNameController.text,
        bio: _bioController.text,
        location: _locationController.text,
        avatarUrl: _avatarUrlController.text,
        contactPreference: _contactPreference,
      );
      if (!mounted) return;
      context
          .read<HDCAuthProvider>()
          .updateDisplayNameFromProfile(saved.displayName);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shared HDC profile saved.')),
      );
      Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profiles = context.watch<HdcProfileProvider>();
    final member = profiles.memberProfile;

    return Scaffold(
      appBar: AppBar(title: const Text('Shared Account Profile')),
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
                    const _SharedIdentityNotice(),
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Master identity',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              member?.email ?? '',
                              style: const TextStyle(
                                color: HDCColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _displayNameController,
                              maxLength: 80,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Account display name',
                                helperText: 'Used as the default for new role profiles.',
                              ),
                              validator: (value) {
                                final name = value?.trim() ?? '';
                                if (name.length < 2) {
                                  return 'Enter at least 2 characters.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _bioController,
                              minLines: 4,
                              maxLines: 7,
                              maxLength: 1200,
                              decoration: const InputDecoration(
                                labelText: 'About you',
                                alignLabelWithHint: true,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _locationController,
                              maxLength: 200,
                              decoration: const InputDecoration(
                                labelText: 'Home location or service base',
                                prefixIcon: Icon(Icons.location_on_outlined),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _avatarUrlController,
                              keyboardType: TextInputType.url,
                              maxLength: 500,
                              decoration: const InputDecoration(
                                labelText: 'Profile photo URL (optional)',
                                prefixIcon: Icon(Icons.image_outlined),
                              ),
                              validator: _optionalHttpUrlValidator,
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              initialValue: _contactPreference,
                              decoration: const InputDecoration(
                                labelText: 'Preferred private contact',
                                prefixIcon: Icon(Icons.contact_mail_outlined),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'in_app',
                                  child: Text('HDC in-app messages'),
                                ),
                                DropdownMenuItem(
                                  value: 'email',
                                  child: Text('Email'),
                                ),
                                DropdownMenuItem(
                                  value: 'phone',
                                  child: Text('Phone'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _contactPreference = value);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: profiles.isSaving || !profiles.backendAvailable
                          ? null
                          : _save,
                      icon: profiles.isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        profiles.isSaving ? 'Saving...' : 'Save Shared Profile',
                      ),
                    ),
                    if (!profiles.backendAvailable) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Connect the authenticated HDC API before saving.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: HDCColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SharedIdentityNotice extends StatelessWidget {
  const _SharedIdentityNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HDCColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HDCColors.info.withValues(alpha: 0.18)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: HDCColors.info),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'This is the only account identity used to sign in. Role public '
              'names are edited separately and never create another password '
              'or account.',
              style: TextStyle(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

String? _optionalHttpUrlValidator(String? value) {
  final input = value?.trim() ?? '';
  if (input.isEmpty) return null;
  final uri = Uri.tryParse(input);
  if (uri == null ||
      !uri.hasAuthority ||
      (uri.scheme != 'https' && uri.scheme != 'http')) {
    return 'Enter a complete http:// or https:// URL.';
  }
  return null;
}
