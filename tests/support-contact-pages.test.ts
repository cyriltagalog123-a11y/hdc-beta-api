import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

const read = (path: string) =>
  readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

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
    const page = read('lib/features/support/support_us_screen.dart');

    expect(page).toContain('SAICORE SUPPORT PROGRAM');
    expect(page).toContain('PHP only for now');
    expect(page).toContain('One-time support');
    expect(page).toContain('Recurring support');
    expect(page).toContain('Corporate sponsorship');
    expect(page).toContain('GCash / QR');
    expect(page).toContain('Maya / QR Ph');
    expect(page).not.toContain('PayPal');
    expect(page).not.toContain('Ko-fi or similar');
    expect(page).toContain('Bank / transfer route');
    expect(page).toContain('Not available at the moment');
    expect(page).toContain('Corporate arrangement');
  });

  it('keeps verified payment destinations open and discloses provider fees', () => {
    const page = read('lib/features/support/support_us_screen.dart');

    expect(page).toContain('verified local QR or wallet routes');
    expect(page).toContain('transaction or withdrawal fees');
    expect(page).toContain('universally fee-free');
    expect(page).toContain(
      'Payment destinations remain open for owner-supplied verified QR or account details.',
    );
    expect(page).toContain('Bank transfer is not available at the moment.');
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
    const page = read('lib/features/support/support_us_screen.dart');

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
