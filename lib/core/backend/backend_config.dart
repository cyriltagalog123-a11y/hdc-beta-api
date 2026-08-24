import 'package:flutter/foundation.dart';

enum HDCBackendProvider {
  hdcApi,
  local,
}

class HDCBackendConfig {
  // Flutter talks only to the provider-neutral HDC HTTPS API. Legacy provider
  // names remain accepted as aliases so older launch scripts keep working,
  // but database vendors are never contacted directly by the client.
  static const String providerName = String.fromEnvironment(
    'HDC_BACKEND_PROVIDER',
    defaultValue: 'api',
  );

  // Public HDC API address only. Database URLs, signing secrets, service keys,
  // and other privileged credentials must never be placed in Flutter source or
  // dart-defines.
  static const String apiBaseUrl = String.fromEnvironment(
    'HDC_API_BASE_URL',
    defaultValue: 'https://hdc-beta-api.netlify.app',
  );

  static Uri? get apiBaseUri {
    final value = apiBaseUrl.trim();
    if (value == 'same-origin') {
      if (!kIsWeb) return null;
      final base = Uri.base;
      final isLoopback = base.host == 'localhost' ||
          base.host == '127.0.0.1' ||
          base.host == '::1';
      if (base.host.isEmpty ||
          (base.scheme != 'https' && !(base.scheme == 'http' && isLoopback))) {
        return null;
      }
      return Uri.parse(base.origin);
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty || uri.scheme != 'https') return null;
    return uri;
  }

  static bool get hasApiConfiguration => apiBaseUri != null;

  static HDCBackendProvider get provider {
    switch (providerName.trim().toLowerCase()) {
      case 'api':
      case 'hdc_api':
      case 'neon':
      case 'supabase':
        return HDCBackendProvider.hdcApi;
      case 'local':
      default:
        return HDCBackendProvider.local;
    }
  }
}
