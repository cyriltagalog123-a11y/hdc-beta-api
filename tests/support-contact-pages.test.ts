import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

const read = (path: string) =>
  readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

describe('Support HDC and Contact Owner public pages', () => {
  it('keeps the owner contact channel explicit and copyable', () => {
    const page = read('lib/features/support/contact_owner_screen.dart');

    expect(page).toContain("static const ownerEmail = 'saicore.holdings@gmail.com'");
    expect(page).toContain('Copy Email Address');
    expect(page).toContain('Copy Email Template');
    expect(page).toContain('Clipboard.setData');
    expect(page).toContain('never send passwords');
  });

  it('provides non-financial beta support paths before payment is configured', () => {
    const page = read('lib/features/support/support_us_screen.dart');

    expect(page).toContain('Test and report defects');
    expect(page).toContain('Challenge the workflow');
    expect(page).toContain('Share HDC responsibly');
    expect(page).toContain('Suggest practical improvements');
    expect(page).toContain('Suggest troubleshooting topics');
    expect(page).toContain('Offer partnership or resources');
    expect(page).toContain('Direct public contributions are not enabled yet.');
  });

  it('keeps support independent from trust and private authority', () => {
    const page = read('lib/features/support/support_us_screen.dart');

    expect(page).toContain('Support must never buy trust');
    expect(page).toContain('No purchased ratings or review manipulation.');
    expect(page).toContain('No purchased verification or trust status.');
    expect(page).toContain('No moderation or dispute exceptions for supporters.');
    expect(page).toContain('No access to private user, transaction, chat, or internal data.');
  });

  it('exposes both public pages from dashboard navigation', () => {
    const dashboard = read('lib/features/dashboard/dashboard_screen.dart');

    expect(dashboard).toContain("label: 'Support HDC'");
    expect(dashboard).toContain("label: 'Contact Owner'");
    expect(dashboard).toContain('SupportUsScreen');
    expect(dashboard).toContain('ContactOwnerScreen');
  });

  it('does not introduce fabricated payment providers or donation destinations', () => {
    const page = read('lib/features/support/support_us_screen.dart');

    for (const unsupported of [
      'paypal.me',
      'gcash.com',
      'buymeacoffee.com',
      'ko-fi.com',
      'patreon.com',
      'Donate Now',
      'Send Money',
    ]) {
      expect(page).not.toContain(unsupported);
    }
  });
});
