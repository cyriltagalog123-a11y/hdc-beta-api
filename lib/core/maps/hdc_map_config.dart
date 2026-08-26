class HdcMapConfig {
  static const String searchUrlTemplate = String.fromEnvironment(
    'HDC_MAP_SEARCH_URL_TEMPLATE',
    defaultValue: 'https://www.openstreetmap.org/search?query={query}',
  );

  static Uri serviceAreaUri(String serviceArea) {
    final query = serviceArea.trim();
    if (query.isEmpty) {
      throw ArgumentError.value(serviceArea, 'serviceArea', 'cannot be empty');
    }

    final encodedQuery = Uri.encodeQueryComponent(query);
    final rawUrl = searchUrlTemplate.contains('{query}')
        ? searchUrlTemplate.replaceAll('{query}', encodedQuery)
        : '$searchUrlTemplate$encodedQuery';
    final uri = Uri.parse(rawUrl);
    if (!uri.hasScheme || (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw StateError('HDC map search must use an HTTP or HTTPS URL.');
    }
    return uri;
  }
}
