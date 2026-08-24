import 'account_identity.dart';

const int hdcPlatformRoleApplicationFormVersion = 2;

enum HDCPlatformRoleApplicationFieldType {
  text,
  multiline,
  integer,
  url,
  confirmation,
}

class HDCPlatformRoleApplicationField {
  final String key;
  final String label;
  final String helperText;
  final HDCPlatformRoleApplicationFieldType type;
  final bool isRequired;
  final int minimumLength;
  final int maximumLength;
  final int? minimumInteger;
  final int? maximumInteger;

  const HDCPlatformRoleApplicationField({
    required this.key,
    required this.label,
    required this.type,
    this.helperText = '',
    this.isRequired = true,
    this.minimumLength = 1,
    this.maximumLength = 500,
    this.minimumInteger,
    this.maximumInteger,
  });
}

const _commonFields = <HDCPlatformRoleApplicationField>[
  HDCPlatformRoleApplicationField(
    key: 'phone',
    label: 'Contact phone number',
    type: HDCPlatformRoleApplicationFieldType.text,
    minimumLength: 7,
    maximumLength: 30,
  ),
  HDCPlatformRoleApplicationField(
    key: 'country',
    label: 'Country',
    type: HDCPlatformRoleApplicationFieldType.text,
    minimumLength: 2,
    maximumLength: 80,
  ),
  HDCPlatformRoleApplicationField(
    key: 'city',
    label: 'City or service base',
    type: HDCPlatformRoleApplicationFieldType.text,
    minimumLength: 2,
    maximumLength: 100,
  ),
  HDCPlatformRoleApplicationField(
    key: 'reason',
    label: 'Why are you applying for this role?',
    helperText: 'Describe how you plan to use this HDC workspace.',
    type: HDCPlatformRoleApplicationFieldType.multiline,
    minimumLength: 40,
    maximumLength: 1000,
  ),
  HDCPlatformRoleApplicationField(
    key: 'evidenceUrl',
    label: 'Supporting evidence URL (optional)',
    helperText: 'Use an HTTPS link only.',
    type: HDCPlatformRoleApplicationFieldType.url,
    isRequired: false,
    maximumLength: 500,
  ),
  HDCPlatformRoleApplicationField(
    key: 'agreedToPlatformStandards',
    label: 'I agree to follow HDC platform standards and role policies.',
    type: HDCPlatformRoleApplicationFieldType.confirmation,
  ),
];

List<HDCPlatformRoleApplicationField> platformRoleApplicationFields(
  HDCPlatformRole role,
) {
  final specific = switch (role) {
    HDCPlatformRole.technician => const [
        HDCPlatformRoleApplicationField(
          key: 'primarySpecialty',
          label: 'Primary technical specialty',
          type: HDCPlatformRoleApplicationFieldType.text,
          minimumLength: 2,
          maximumLength: 120,
        ),
        HDCPlatformRoleApplicationField(
          key: 'yearsExperience',
          label: 'Years of relevant experience',
          type: HDCPlatformRoleApplicationFieldType.integer,
          minimumInteger: 0,
          maximumInteger: 60,
        ),
        HDCPlatformRoleApplicationField(
          key: 'serviceArea',
          label: 'Service area',
          type: HDCPlatformRoleApplicationFieldType.multiline,
          minimumLength: 2,
          maximumLength: 300,
        ),
        HDCPlatformRoleApplicationField(
          key: 'certifications',
          label: 'Certifications or training (optional)',
          type: HDCPlatformRoleApplicationFieldType.multiline,
          isRequired: false,
          maximumLength: 1000,
        ),
        HDCPlatformRoleApplicationField(
          key: 'portfolioUrl',
          label: 'Portfolio or professional URL (optional)',
          type: HDCPlatformRoleApplicationFieldType.url,
          isRequired: false,
          maximumLength: 500,
        ),
        HDCPlatformRoleApplicationField(
          key: 'validIdentificationConfirmed',
          label: 'I can provide valid identification during verification.',
          type: HDCPlatformRoleApplicationFieldType.confirmation,
        ),
        HDCPlatformRoleApplicationField(
          key: 'backgroundCheckConsent',
          label: 'I consent to an HDC background or credential review.',
          type: HDCPlatformRoleApplicationFieldType.confirmation,
        ),
      ],
    HDCPlatformRole.business => const [
        HDCPlatformRoleApplicationField(
          key: 'businessName',
          label: 'Registered business name',
          type: HDCPlatformRoleApplicationFieldType.text,
          minimumLength: 2,
          maximumLength: 160,
        ),
        HDCPlatformRoleApplicationField(
          key: 'registrationReference',
          label: 'Registration or permit reference',
          type: HDCPlatformRoleApplicationFieldType.text,
          minimumLength: 2,
          maximumLength: 160,
        ),
        HDCPlatformRoleApplicationField(
          key: 'businessType',
          label: 'Business type',
          type: HDCPlatformRoleApplicationFieldType.text,
          minimumLength: 2,
          maximumLength: 100,
        ),
        HDCPlatformRoleApplicationField(
          key: 'businessAddress',
          label: 'Business address',
          type: HDCPlatformRoleApplicationFieldType.multiline,
          minimumLength: 5,
          maximumLength: 300,
        ),
        HDCPlatformRoleApplicationField(
          key: 'contactRole',
          label: 'Your role in the business',
          type: HDCPlatformRoleApplicationFieldType.text,
          minimumLength: 2,
          maximumLength: 100,
        ),
        HDCPlatformRoleApplicationField(
          key: 'website',
          label: 'Business website (optional)',
          type: HDCPlatformRoleApplicationFieldType.url,
          isRequired: false,
          maximumLength: 500,
        ),
        HDCPlatformRoleApplicationField(
          key: 'authorizedRepresentative',
          label: 'I am authorized to represent this business.',
          type: HDCPlatformRoleApplicationFieldType.confirmation,
        ),
      ],
    HDCPlatformRole.seller => const [
        HDCPlatformRoleApplicationField(
          key: 'shopName',
          label: 'Shop or seller name',
          type: HDCPlatformRoleApplicationFieldType.text,
          minimumLength: 2,
          maximumLength: 160,
        ),
        HDCPlatformRoleApplicationField(
          key: 'productCategories',
          label: 'Product categories',
          type: HDCPlatformRoleApplicationFieldType.multiline,
          minimumLength: 2,
          maximumLength: 500,
        ),
        HDCPlatformRoleApplicationField(
          key: 'fulfillmentMethod',
          label: 'Order fulfillment method',
          type: HDCPlatformRoleApplicationFieldType.multiline,
          minimumLength: 2,
          maximumLength: 200,
        ),
        HDCPlatformRoleApplicationField(
          key: 'returnPolicy',
          label: 'Return and refund policy',
          type: HDCPlatformRoleApplicationFieldType.multiline,
          minimumLength: 20,
          maximumLength: 1000,
        ),
        HDCPlatformRoleApplicationField(
          key: 'registrationReference',
          label: 'Registration or permit reference',
          type: HDCPlatformRoleApplicationFieldType.text,
          minimumLength: 2,
          maximumLength: 160,
        ),
        HDCPlatformRoleApplicationField(
          key: 'website',
          label: 'Shop website (optional)',
          type: HDCPlatformRoleApplicationFieldType.url,
          isRequired: false,
          maximumLength: 500,
        ),
        HDCPlatformRoleApplicationField(
          key: 'authenticProductsConfirmed',
          label: 'I confirm that listed products will be authentic and lawful.',
          type: HDCPlatformRoleApplicationFieldType.confirmation,
        ),
      ],
    HDCPlatformRole.supplier => const [
        HDCPlatformRoleApplicationField(
          key: 'companyName',
          label: 'Registered company name',
          type: HDCPlatformRoleApplicationFieldType.text,
          minimumLength: 2,
          maximumLength: 160,
        ),
        HDCPlatformRoleApplicationField(
          key: 'registrationReference',
          label: 'Registration or permit reference',
          type: HDCPlatformRoleApplicationFieldType.text,
          minimumLength: 2,
          maximumLength: 160,
        ),
        HDCPlatformRoleApplicationField(
          key: 'supplyCategories',
          label: 'Supply categories',
          type: HDCPlatformRoleApplicationFieldType.multiline,
          minimumLength: 2,
          maximumLength: 500,
        ),
        HDCPlatformRoleApplicationField(
          key: 'serviceRegions',
          label: 'Regions served',
          type: HDCPlatformRoleApplicationFieldType.multiline,
          minimumLength: 2,
          maximumLength: 500,
        ),
        HDCPlatformRoleApplicationField(
          key: 'minimumOrderDetails',
          label: 'Minimum order details',
          type: HDCPlatformRoleApplicationFieldType.multiline,
          minimumLength: 2,
          maximumLength: 500,
        ),
        HDCPlatformRoleApplicationField(
          key: 'website',
          label: 'Company website (optional)',
          type: HDCPlatformRoleApplicationFieldType.url,
          isRequired: false,
          maximumLength: 500,
        ),
        HDCPlatformRoleApplicationField(
          key: 'authorizedRepresentative',
          label: 'I am authorized to represent this supplier.',
          type: HDCPlatformRoleApplicationFieldType.confirmation,
        ),
      ],
    HDCPlatformRole.store => const [
        HDCPlatformRoleApplicationField(
          key: 'organizationName',
          label: 'Organization name',
          type: HDCPlatformRoleApplicationFieldType.text,
          minimumLength: 2,
          maximumLength: 160,
        ),
        HDCPlatformRoleApplicationField(
          key: 'branchName',
          label: 'Store or branch name',
          type: HDCPlatformRoleApplicationFieldType.text,
          minimumLength: 2,
          maximumLength: 160,
        ),
        HDCPlatformRoleApplicationField(
          key: 'storeAddress',
          label: 'Store address',
          type: HDCPlatformRoleApplicationFieldType.multiline,
          minimumLength: 5,
          maximumLength: 300,
        ),
        HDCPlatformRoleApplicationField(
          key: 'storeType',
          label: 'Store type',
          type: HDCPlatformRoleApplicationFieldType.text,
          minimumLength: 2,
          maximumLength: 100,
        ),
        HDCPlatformRoleApplicationField(
          key: 'registrationReference',
          label: 'Registration or permit reference',
          type: HDCPlatformRoleApplicationFieldType.text,
          minimumLength: 2,
          maximumLength: 160,
        ),
        HDCPlatformRoleApplicationField(
          key: 'website',
          label: 'Store website (optional)',
          type: HDCPlatformRoleApplicationFieldType.url,
          isRequired: false,
          maximumLength: 500,
        ),
        HDCPlatformRoleApplicationField(
          key: 'authorizedRepresentative',
          label: 'I am authorized to represent this store or branch.',
          type: HDCPlatformRoleApplicationFieldType.confirmation,
        ),
      ],
    HDCPlatformRole.customer =>
      const <HDCPlatformRoleApplicationField>[],
  };
  return List<HDCPlatformRoleApplicationField>.unmodifiable([
    ...specific,
    if (role != HDCPlatformRole.customer) ..._commonFields,
  ]);
}

String platformRoleApplicationAnswerLabel(
  HDCPlatformRole role,
  String key,
) {
  for (final field in platformRoleApplicationFields(role)) {
    if (field.key == key) return field.label;
  }
  return key
      .replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}',
      )
      .replaceAll('_', ' ');
}
