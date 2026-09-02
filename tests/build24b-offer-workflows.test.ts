import { existsSync, readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

const read = (path: string) =>
  readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

const binary = (path: string) =>
  readFileSync(new URL(`../${path}`, import.meta.url));

const pngSize = (path: string) => {
  const image = binary(path);
  expect(image.subarray(0, 8).toString('hex')).toBe('89504e470d0a1a0a');
  return {
    width: image.readUInt32BE(16),
    height: image.readUInt32BE(20),
  };
};

const pngMetadata = (path: string) => {
  const image = binary(path);
  return {
    bytes: image.byteLength,
    bitDepth: image.readUInt8(24),
  };
};

describe('Build 24B offer workflow and official HDC branding', () => {
  it('packages the approved HDC mark locally across Flutter and web startup', () => {
    expect(existsSync(new URL('../assets/branding/hdc_mark.png', import.meta.url)))
      .toBe(true);
    expect(pngSize('assets/branding/hdc_mark.png')).toEqual({
      width: 512,
      height: 512,
    });
    expect(pngMetadata('assets/branding/hdc_mark.png')).toEqual({
      bytes: expect.any(Number),
      bitDepth: 8,
    });
    expect(pngMetadata('assets/branding/hdc_mark.png').bytes)
      .toBeLessThan(300_000);
    expect(binary('web/hdc_mark.png')).toEqual(
      binary('assets/branding/hdc_mark.png'),
    );

    const pubspec = read('pubspec.yaml');
    const brand = read('lib/core/ui/hdc_brand.dart');
    const startup = read('web/index.html');

    expect(pubspec).toContain('assets/branding/hdc_mark.png');
    expect(brand).toContain("Image.asset(");
    expect(brand).toContain("'assets/branding/hdc_mark.png'");
    expect(startup).toContain('class="hdc-startup-mark"');
    expect(startup).toContain('src="hdc_mark.png"');
    expect(startup).toContain('alt=""');
    expect(startup).toContain('aria-hidden="true"');

    const manifest = JSON.parse(read('web/manifest.json'));
    expect(manifest.background_color).toBe('#041426');
    expect(manifest.theme_color).toBe('#0A2342');
  });

  it('ships standard and maskable web icon sizes', () => {
    expect(pngSize('web/favicon.png')).toEqual({ width: 64, height: 64 });
    expect(pngSize('web/icons/Icon-192.png')).toEqual({
      width: 192,
      height: 192,
    });
    expect(pngSize('web/icons/Icon-512.png')).toEqual({
      width: 512,
      height: 512,
    });
    expect(pngSize('web/icons/Icon-maskable-192.png')).toEqual({
      width: 192,
      height: 192,
    });
    expect(pngSize('web/icons/Icon-maskable-512.png')).toEqual({
      width: 512,
      height: 512,
    });
    for (const icon of [
      'web/favicon.png',
      'web/icons/Icon-192.png',
      'web/icons/Icon-512.png',
      'web/icons/Icon-maskable-192.png',
      'web/icons/Icon-maskable-512.png',
    ]) {
      expect(pngMetadata(icon).bitDepth).toBe(8);
      expect(pngMetadata(icon).bytes).toBeLessThan(200_000);
    }
  });

  it('uses the responsive HDC flow language across technician offers', () => {
    const marketplace = read(
      'lib/features/technician_marketplace/technician_marketplace_screen.dart',
    );
    const details = read(
      'lib/features/technician_marketplace/technician_request_details_screen.dart',
    );
    const studio = read(
      'lib/features/technician_marketplace/proposal_studio_screen.dart',
    );

    expect(marketplace).toContain('HDCFlowHero(');
    expect(marketplace).toContain('HDCEmptyState(');
    expect(details).toContain('HDCFlowHero(');
    expect(details).toContain('Only one offer is allowed per technician.');
    expect(studio).toContain('HDCFlowProgress(');
    expect(studio).toContain('HDCResponsiveActions(');
  });

  it('keeps customer review and acceptance compact-screen safe', () => {
    const offers = read(
      'lib/features/customer_proposals/customer_offers_screen.dart',
    );
    const inbox = read(
      'lib/features/customer_proposals/customer_proposal_inbox_screen.dart',
    );
    const comparison = read(
      'lib/features/customer_proposals/customer_proposal_comparison_screen.dart',
    );
    const details = read(
      'lib/features/customer_proposals/customer_proposal_details_screen.dart',
    );

    expect(offers).toContain('HDCFlowHero(');
    expect(inbox).toContain('HDCFlowHero(');
    expect(inbox).toContain('HDCResponsiveActions(');
    expect(inbox).toContain('constraints.maxWidth < 560');
    expect(comparison).toContain('LayoutBuilder(');
    expect(comparison).not.toContain('scrollDirection: Axis.horizontal');
    expect(comparison).toContain('startProposalAcceptanceFlow(');
    expect(details).toContain('HDCFlowHero(');
    expect(details).toContain('HDCResponsiveActions(');
  });
});
