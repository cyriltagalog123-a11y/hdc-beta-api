import { existsSync, readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

const read = (path: string) =>
  readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

describe('Build 25 distinctive HDC interface redesign', () => {
  it('keeps the Build 25 redesign synchronized to the current release', () => {
    const packageJson = read('package.json');
    const packageLock = read('package-lock.json');
    const pubspec = read('pubspec.yaml');
    const appConfig = read('lib/core/config/app_config.dart');
    const dashboard = read('lib/features/dashboard/dashboard_screen.dart');
    const startup = read('web/index.html');
    const api = read('netlify/functions/api.mts');
    const ci = read('.github/workflows/ci.yml');
    const packageVersion = (JSON.parse(packageJson) as { version: string }).version;
    const release = /^(\d+\.\d+\.\d+)-build\.(\d+)$/.exec(packageVersion);
    if (!release) throw new Error('Unexpected HDC package version.');
    const [, semanticVersion, buildNumber] = release;

    expect(packageLock).toContain(`"version": "${packageVersion}"`);
    expect(pubspec).toContain(`version: ${semanticVersion}+${buildNumber}`);
    expect(appConfig).toContain(`${semanticVersion} Beta (Build ${buildNumber})`);
    expect(dashboard).toContain(
      `HelpDesk Connect Beta v${semanticVersion} Build ${buildNumber}`,
    );
    expect(startup).toContain(`Build ${buildNumber}`);
    expect(api).toContain(`build: '${semanticVersion}-build${buildNumber}'`);
    expect(ci).toContain('steps.release-artifact.outputs.name');
    expect(ci).not.toContain('git push origin');
  });

  it('keeps shared workflow surfaces semantic and responsive', () => {
    const flow = read('lib/core/ui/hdc_flow.dart');
    const shell = read('lib/core/ui/hdc_app_shell.dart');
    const actionCard = read('lib/core/ui/hdc_action_card.dart');
    const statusBadge = read('lib/core/ui/hdc_status_badge.dart');

    expect(flow).toContain('Semantics(');
    expect(flow).toContain('Workflow step $currentStep of ${steps.length}');
    expect(flow).toContain('constraints.maxWidth >= breakpoint');
    expect(shell).toContain('Semantics(');
    expect(shell).toContain('selected: item.selected');
    expect(actionCard).toContain('hint: subtitle');
    expect(statusBadge).toContain("label: '$semanticTone: $label'");
  });

  it('uses provider-backed dashboard and notification state instead of synthetic status', () => {
    const dashboardHeader = read(
      'lib/features/dashboard/widgets/dashboard_header.dart',
    );
    const serviceOverview = read(
      'lib/features/dashboard/widgets/dashboard_service_overview.dart',
    );
    const notifications = read(
      'lib/features/notifications/notification_center_screen.dart',
    );

    expect(dashboardHeader).not.toContain('RECORD SYNC');
    expect(serviceOverview).toContain(
      'Counts below come from your loaded HDC requests, offers, and service transactions.',
    );
    expect(notifications).toContain('provider.unreadCount');
    expect(notifications).toContain('provider.notifications[index - 1]');
  });

  it('preserves explicit commerce and private-workspace authority boundaries', () => {
    const marketplace = read(
      'lib/features/marketplace/marketplace_catalog_screen.dart',
    );
    const internal = read(
      'lib/features/internal/internal_dashboard_screen.dart',
    );
    const security = read(
      'lib/features/authentication/account_security_screen.dart',
    );

    expect(marketplace).toContain(
      'HDC does not claim to charge the buyer, verify delivery, or create a payment receipt',
    );
    expect(internal).toContain('server-enforced permissions');
    expect(security).toContain('Current password required');
    expect(security).toContain('Three protected answers');
  });

  it('does not leave temporary Build 25 repair machinery in the review branch', () => {
    const paths = [
      '../.github/workflows/build25-patch.yml',
      '../scripts/build25_patch.py',
      '../.github/workflows/build25-release-sync.yml',
      '../scripts/build25_release_sync.py',
    ];

    for (const path of paths) {
      expect(existsSync(new URL(path, import.meta.url))).toBe(false);
    }
  });
});
