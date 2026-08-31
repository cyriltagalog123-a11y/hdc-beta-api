import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

const read = (path: string) =>
  readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

describe('Build 23 HDC interface foundation', () => {
  it('uses one shared signal-network design system', () => {
    const colors = read('lib/core/ui/hdc_colors.dart');
    const theme = read('lib/core/ui/hdc_theme.dart');
    const brand = read('lib/core/ui/hdc_brand.dart');

    expect(colors).toContain('signalGradient');
    expect(theme).toContain('useMaterial3: true');
    expect(theme).toContain('inputDecorationTheme');
    expect(brand).toContain('class HDCSignalBackdrop');
    expect(brand).toContain('class HDCBrandLockup');
  });

  it('keeps account entry, recovery, legal, and guest paths visible', () => {
    const login = read('lib/features/authentication/login_screen.dart');

    for (const marker of [
      "Key('hdc-email-field')",
      "Key('hdc-password-field')",
      "Key('hdc-auth-submit')",
      'Forgot Password?',
      'Read Terms',
      'Read Privacy',
      'Continue as Guest',
      'hdcRegistrationRecoveryQuestions',
    ]) {
      expect(login).toContain(marker);
    }
  });

  it('keeps core workflows reachable in desktop and mobile navigation', () => {
    const shell = read('lib/core/ui/hdc_app_shell.dart');
    const dashboard = read('lib/features/dashboard/dashboard_screen.dart');

    expect(shell).toContain('constraints.maxWidth >= 1120');
    expect(shell).toContain('openDrawer()');
    for (const label of [
      'Post a Service Request',
      'Active Services',
      'My Service Requests',
      'Offers',
      'Find a Technician',
      'Technician Jobs',
      'Shop Technology',
      'Notifications',
      'Profiles & Workspaces',
      'Role Center',
      'Private Operations',
    ]) {
      expect(dashboard).toContain(label);
    }
  });

  it('keeps startup recovery bounded and synchronized to the current build', () => {
    const index = read('web/index.html');
    const startup = read('web/hdc_startup.js');

    expect(index).toContain('Build 24');
    expect(index).toContain('Opening your secure workspace');
    expect(startup).toContain('Build 24 could not finish loading.');
    expect(startup).toContain("searchParams.set('hdc_refresh'");
    expect(startup).not.toContain('localStorage.clear');
  });
});
