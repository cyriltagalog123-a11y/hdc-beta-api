import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { describe, expect, it } from 'vitest';

const read = (path: string) =>
  readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

const supportPage = () => [
  read('lib/features/support/support_us_screen.dart'),
  read('lib/features/support/support_payment_channels.dart'),
].join('\n');

describe('SaiCore Support HDC and Contact Owner public pages', () => {
  it('keeps the owner contact channel explicit and copyable', () => {
    const page = read('lib/features/support/contact_owner_screen.dart');

    expect(page).toContain("static const ownerEmail = 'saicore.holdings@gmail.com'");
    expect(page).toContain('Copy Email Address');
    expect(page).toContain('Copy Email Template');
    expect(page).toContain('Clipboard.setData');
    expect(page).toContain('never send passwords');
  });

  it('keeps only the currently approved SaiCore PHP payment channels', () => {
    const page = supportPage();

    expect(page).toContain('SAICORE SUPPORT PROGRAM');
    expect(page).toContain('PHP only for now');
    expect(page).toContain('One-time support');
    expect(page).toContain('Recurring support');
    expect(page).toContain('Corporate sponsorship');
    expect(page).toContain("'GCash'");
    expect(page).toContain("'Maya (PayMaya)'");
    expect(page).not.toContain('PayPal');
    expect(page).not.toContain('Ko-fi or similar');
    expect(page).toContain('Bank transfer is not available at the moment.');
    expect(page).toContain('Automatic recurring payments are not enabled.');
  });

  it('publishes the unchanged owner-supplied QR cards with manual confirmation and fee disclosure', () => {
    const page = supportPage();
    const manifest = read('pubspec.yaml');
    const approvedAssets = [
      ['assets/payments/hdc-support-gcash.jpg', 'bdfa88b16aea280c9e131765c06c0beddcd46faef7b6dfcbb7a3d3c81d514d9a'],
      ['assets/payments/hdc-support-maya.jpg', '751dec0fde0bd3f8cd16722775e8a1bc6e00121577cb95eb292aa40fe82ce869'],
    ];

    for (const [path, sha256] of approvedAssets) {
      expect(page).toContain(path);
      expect(manifest).toContain(`- ${path}`);
      const bytes = readFileSync(new URL(`../${path}`, import.meta.url));
      expect(createHash('sha256').update(bytes).digest('hex')).toBe(sha256);
    }
    expect(page).toContain('Transfer fees may apply.');
    expect(page).toContain('HDC does not automatically confirm these transfers');
    expect(page).toContain('Public recognition requires your consent.');
    expect(page).toContain('personal ');
    expect(page).toContain('receiving account shown on the card.');
    expect(page).not.toContain('Destination setup required');
  });

  it('keeps useful non-financial support available', () => {
    const page = read('lib/features/support/support_us_screen.dart');

    expect(page).toContain('Test and report defects');
    expect(page).toContain('Challenge the workflow');
    expect(page).toContain('Share HDC responsibly');
    expect(page).toContain('Suggest practical improvements');
    expect(page).toContain('Suggest Knowledge Base topics');
    expect(page).toContain('Offer partnership or resources');
  });

  it('keeps support independent from trust, ranking, and private authority', () => {
    const page = read('lib/features/support/support_us_screen.dart');

    expect(page).toContain('Support must never buy trust');
    expect(page).toContain('No purchased ratings or review manipulation.');
    expect(page).toContain('No purchased verification or trust status.');
    expect(page).toContain('No moderation or dispute exceptions for supporters.');
    expect(page).toContain('No access to private user, transaction, chat, or internal data.');
    expect(page).toContain(
      'No special marketplace ranking or technician visibility purchased through support.',
    );
  });

  it('recognizes supporters publicly only by consent', () => {
    const page = read('lib/features/support/support_us_screen.dart');

    expect(page).toContain('Public supporter recognition');
    expect(page).toContain('agrees to be publicly named');
    expect(page).toContain('Anonymous or private support stays private.');
    expect(page).toContain('Recognition is publicity only.');
  });

  it('exposes Support HDC and Contact Owner from dashboard navigation', () => {
    const dashboard = read('lib/features/dashboard/dashboard_screen.dart');

    expect(dashboard).toContain("label: 'Support HDC'");
    expect(dashboard).toContain("label: 'Contact Owner'");
    expect(dashboard).toContain('SupportUsScreen');
    expect(dashboard).toContain('ContactOwnerScreen');
  });

  it('does not publish fabricated contribution destinations', () => {
    const page = supportPage();

    for (const unsupported of [
      'paypal.me/',
      'gcash.com/pay',
      'ko-fi.com/saicore',
      'patreon.com/',
      'Donate Now',
      'Send Money Now',
    ]) {
      expect(page).not.toContain(unsupported);
    }
  });
});
