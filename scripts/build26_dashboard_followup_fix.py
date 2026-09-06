from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def patch(path, old, new, label):
    file = ROOT / path
    text = file.read_text()
    if old not in text:
        raise SystemExit(f'missing fix target: {label}')
    file.write_text(text.replace(old, new, 1))

path = 'lib/features/internal/internal_dashboard_screen.dart'
patch(
    path,
    "                            isOwner: isOwner,\n                            loading: workspace.isLoading,",
    "                            isOwner: isOwner,\n                            canApprovePlatformRoles:\n                                workspace.permissions.canApprovePlatformRoles,\n                            canReviewAccountRecovery:\n                                workspace.permissions.canReviewAccountRecovery,\n                            loading: workspace.isLoading,",
    'priority permissions args',
)
patch(
    path,
    "  final bool isOwner;\n  final bool loading;",
    "  final bool isOwner;\n  final bool canApprovePlatformRoles;\n  final bool canReviewAccountRecovery;\n  final bool loading;",
    'priority permissions fields',
)
patch(
    path,
    "    required this.isOwner,\n    required this.loading,",
    "    required this.isOwner,\n    required this.canApprovePlatformRoles,\n    required this.canReviewAccountRecovery,\n    required this.loading,",
    'priority permissions constructor',
)
patch(
    path,
    "              _PriorityAction(\n                icon: Icons.fact_check_outlined,\n                label: 'Role approvals',\n                count: pendingApplications,\n                onTap: loading ? null : onOpenApprovalQueue,\n              ),",
    "              if (canApprovePlatformRoles)\n                _PriorityAction(\n                  icon: Icons.fact_check_outlined,\n                  label: 'Role approvals',\n                  count: pendingApplications,\n                  onTap: loading ? null : onOpenApprovalQueue,\n                ),",
    'role approval priority gate',
)
patch(
    path,
    "              _PriorityAction(\n                icon: Icons.security_outlined,\n                label: 'Recovery',\n                count: pendingRecoveryReviews,\n                onTap: loading ? null : onOpenRecoveryQueue,\n              ),",
    "              if (canReviewAccountRecovery)\n                _PriorityAction(\n                  icon: Icons.security_outlined,\n                  label: 'Recovery',\n                  count: pendingRecoveryReviews,\n                  onTap: loading ? null : onOpenRecoveryQueue,\n                ),",
    'recovery priority gate',
)
patch(
    path,
    "              _PriorityAction(\n                icon: Icons.gavel_outlined,\n                label: 'Disputes',\n                count: pendingDisputes,\n                onTap: loading ? null : onOpenDisputeQueue,\n              ),",
    "              if (canApprovePlatformRoles)\n                _PriorityAction(\n                  icon: Icons.gavel_outlined,\n                  label: 'Disputes',\n                  count: pendingDisputes,\n                  onTap: loading ? null : onOpenDisputeQueue,\n                ),",
    'dispute priority gate',
)

path = 'lib/features/notifications/notification_center_screen.dart'
patch(
    path,
    "                    Text(\n                      notification.message,\n                      style: const TextStyle(",
    "                    Text(\n                      notification.message,\n                      maxLines: 2,\n                      overflow: TextOverflow.ellipsis,\n                      style: const TextStyle(",
    'notification inbox preview',
)

print('Build 26 follow-up permission/UI tightening applied.')
