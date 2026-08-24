import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui/hdc_colors.dart';
import '../../models/account_identity.dart';
import '../../models/hdc_profile.dart';
import '../../providers/hdc_profile_provider.dart';

class RoleProfileEditScreen extends StatefulWidget {
  final HDCPlatformRole role;

  const RoleProfileEditScreen({
    required this.role,
    super.key,
  });

  @override
  State<RoleProfileEditScreen> createState() =>
      _RoleProfileEditScreenState();
}

class _RoleProfileEditScreenState extends State<RoleProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  late bool _isPublic;
  late bool _emergencyService;
  late bool _pickupAvailable;
  late bool _deliveryAvailable;
  late String _preferredServiceMode;

  HDCPlatformRole get role => widget.role;

  @override
  void initState() {
    super.initState();
    final profiles = context.read<HdcProfileProvider>();
    final profile = profiles.profileFor(role);
    final details = profile?.details ?? const <String, dynamic>{};
    final defaultName = profiles.memberProfile?.displayName ?? role.label;

    _addController('publicName', profile?.publicName ?? defaultName);
    _addController('headline', profile?.headline ?? '');
    _addController('description', profile?.description ?? '');
    _addController('location', profile?.location ?? '');
    _addController('contactEmail', profile?.contactEmail ?? '');
    _addController('contactPhone', profile?.contactPhone ?? '');
    _addController('website', profile?.website ?? '');

    for (final key in _roleTextKeys(role)) {
      _addController(key, _detailText(details[key]));
    }
    for (final key in _roleListKeys(role)) {
      _addController(key, _detailList(details[key]).join(', '));
    }
    for (final key in _roleNumberKeys(role)) {
      _addController(key, _detailNumber(details[key]));
    }

    _isPublic = profile?.isPublic ?? false;
    _emergencyService = details['emergencyService'] == true;
    _pickupAvailable = details['pickupAvailable'] == true;
    _deliveryAvailable = details['deliveryAvailable'] == true;
    final mode = _detailText(details['preferredServiceMode']);
    _preferredServiceMode = ['onsite', 'remote', 'either'].contains(mode)
        ? mode
        : 'either';
  }

  void _addController(String key, String value) {
    _controllers[key] = TextEditingController(text: value);
  }

  TextEditingController _controller(String key) => _controllers[key]!;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    final profiles = context.read<HdcProfileProvider>();
    try {
      await profiles.saveRoleProfile(
        role,
        body: {
          'publicName': _controller('publicName').text.trim(),
          'headline': _controller('headline').text.trim(),
          'description': _controller('description').text.trim(),
          'location': _controller('location').text.trim(),
          'contactEmail': _controller('contactEmail').text.trim(),
          'contactPhone': _controller('contactPhone').text.trim(),
          'website': _controller('website').text.trim(),
          'isPublic': _isPublic,
          'details': _detailsPayload(),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${role.label} profile saved.')),
      );
      Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Map<String, Object?> _detailsPayload() {
    switch (role) {
      case HDCPlatformRole.customer:
        return {
          'preferredServiceMode': _preferredServiceMode,
          'supportInterests': _stringList('supportInterests'),
        };
      case HDCPlatformRole.technician:
        return {
          'skills': _stringList('skills'),
          'specialties': _stringList('specialties'),
          'yearsExperience': _integer('yearsExperience'),
          'serviceRadiusKm': _number('serviceRadiusKm'),
          'hourlyRate': _number('hourlyRate'),
          'availability': _text('availability'),
          'emergencyService': _emergencyService,
        };
      case HDCPlatformRole.business:
        return {
          'legalName': _text('legalName'),
          'businessType': _text('businessType'),
          'registrationNumber': _text('registrationNumber'),
          'branchCount': _integer('branchCount'),
          'employeeCount': _integer('employeeCount'),
          'services': _stringList('services'),
        };
      case HDCPlatformRole.seller:
        return {
          'storefrontName': _text('storefrontName'),
          'productCategories': _stringList('productCategories'),
          'fulfillmentMethods': _stringList('fulfillmentMethods'),
          'returnPolicy': _text('returnPolicy'),
        };
      case HDCPlatformRole.supplier:
        return {
          'companyName': _text('companyName'),
          'productCategories': _stringList('productCategories'),
          'deliveryRegions': _stringList('deliveryRegions'),
          'minimumOrderValue': _number('minimumOrderValue'),
          'leadTimeDays': _integer('leadTimeDays'),
          'wholesaleTerms': _text('wholesaleTerms'),
        };
      case HDCPlatformRole.store:
        return {
          'storeName': _text('storeName'),
          'storeCode': _text('storeCode'),
          'storeType': _text('storeType'),
          'openingHours': _text('openingHours'),
          'pickupAvailable': _pickupAvailable,
          'deliveryAvailable': _deliveryAvailable,
        };
    }
  }

  String _text(String key) => _controller(key).text.trim();

  List<String> _stringList(String key) => _controller(key)
      .text
      .split(RegExp(r'[,\n]'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .take(25)
      .toList(growable: false);

  int? _integer(String key) {
    final value = _text(key);
    return value.isEmpty ? null : int.tryParse(value);
  }

  double? _number(String key) {
    final value = _text(key);
    return value.isEmpty ? null : double.tryParse(value);
  }

  @override
  Widget build(BuildContext context) {
    final profiles = context.watch<HdcProfileProvider>();
    final existingProfile = profiles.profileFor(role);

    return Scaffold(
      appBar: AppBar(title: Text('${role.label} Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _WorkspaceHeader(
                      role: role,
                      profile: existingProfile,
                    ),
                    const SizedBox(height: 18),
                    _SectionCard(
                      title: 'Public identity',
                      subtitle: 'Only this ${role.label} profile uses these values.',
                      icon: Icons.badge_outlined,
                      children: [
                        _field(
                          'publicName',
                          label: '${role.label} public name',
                          maxLength: 120,
                          capitalization: TextCapitalization.words,
                          validator: (value) {
                            if ((value?.trim().length ?? 0) < 2) {
                              return 'Enter at least 2 characters.';
                            }
                            return null;
                          },
                        ),
                        _field(
                          'headline',
                          label: 'Headline',
                          hint: _headlineHint(role),
                          maxLength: 160,
                        ),
                        _field(
                          'description',
                          label: 'Profile description',
                          maxLength: 2000,
                          minLines: 4,
                          maxLines: 7,
                        ),
                        _field(
                          'location',
                          label: 'Profile location or service area',
                          maxLength: 200,
                          keyboardType: TextInputType.streetAddress,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: '${role.label} details',
                      subtitle: _detailsSubtitle(role),
                      icon: _roleIcon(role),
                      children: _roleSpecificFields(),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Public contact & visibility',
                      subtitle: 'These contacts belong only to this role profile.',
                      icon: Icons.public_outlined,
                      children: [
                        _field(
                          'contactEmail',
                          label: 'Public contact email (optional)',
                          maxLength: 254,
                          keyboardType: TextInputType.emailAddress,
                          validator: _optionalEmailValidator,
                        ),
                        _field(
                          'contactPhone',
                          label: 'Public contact phone (optional)',
                          maxLength: 30,
                          keyboardType: TextInputType.phone,
                          validator: _optionalPhoneValidator,
                        ),
                        _field(
                          'website',
                          label: 'Website (optional)',
                          maxLength: 500,
                          keyboardType: TextInputType.url,
                          validator: _optionalHttpUrlValidator,
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Publicly discoverable profile'),
                          subtitle: const Text(
                            'You control visibility separately for every role.',
                          ),
                          value: _isPublic,
                          onChanged: (value) => setState(() => _isPublic = value),
                        ),
                      ],
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
                        profiles.isSaving
                            ? 'Saving...'
                            : 'Save ${role.label} Profile',
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
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _roleSpecificFields() {
    switch (role) {
      case HDCPlatformRole.customer:
        return [
          DropdownButtonFormField<String>(
            initialValue: _preferredServiceMode,
            decoration: const InputDecoration(
              labelText: 'Preferred service mode',
            ),
            items: const [
              DropdownMenuItem(value: 'onsite', child: Text('On-site')),
              DropdownMenuItem(value: 'remote', child: Text('Remote')),
              DropdownMenuItem(value: 'either', child: Text('Either')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _preferredServiceMode = value);
              }
            },
          ),
          _field(
            'supportInterests',
            label: 'Support interests',
            hint: 'Computers, phones, networking',
            helper: 'Separate items with commas.',
            maxLength: 1000,
          ),
        ];
      case HDCPlatformRole.technician:
        return [
          _field(
            'skills',
            label: 'Skills',
            hint: 'Diagnostics, soldering, data recovery',
            helper: 'Separate items with commas.',
            maxLength: 1000,
          ),
          _field(
            'specialties',
            label: 'Specialties',
            hint: 'Mobile devices, laptops, networks',
            helper: 'Separate items with commas.',
            maxLength: 1000,
          ),
          _field(
            'yearsExperience',
            label: 'Years of experience',
            keyboardType: TextInputType.number,
            validator: _numberValidator(minimum: 0, maximum: 80, integer: true),
          ),
          _field(
            'serviceRadiusKm',
            label: 'Service radius (km)',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: _numberValidator(minimum: 0, maximum: 2000),
          ),
          _field(
            'hourlyRate',
            label: 'Indicative hourly rate',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: _numberValidator(minimum: 0, maximum: 10000000),
          ),
          _field(
            'availability',
            label: 'Availability',
            hint: 'Weekdays 9:00–18:00',
            maxLength: 160,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Emergency service available'),
            value: _emergencyService,
            onChanged: (value) => setState(() => _emergencyService = value),
          ),
        ];
      case HDCPlatformRole.business:
        return [
          _field('legalName', label: 'Legal business name', maxLength: 160),
          _field('businessType', label: 'Business type', maxLength: 100),
          _field(
            'registrationNumber',
            label: 'Registration number',
            maxLength: 100,
          ),
          _field(
            'branchCount',
            label: 'Number of branches',
            keyboardType: TextInputType.number,
            validator: _numberValidator(
              minimum: 0,
              maximum: 100000,
              integer: true,
            ),
          ),
          _field(
            'employeeCount',
            label: 'Number of employees',
            keyboardType: TextInputType.number,
            validator: _numberValidator(
              minimum: 0,
              maximum: 10000000,
              integer: true,
            ),
          ),
          _field(
            'services',
            label: 'Services offered or needed',
            helper: 'Separate items with commas.',
            maxLength: 1000,
          ),
        ];
      case HDCPlatformRole.seller:
        return [
          _field('storefrontName', label: 'Storefront name', maxLength: 160),
          _field(
            'productCategories',
            label: 'Product categories',
            helper: 'Separate items with commas.',
            maxLength: 1000,
          ),
          _field(
            'fulfillmentMethods',
            label: 'Fulfillment methods',
            hint: 'Delivery, pickup, shipping',
            helper: 'Separate items with commas.',
            maxLength: 1000,
          ),
          _field(
            'returnPolicy',
            label: 'Return policy',
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
          ),
        ];
      case HDCPlatformRole.supplier:
        return [
          _field('companyName', label: 'Supply company name', maxLength: 160),
          _field(
            'productCategories',
            label: 'Wholesale product categories',
            helper: 'Separate items with commas.',
            maxLength: 1000,
          ),
          _field(
            'deliveryRegions',
            label: 'Delivery regions',
            helper: 'Separate items with commas.',
            maxLength: 1000,
          ),
          _field(
            'minimumOrderValue',
            label: 'Minimum order value',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: _numberValidator(minimum: 0, maximum: 1000000000),
          ),
          _field(
            'leadTimeDays',
            label: 'Typical lead time (days)',
            keyboardType: TextInputType.number,
            validator: _numberValidator(
              minimum: 0,
              maximum: 3650,
              integer: true,
            ),
          ),
          _field(
            'wholesaleTerms',
            label: 'Wholesale terms',
            minLines: 3,
            maxLines: 6,
            maxLength: 1200,
          ),
        ];
      case HDCPlatformRole.store:
        return [
          _field('storeName', label: 'Store or branch name', maxLength: 160),
          _field('storeCode', label: 'Store code', maxLength: 60),
          _field('storeType', label: 'Store type', maxLength: 100),
          _field(
            'openingHours',
            label: 'Opening hours',
            hint: 'Mon–Sat, 9:00–18:00',
            maxLength: 240,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pickup available'),
            value: _pickupAvailable,
            onChanged: (value) => setState(() => _pickupAvailable = value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Local delivery available'),
            value: _deliveryAvailable,
            onChanged: (value) => setState(() => _deliveryAvailable = value),
          ),
        ];
    }
  }

  Widget _field(
    String key, {
    required String label,
    String? hint,
    String? helper,
    int? maxLength,
    int minLines = 1,
    int maxLines = 1,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.sentences,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: _controller(key),
        keyboardType: keyboardType,
        textCapitalization: capitalization,
        minLines: minLines,
        maxLines: maxLines,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
          alignLabelWithHint: maxLines > 1,
        ),
        validator: validator,
      ),
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  final HDCPlatformRole role;
  final HDCPlatformRoleProfile? profile;

  const _WorkspaceHeader({required this.role, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: HDCColors.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(_roleIcon(role), color: Colors.white, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${role.label} workspace profile',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Same HDC login · ${profile?.completionPercent ?? 17}% complete',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Chip(
            label: Text(profile?.isPublic == true ? 'Public' : 'Private'),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: HDCColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: const TextStyle(color: HDCColors.textSecondary),
            ),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }
}

String? Function(String?) _numberValidator({
  required num minimum,
  required num maximum,
  bool integer = false,
}) {
  return (value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return null;
    final parsed = integer ? int.tryParse(input) : num.tryParse(input);
    if (parsed == null || parsed < minimum || parsed > maximum) {
      return 'Enter a number from $minimum to $maximum.';
    }
    return null;
  };
}

String? _optionalEmailValidator(String? value) {
  final input = value?.trim() ?? '';
  if (input.isEmpty) return null;
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(input)) {
    return 'Enter a valid email address.';
  }
  return null;
}

String? _optionalPhoneValidator(String? value) {
  final input = value?.trim() ?? '';
  if (input.isEmpty) return null;
  if (!RegExp(r'^[0-9+() .-]{7,30}$').hasMatch(input)) {
    return 'Enter a valid phone number.';
  }
  return null;
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

String _detailText(Object? value) => value is String ? value : '';

List<String> _detailList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList(growable: false);
}

String _detailNumber(Object? value) => value is num ? '$value' : '';

List<String> _roleTextKeys(HDCPlatformRole role) {
  switch (role) {
    case HDCPlatformRole.customer:
      return const [];
    case HDCPlatformRole.technician:
      return const ['availability'];
    case HDCPlatformRole.business:
      return const ['legalName', 'businessType', 'registrationNumber'];
    case HDCPlatformRole.seller:
      return const ['storefrontName', 'returnPolicy'];
    case HDCPlatformRole.supplier:
      return const ['companyName', 'wholesaleTerms'];
    case HDCPlatformRole.store:
      return const ['storeName', 'storeCode', 'storeType', 'openingHours'];
  }
}

List<String> _roleListKeys(HDCPlatformRole role) {
  switch (role) {
    case HDCPlatformRole.customer:
      return const ['supportInterests'];
    case HDCPlatformRole.technician:
      return const ['skills', 'specialties'];
    case HDCPlatformRole.business:
      return const ['services'];
    case HDCPlatformRole.seller:
      return const ['productCategories', 'fulfillmentMethods'];
    case HDCPlatformRole.supplier:
      return const ['productCategories', 'deliveryRegions'];
    case HDCPlatformRole.store:
      return const [];
  }
}

List<String> _roleNumberKeys(HDCPlatformRole role) {
  switch (role) {
    case HDCPlatformRole.customer:
    case HDCPlatformRole.seller:
    case HDCPlatformRole.store:
      return const [];
    case HDCPlatformRole.technician:
      return const ['yearsExperience', 'serviceRadiusKm', 'hourlyRate'];
    case HDCPlatformRole.business:
      return const ['branchCount', 'employeeCount'];
    case HDCPlatformRole.supplier:
      return const ['minimumOrderValue', 'leadTimeDays'];
  }
}

String _headlineHint(HDCPlatformRole role) {
  switch (role) {
    case HDCPlatformRole.customer:
      return 'Technology user and HDC customer';
    case HDCPlatformRole.technician:
      return 'Certified mobile and computer technician';
    case HDCPlatformRole.business:
      return 'Technology support for growing teams';
    case HDCPlatformRole.seller:
      return 'Trusted technology products and accessories';
    case HDCPlatformRole.supplier:
      return 'Wholesale parts and equipment supplier';
    case HDCPlatformRole.store:
      return 'Local technology store and service branch';
  }
}

String _detailsSubtitle(HDCPlatformRole role) {
  switch (role) {
    case HDCPlatformRole.customer:
      return 'Personalize how you request and discover support.';
    case HDCPlatformRole.technician:
      return 'Describe your professional capabilities and availability.';
    case HDCPlatformRole.business:
      return 'Keep organization details separate from your personal identity.';
    case HDCPlatformRole.seller:
      return 'Configure the storefront operated by this seller profile.';
    case HDCPlatformRole.supplier:
      return 'Describe wholesale coverage, logistics, and terms.';
    case HDCPlatformRole.store:
      return 'Configure this store or branch operating profile.';
  }
}

IconData _roleIcon(HDCPlatformRole role) {
  switch (role) {
    case HDCPlatformRole.customer:
      return Icons.person_outline;
    case HDCPlatformRole.technician:
      return Icons.build_outlined;
    case HDCPlatformRole.business:
      return Icons.business_outlined;
    case HDCPlatformRole.seller:
      return Icons.sell_outlined;
    case HDCPlatformRole.supplier:
      return Icons.inventory_2_outlined;
    case HDCPlatformRole.store:
      return Icons.storefront_outlined;
  }
}
