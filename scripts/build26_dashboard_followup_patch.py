from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

def read(path):
    return (ROOT / path).read_text()

def write(path, content):
    (ROOT / path).write_text(content)

def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'missing patch target: {label}')
    return text.replace(old, new, 1)

# Community Center: Suggestions becomes a standalone destination.
path = 'lib/features/community/community_center_screen.dart'
text = read(path)
text = replace_once(text, 'TabController(length: 3, vsync: this)', 'TabController(length: 2, vsync: this)', 'community tab count')
text = replace_once(text, "title: const Text('Ratings, Suggestions & Badges'),", "title: const Text('Ratings & Badges'),", 'community title')
text = text.replace("            Tab(text: 'Suggestions', icon: Icon(Icons.lightbulb_outline_rounded)),\n", '')
text = text.replace("                  _SuggestionsTab(provider: provider),\n", '')
text, count = re.subn(r'class _SuggestionsTab extends StatelessWidget \{.*?(?=class _BadgesTab)', '', text, count=1, flags=re.S)
if count != 1:
    raise SystemExit('missing suggestions tab class')
write(path, text)

# Public dashboard: standalone Suggestions, cleaner community naming, attention panel.
path = 'lib/features/dashboard/dashboard_screen.dart'
text = read(path)
text = replace_once(text, "import '../community/community_center_screen.dart';\nimport '../internal/internal_dashboard_screen.dart';\nimport '../internal/suggestion_management_screen.dart';", "import '../community/community_center_screen.dart';\nimport '../community/suggestions_screen.dart';\nimport '../internal/internal_dashboard_screen.dart';", 'dashboard suggestion imports')
text = replace_once(text, "import 'widgets/dashboard_header.dart';", "import 'widgets/dashboard_header.dart';\nimport 'widgets/dashboard_focus_panel.dart';", 'dashboard focus import')
text = replace_once(text, "  void _openSuggestionQueue(BuildContext context) {\n    Navigator.of(context).push(\n      HDCPageRoute<void>(page: const SuggestionManagementScreen()),\n    );\n  }", "  void _openSuggestions(BuildContext context) {\n    Navigator.of(context).push(\n      HDCPageRoute<void>(page: const SuggestionsScreen()),\n    );\n  }", 'dashboard suggestion opener')
text = re.sub(r"\n    final canManageSuggestions =\n        auth\.authenticated &&\n        auth\.identity\?\.internalRoles\.any\(\n              \(role\) => role\.hasPrivilegedResourceAccess,\n            \) ==\n            true;", '', text, count=1)
text = replace_once(text, "          label: 'Ratings & Community',", "          label: 'Ratings & Badges',", 'ratings nav label')
old = "      if (canManageSuggestions)\n        HDCNavigationItem(\n          label: 'Suggestion Queue',\n          icon: Icons.fact_check_outlined,\n          onTap: () => _openSuggestionQueue(context),\n        ),"
new = "      HDCNavigationItem(\n        label: 'Suggestions',\n        icon: Icons.lightbulb_outline_rounded,\n        onTap: () => _openSuggestions(context),\n      ),"
text = replace_once(text, old, new, 'standalone suggestions nav')
needle = "                      const SizedBox(height: 24),\n                      DashboardPrimaryActions("
insert = "                      const SizedBox(height: 18),\n                      DashboardFocusPanel(\n                        unreadNotifications: notificationCenter.unreadCount,\n                        activeServices: activeTransactions,\n                        newOffers: totalOffers,\n                        hasPrivateWorkspace: hasPrivateWorkspace,\n                        onNotifications: () => _openNotifications(context),\n                        onSuggestions: () => _openSuggestions(context),\n                        onRatings: () => _openCommunityCenter(context),\n                        onPrivateOperations: hasPrivateWorkspace\n                            ? () => _openPrivateDashboard(context)\n                            : null,\n                      ),\n                      const SizedBox(height: 24),\n                      DashboardPrimaryActions("
text = replace_once(text, needle, insert, 'dashboard focus panel')
write(path, text)

# Notifications: opening a notification now opens a readable message view.
path = 'lib/features/notifications/notification_center_screen.dart'
text = read(path)
text = replace_once(text, "import '../../providers/hdc_notification_center_provider.dart';", "import '../../providers/hdc_notification_center_provider.dart';\nimport 'notification_detail_screen.dart';", 'notification detail import')
text = text.replace(",\n                        onRead: provider.markRead", '')
text = replace_once(text, "  final Future<void> Function(String id) onRead;\n\n  const _NotificationCard({required this.notification, required this.onRead});", "  const _NotificationCard({required this.notification});", 'notification card signature')
text = replace_once(text, "        onTap: notification.isUnread ? () => onRead(notification.id) : null,", "        onTap: () => Navigator.of(context).push(\n          MaterialPageRoute<void>(\n            builder: (_) => NotificationDetailScreen(notification: notification),\n          ),\n        ),", 'notification open behavior')
write(path, text)

# Suggestion review copy: owner-only, not general admin.
path = 'lib/features/internal/suggestion_management_screen.dart'
text = read(path)
text = replace_once(text, "eyebrow: 'OWNER / APPROVED ADMIN',", "eyebrow: 'OWNER ONLY',", 'owner suggestion eyebrow')
text = replace_once(text, "title: 'Review HDC suggestions without editing code.',", "title: 'Owner Suggestion Review',", 'owner suggestion title')
text = replace_once(text, "'Move suggestions through review, planning, decline, or implementation. Marking a suggestion implemented can earn its author the Helpful Contributor badge. Public credit still depends on the member’s separate consent.',", "'Only the HDC Owner can view the full suggestion queue. Move suggestions through review, planning, decline, or implementation. Marking a suggestion implemented can earn its author the Helpful Contributor badge. Public credit still depends on the member’s separate consent.',", 'owner suggestion description')
write(path, text)

# Backend: only the Owner can list/update the complete suggestion queue.
path = 'netlify/functions/community-admin.mts'
text = read(path)
text = replace_once(text, "const privilegedRoles = new Set(['owner', 'super_admin', 'admin']);", "const privilegedRoles = new Set(['owner']);", 'owner-only suggestion backend')
write(path, text)

# Private Operations: owner-only Suggestions plus a clearer operational command surface.
path = 'lib/features/internal/internal_dashboard_screen.dart'
text = read(path)
text = replace_once(text, "import '../../models/hdc_internal_dashboard.dart';\nimport '../../providers/hdc_internal_dashboard_provider.dart';", "import '../../models/account_identity.dart';\nimport '../../models/hdc_internal_dashboard.dart';\nimport '../../providers/hdc_auth_provider.dart';\nimport '../../providers/hdc_internal_dashboard_provider.dart';", 'private auth imports')
text = replace_once(text, "import 'platform_role_management_screen.dart';", "import 'platform_role_management_screen.dart';\nimport 'suggestion_management_screen.dart';", 'private suggestion import')
needle = "  Future<void> _openPlatformRoleManagement(BuildContext context) async {\n    if (!context.mounted) return;\n    Navigator.of(context).push(\n      MaterialPageRoute<void>(\n        builder: (_) => const PlatformRoleManagementScreen(),\n      ),\n    );\n  }"
replacement = needle + "\n\n  void _openSuggestionQueue(BuildContext context) {\n    Navigator.of(context).push(\n      MaterialPageRoute<void>(\n        builder: (_) => const SuggestionManagementScreen(),\n      ),\n    );\n  }"
text = replace_once(text, needle, replacement, 'private suggestion opener')
text = replace_once(text, "    final workspace = context.watch<HdcInternalDashboardProvider>();", "    final workspace = context.watch<HdcInternalDashboardProvider>();\n    final auth = context.watch<HDCAuthProvider>();\n    final isOwner =\n        auth.identity?.hasInternalRole(HDCInternalRole.owner) == true;", 'private owner check')
text = replace_once(text, "                          const SizedBox(height: 24),\n                          Text(\n                            'Authorized statistics',", "                          const SizedBox(height: 18),\n                          _OperationsPriorityStrip(\n                            pendingApplications: workspace.statistics['pendingRoleApplications'] ?? 0,\n                            pendingRecoveryReviews: workspace.statistics['pendingRecoveryReviews'] ?? 0,\n                            pendingDisputes: workspace.statistics['pendingDisputes'] ?? 0,\n                            isOwner: isOwner,\n                            loading: workspace.isLoading,\n                            onOpenApprovalQueue: () => _openApprovalQueue(context),\n                            onOpenRecoveryQueue: () => _openRecoveryQueue(context),\n                            onOpenDisputeQueue: () => _openDisputeQueue(context),\n                            onOpenSuggestions: () => _openSuggestionQueue(context),\n                          ),\n                          const SizedBox(height: 26),\n                          Text(\n                            'Operations snapshot',", 'private priority strip')
text = replace_once(text, "                            onOpenPlatformRoleManagement: () =>\n                                _openPlatformRoleManagement(context),", "                            onOpenPlatformRoleManagement: () =>\n                                _openPlatformRoleManagement(context),\n                            canManageSuggestions: isOwner,\n                            onOpenSuggestions: () =>\n                                _openSuggestionQueue(context),", 'private scope suggestion args')
text = replace_once(text, "  final VoidCallback onOpenPlatformRoleManagement;", "  final VoidCallback onOpenPlatformRoleManagement;\n  final bool canManageSuggestions;\n  final VoidCallback onOpenSuggestions;", 'private scope fields')
text = replace_once(text, "    required this.onOpenPlatformRoleManagement,\n  });", "    required this.onOpenPlatformRoleManagement,\n    required this.canManageSuggestions,\n    required this.onOpenSuggestions,\n  });", 'private scope constructor')
text = replace_once(text, "          'Authorized tools',", "          'Queues & controls',", 'private tools heading')
anchor = "        if (permissions.canModerateCommunity)\n          const _ScopeTile("
owner_tile = "        if (canManageSuggestions)\n          _ScopeTile(\n            icon: Icons.lightbulb_outline_rounded,\n            title: 'Suggestion Queue',\n            subtitle:\n                'Owner-only access to member suggestions, decisions, responses, and implementation tracking.',\n            action: FilledButton.tonalIcon(\n              onPressed: loading ? null : onOpenSuggestions,\n              icon: const Icon(Icons.lock_open_outlined),\n              label: const Text('Owner Review'),\n            ),\n          ),\n"
text = replace_once(text, anchor, owner_tile + anchor, 'owner suggestion scope tile')

priority_class = r'''
class _OperationsPriorityStrip extends StatelessWidget {
  final int pendingApplications;
  final int pendingRecoveryReviews;
  final int pendingDisputes;
  final bool isOwner;
  final bool loading;
  final VoidCallback onOpenApprovalQueue;
  final VoidCallback onOpenRecoveryQueue;
  final VoidCallback onOpenDisputeQueue;
  final VoidCallback onOpenSuggestions;

  const _OperationsPriorityStrip({
    required this.pendingApplications,
    required this.pendingRecoveryReviews,
    required this.pendingDisputes,
    required this.isOwner,
    required this.loading,
    required this.onOpenApprovalQueue,
    required this.onOpenRecoveryQueue,
    required this.onOpenDisputeQueue,
    required this.onOpenSuggestions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: HDCColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HDCColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.radar_rounded, color: HDCColors.primary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Operations priority board',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              if (isOwner)
                const Chip(
                  avatar: Icon(Icons.key_outlined, size: 17),
                  label: Text('OWNER'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Open the queues that need attention without searching through the full operations workspace.',
            style: TextStyle(color: HDCColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _PriorityAction(
                icon: Icons.fact_check_outlined,
                label: 'Role approvals',
                count: pendingApplications,
                onTap: loading ? null : onOpenApprovalQueue,
              ),
              _PriorityAction(
                icon: Icons.security_outlined,
                label: 'Recovery',
                count: pendingRecoveryReviews,
                onTap: loading ? null : onOpenRecoveryQueue,
              ),
              _PriorityAction(
                icon: Icons.gavel_outlined,
                label: 'Disputes',
                count: pendingDisputes,
                onTap: loading ? null : onOpenDisputeQueue,
              ),
              if (isOwner)
                _PriorityAction(
                  icon: Icons.lightbulb_outline_rounded,
                  label: 'Suggestions',
                  count: null,
                  onTap: loading ? null : onOpenSuggestions,
                  ownerOnly: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriorityAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? count;
  final VoidCallback? onTap;
  final bool ownerOnly;

  const _PriorityAction({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
    this.ownerOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final suffix = count == null ? '' : ' ($count)';
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text('${ownerOnly ? 'Owner • ' : ''}$label$suffix'),
    );
  }
}

'''
text = replace_once(text, 'class _StatisticsGrid extends StatelessWidget {', priority_class + 'class _StatisticsGrid extends StatelessWidget {', 'private priority class')
write(path, text)

# Regression coverage for this follow-up.
test = r'''import { describe, expect, it } from 'vitest';
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
'''
write('tests/build26-dashboard-suggestions-notifications.test.ts', test)
print('Build 26 dashboard/suggestions/notifications patch applied.')
