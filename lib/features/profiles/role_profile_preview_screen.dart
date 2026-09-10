import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/account_identity.dart';
import '../../providers/hdc_profile_provider.dart';

class RoleProfilePreviewScreen extends StatelessWidget {
  final HDCPlatformRole role;
  final String userId;
  const RoleProfilePreviewScreen({required this.role, required this.userId, super.key});

  @override
  Widget build(BuildContext context) {
    final profiles = context.watch<HdcProfileProvider>();
    final profile = profiles.profileFor(role);
    final allowed = profiles.memberProfile?.userId == userId &&
        profiles.activeRoles.contains(role) && profile?.userId == userId;
    return Scaffold(
      appBar: AppBar(title: Text('${role.label} profile preview')),
      body: !allowed || profile == null
          ? const Center(child: Text('This profile is no longer available to this account.'))
          : Align(alignment: Alignment.topCenter, child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView(padding: const EdgeInsets.all(24), children: [
                Text(profile.publicName, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(profile.isPublic ? 'Public role profile · Preview' : 'Private role profile · Only you can preview it here'),
                const SizedBox(height: 12),
                if (profile.headline.isNotEmpty) Text(profile.headline, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 20),
                for (final entry in <String, Object?>{
                  'About': profile.description,
                  'Location': profile.location,
                  'Public contact email': profile.contactEmail,
                  'Public contact phone': profile.contactPhone,
                  'Website': profile.website,
                  ...profile.details,
                }.entries)
                  if (_value(entry.value).isNotEmpty) Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_label(entry.key), style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 4),
                      SelectableText(_value(entry.value)),
                    ]),
                  ),
                const Divider(),
                const Text('This preview includes only your role profile. Your sign-in email, member account settings and recovery information are not included.'),
              ]),
            )),
    );
  }
}

String _label(String text) {
  final words = text.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}').replaceAll('_', ' ');
  return words.isEmpty ? '' : '${words[0].toUpperCase()}${words.substring(1)}';
}

String _value(Object? value) {
  if (value == null) {
    return '';
  }
  if (value is bool) {
    return value ? 'Yes' : 'No';
  }
  if (value is Iterable) {
    return value.map(_value).where((v) => v.isNotEmpty).join(', ');
  }
  if (value is Map) {
    return value.entries.map((e) => '${_label('${e.key}')}: ${_value(e.value)}').join('\n');
  }
  return '$value';
}
