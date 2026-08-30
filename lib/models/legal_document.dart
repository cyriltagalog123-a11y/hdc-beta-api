const String hdcCurrentLegalVersion = 'beta-2026-08-29';

enum HDCLegalDocument { terms, privacy }

extension HDCLegalDocumentDetails on HDCLegalDocument {
  String get title => switch (this) {
    HDCLegalDocument.terms => 'HelpDesk Connect Beta Terms of Service',
    HDCLegalDocument.privacy => 'HelpDesk Connect Beta Privacy Notice',
  };

  String get shortTitle => switch (this) {
    HDCLegalDocument.terms => 'Terms of Service',
    HDCLegalDocument.privacy => 'Privacy Notice',
  };

  String get assetPath => switch (this) {
    HDCLegalDocument.terms => 'legal/terms-of-service-beta-2026-08-29.txt',
    HDCLegalDocument.privacy => 'legal/privacy-notice-beta-2026-08-29.txt',
  };

  String get publicPath => switch (this) {
    HDCLegalDocument.terms => '/legal/terms/',
    HDCLegalDocument.privacy => '/legal/privacy/',
  };
}
