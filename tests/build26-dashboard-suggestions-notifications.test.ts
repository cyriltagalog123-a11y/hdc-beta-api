import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';

const read = (path: string) => readFileSync(path, 'utf8');

describe('Build 26 dashboard, suggestions, and notification follow-up', () => {
  it('keeps Suggestions standalone and visible from the public dashboard', () => {
    const dashboard = read('lib/features/dashboard/dashboard_screen.dart');
    const community = read('lib/features/community/community_center_screen.dart');
    const suggestions = read('lib/features/community/suggestions_screen.dart');

    expect(dashboard).toContain("label: 'Suggestions'");
    expect(dashboard).toContain('SuggestionsScreen');
    expect(dashboard).not.toContain("label: 'Suggestion Queue'");
    expect(dashboard).toContain("label: 'Ratings & Badges'");
    expect(community).toContain('TabController(length: 2');
    expect(community).not.toContain("Tab(text: 'Suggestions'");
    expect(suggestions).toContain('Suggestion page is visible in Guest mode');
    expect(suggestions).toContain('Only you and the Owner review workspace can see');
  });

  it('makes the complete suggestion queue owner-only in both backend and private UI', () => {
    const admin = read('netlify/functions/community-admin.mts');
    const privateOps = read('lib/features/internal/internal_dashboard_screen.dart');
    const manager = read('lib/features/internal/suggestion_management_screen.dart');

    expect(admin).toContain("const privilegedRoles = new Set(['owner']);");
    expect(admin).not.toContain("'super_admin', 'admin'");
    expect(privateOps).toContain('HDCInternalRole.owner');
    expect(privateOps).toContain("title: 'Suggestion Queue'");
    expect(privateOps).toContain('Owner-only access');
    expect(manager).toContain("eyebrow: 'OWNER ONLY'");
  });

  it('opens notifications into a readable detail surface instead of only toggling read state', () => {
    const center = read('lib/features/notifications/notification_center_screen.dart');
    const detail = read('lib/features/notifications/notification_detail_screen.dart');

    expect(center).toContain('NotificationDetailScreen(notification: notification)');
    expect(center).not.toContain('onTap: notification.isUnread');
    expect(detail).toContain('SelectableText');
    expect(detail).toContain('markRead(widget.notification.id)');
  });

  it('adds attention-first dashboard and private operations surfaces', () => {
    const dashboard = read('lib/features/dashboard/dashboard_screen.dart');
    const focus = read('lib/features/dashboard/widgets/dashboard_focus_panel.dart');
    const privateOps = read('lib/features/internal/internal_dashboard_screen.dart');

    expect(dashboard).toContain('DashboardFocusPanel(');
    expect(focus).toContain('may need attention');
    expect(privateOps).toContain('Operations priority board');
    expect(privateOps).toContain("'Queues & controls'");
  });
});
