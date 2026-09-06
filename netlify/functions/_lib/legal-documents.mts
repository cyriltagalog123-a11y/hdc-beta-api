export const CURRENT_LEGAL_VERSION = 'beta-2026-09-06';

export const CURRENT_LEGAL_DOCUMENTS = Object.freeze({
  terms_of_service: Object.freeze({
    documentType: 'terms_of_service',
    version: CURRENT_LEGAL_VERSION,
    title: 'HelpDesk Connect Beta Terms of Service',
    contentSha256: 'ab71dc81ee05dc8fa865b5261920ea2ebbae05e2b656cfd3d8527ea9062c3720',
    publicPath: '/legal/terms/',
    effectiveAt: '2026-09-06T00:00:00.000Z',
  }),
  privacy_notice: Object.freeze({
    documentType: 'privacy_notice',
    version: CURRENT_LEGAL_VERSION,
    title: 'HelpDesk Connect Beta Privacy Notice',
    contentSha256: '3a349d3b83c1a6f95d5c86533f9b3d41b54d33335b68731cdc8fad34ea42bc93',
    publicPath: '/legal/privacy/',
    effectiveAt: '2026-09-06T00:00:00.000Z',
  }),
});

export type LegalDocumentType = keyof typeof CURRENT_LEGAL_DOCUMENTS;

export function currentLegalDocumentList() {
  return Object.values(CURRENT_LEGAL_DOCUMENTS).map((document) => ({
    ...document,
  }));
}
