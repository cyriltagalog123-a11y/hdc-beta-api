from pathlib import Path

STAGE = 'Build 25F: integrate profiles commerce security and internal tools'


def replace_once(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    text = file_path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one match, found {count}: {old[:100]!r}')
    file_path.write_text(text.replace(old, new, 1))


profile = 'lib/features/profiles/profile_center_screen.dart'
replace_once(
    profile,
    "import '../../core/ui/hdc_colors.dart';\n",
    "import '../../core/ui/hdc_colors.dart';\nimport '../../core/ui/hdc_flow.dart';\n",
)
replace_once(
    profile,
    "            const _OneAccountBanner(),\n",
    """            const HDCFlowHero(
              eyebrow: 'IDENTITY & WORKSPACES',
              title: 'One account. Multiple authorized profiles.',
              description:
                  'Your member identity stays shared while each active HDC role keeps its own public profile and workspace settings.',
              icon: Icons.hub_outlined,
              tags: [
                HDCFlowTag(label: 'Shared identity', icon: Icons.person_outline_rounded),
                HDCFlowTag(label: 'Role-aware', icon: Icons.badge_outlined),
                HDCFlowTag(label: 'Server-backed', icon: Icons.verified_user_outlined),
              ],
            ),
""",
)

security = 'lib/features/authentication/account_security_screen.dart'
replace_once(
    security,
    "import '../../core/ui/hdc_colors.dart';\n",
    "import '../../core/ui/hdc_colors.dart';\nimport '../../core/ui/hdc_flow.dart';\n",
)
old_security = """                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: HDCColors.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined, color: HDCColors.primary),
                        SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Set or replace the three private answers used by '
                            'Forgot Password. This is required for accounts '
                            'created before Build 12. HDC stores only protected '
                            'hashes; nobody can view the original answers.',
                            style: TextStyle(height: 1.45),
                          ),
                        ),
                      ],
                    ),
                  ),
"""
new_security = """                  const HDCFlowHero(
                    eyebrow: 'ACCOUNT SECURITY',
                    title: 'Protected recovery belongs to the account owner.',
                    description:
                        'Set or replace the three private answers used by Forgot Password. HDC stores protected hashes rather than readable answers.',
                    icon: Icons.shield_outlined,
                    tags: [
                      HDCFlowTag(label: 'Current password required', icon: Icons.lock_outline),
                      HDCFlowTag(label: 'Three protected answers', icon: Icons.password_outlined),
                    ],
                  ),
"""
replace_once(security, old_security, new_security)

market = 'lib/features/marketplace/marketplace_catalog_screen.dart'
replace_once(
    market,
    "import '../../core/ui/hdc_colors.dart';\n",
    "import '../../core/ui/hdc_colors.dart';\nimport '../../core/ui/hdc_flow.dart';\n",
)
replace_once(
    market,
    "          const _CatalogNotice(),\n",
    """          const HDCFlowHero(
            eyebrow: 'TECHNOLOGY MARKETPLACE',
            title: 'Browse listings. Send a tracked purchase request.',
            description:
                'HDC records the request and seller response. HDC does not claim to charge the buyer, verify delivery, or create a payment receipt from this action.',
            icon: Icons.storefront_outlined,
            tags: [
              HDCFlowTag(label: 'Seller listings', icon: Icons.inventory_2_outlined),
              HDCFlowTag(label: 'Tracked request', icon: Icons.receipt_long_outlined),
            ],
          ),
""",
)

notifications = 'lib/features/notifications/notification_center_screen.dart'
replace_once(
    notifications,
    "import '../../core/ui/hdc_colors.dart';\n",
    "import '../../core/ui/hdc_colors.dart';\nimport '../../core/ui/hdc_flow.dart';\n",
)
replace_once(
    notifications,
    "                    padding: const EdgeInsets.all(20),\n                    itemCount: provider.notifications.length,\n                    separatorBuilder: (_, _) => const SizedBox(height: 10),\n                    itemBuilder: (context, index) => _NotificationCard(\n                      notification: provider.notifications[index],\n                      onRead: provider.markRead,\n                    ),\n",
    """                    padding: const EdgeInsets.all(20),
                    itemCount: provider.notifications.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return HDCFlowHero(
                          eyebrow: 'NOTIFICATION CENTER',
                          title: provider.unreadCount == 0
                              ? 'You are caught up.'
                              : '${provider.unreadCount} unread update${provider.unreadCount == 1 ? '' : 's'} need review.',
                          description:
                              'Only notifications returned for this signed-in account appear here. Priority and read state remain provider-backed.',
                          icon: Icons.notifications_active_outlined,
                        );
                      }
                      return _NotificationCard(
                        notification: provider.notifications[index - 1],
                        onRead: provider.markRead,
                      );
                    },
""",
)

internal = 'lib/features/internal/internal_dashboard_screen.dart'
replace_once(
    internal,
    "import '../../core/ui/hdc_colors.dart';\n",
    "import '../../core/ui/hdc_colors.dart';\nimport '../../core/ui/hdc_flow.dart';\n",
)
old_internal = """    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: HDCColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
"""
new_internal = """    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: HDCColors.brandGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HDCColors.accent.withValues(alpha: 0.20)),
        boxShadow: const [
          BoxShadow(
            color: HDCColors.shadowStrong,
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: LayoutBuilder(
"""
replace_once(internal, old_internal, new_internal)
replace_once(
    internal,
    "                'Statistics and actions are filtered by server-enforced '\n                'permissions. This workspace is not part of the public app.',",
    "                'Private operations are filtered by server-enforced permissions. Only authorized queues, statistics, and actions are shown in this workspace.',",
)

print(STAGE)
