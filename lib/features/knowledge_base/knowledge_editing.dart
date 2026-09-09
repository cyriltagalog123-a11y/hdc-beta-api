const knowledgeCategories = <String, String>{
  'pc_laptop': 'PC & Laptop',
  'phones_mobile': 'Phones & Mobile',
  'pos_business_tech': 'POS & Business Tech',
  'network_internet': 'Network & Internet',
  'printers_peripherals': 'Printers & Peripherals',
  'security_accounts': 'Security & Accounts',
};

const knowledgeStatuses = <String, String>{
  'draft': 'Draft',
  'review': 'In review',
  'published': 'Published',
  'archived': 'Archived',
};

List<String> knowledgeStringList(Object? value) =>
    value is List ? value.map((item) => '$item').toList() : const [];

// Quick actions use the same version check and content contract as the editor.
// Read-only metadata must never be replayed as an editable field.
Map<String, Object?> knowledgeUpdatePayload(Map<String, dynamic> article) => {
  for (final field in const [
    'id',
    'title',
    'slug',
    'category',
    'summary',
    'body',
    'steps',
    'tags',
    'safetyLevel',
    'safetyNotice',
    'escalationText',
    'nexusReady',
    'isFeatured',
    'status',
  ])
    field: article[field],
  'expectedVersion': article['version'],
};
