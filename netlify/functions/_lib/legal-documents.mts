export const CURRENT_LEGAL_VERSION = 'beta-2026-08-29';

export const CURRENT_LEGAL_DOCUMENTS = Object.freeze({
  terms_of_service: Object.freeze({
    documentType: 'terms_of_service',
    version: CURRENT_LEGAL_VERSION,
    title: 'HelpDesk Connect Beta Terms of Service',
    contentSha256:
      'b4af57360747f1c6c04a9f053c50564c5f49ef735e78f9bf0cfd9c77ffb73e57',
    publicPath: '/legal/terms/',
    effectiveAt: '2026-08-29T00:00:00.000Z',
  }),
  privacy_notice: Object.freeze({
    documentType: 'privacy_notice',
    version: CURRENT_LEGAL_VERSION,
    title: 'HelpDesk Connect Beta Privacy Notice',
    contentSha256:
      '3bc1887dca3c4dfc09e79aaad5cf14d717eba46f943dda1fbb2a01434bbfc4bf',
    publicPath: '/legal/privacy/',
    effectiveAt: '2026-08-29T00:00:00.000Z',
  }),
});

export type LegalDocumentType = keyof typeof CURRENT_LEGAL_DOCUMENTS;

export function currentLegalDocumentList() {
  return Object.values(CURRENT_LEGAL_DOCUMENTS).map((document) => ({
    ...document,
  }));
}
