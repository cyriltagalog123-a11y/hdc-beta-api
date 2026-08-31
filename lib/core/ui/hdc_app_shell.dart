import 'package:flutter/material.dart';

import 'hdc_brand.dart';
import 'hdc_colors.dart';
import 'hdc_spacing.dart';

class HDCNavigationItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;
  final int badgeCount;

  const HDCNavigationItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
    this.badgeCount = 0,
  });
}

class HDCAppShell extends StatelessWidget {
  final Widget child;
  final List<HDCNavigationItem> primaryItems;
  final List<HDCNavigationItem> secondaryItems;
  final String workspaceLabel;
  final String userLabel;
  final VoidCallback onSignOut;
  final VoidCallback? onNotifications;
  final int notificationCount;

  const HDCAppShell({
    required this.child,
    required this.primaryItems,
    required this.secondaryItems,
    required this.workspaceLabel,
    required this.userLabel,
    required this.onSignOut,
    this.onNotifications,
    this.notificationCount = 0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useSidebar = constraints.maxWidth >= 1120;
        if (useSidebar) {
          return Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: HDCSpacing.navigationWidth,
                  child: _NavigationPanel(
                    primaryItems: primaryItems,
                    secondaryItems: secondaryItems,
                    workspaceLabel: workspaceLabel,
                    userLabel: userLabel,
                    onSignOut: onSignOut,
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            leading: Builder(
              builder: (context) => IconButton(
                tooltip: 'Open navigation',
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            ),
            title: const HDCBrandLockup(
              light: true,
              compact: true,
              markSize: 34,
            ),
            actions: [
              if (onNotifications != null)
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: onNotifications,
                  icon: Badge(
                    isLabelVisible: notificationCount > 0,
                    label: Text(
                      notificationCount > 99 ? '99+' : '$notificationCount',
                    ),
                    child: const Icon(Icons.notifications_none_rounded),
                  ),
                ),
              const SizedBox(width: 6),
            ],
          ),
          drawer: Drawer(
            width: 310,
            child: _NavigationPanel(
              primaryItems: primaryItems,
              secondaryItems: secondaryItems,
              workspaceLabel: workspaceLabel,
              userLabel: userLabel,
              onSignOut: onSignOut,
              closeDrawer: true,
            ),
          ),
          body: child,
        );
      },
    );
  }
}

class _NavigationPanel extends StatelessWidget {
  final List<HDCNavigationItem> primaryItems;
  final List<HDCNavigationItem> secondaryItems;
  final String workspaceLabel;
  final String userLabel;
  final VoidCallback onSignOut;
  final bool closeDrawer;

  const _NavigationPanel({
    required this.primaryItems,
    required this.secondaryItems,
    required this.workspaceLabel,
    required this.userLabel,
    required this.onSignOut,
    this.closeDrawer = false,
  });

  void _invoke(BuildContext context, VoidCallback action) {
    if (!closeDrawer) {
      action();
      return;
    }
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => action());
  }

  @override
  Widget build(BuildContext context) {
    return HDCSignalBackdrop(
      dark: true,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 22, 18, 20),
              child: HDCBrandLockup(light: true, markSize: 44),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: HDCSignalPill(
                label: workspaceLabel.toUpperCase(),
                icon: Icons.hub_outlined,
                light: true,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final item in primaryItems)
                    _NavigationTile(
                      item: item,
                      onTap: () => _invoke(context, item.onTap),
                    ),
                  if (secondaryItems.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(12, 20, 12, 9),
                      child: Text(
                        'ACCOUNT & TOOLS',
                        style: TextStyle(
                          color: HDCColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.35,
                        ),
                      ),
                    ),
                    for (final item in secondaryItems)
                      _NavigationTile(
                        item: item,
                        onTap: () => _invoke(context, item.onTap),
                      ),
                  ],
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HDCColors.textLight.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(HDCSpacing.radiusMedium),
                border: Border.all(
                  color: HDCColors.textLight.withValues(alpha: 0.10),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: HDCColors.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: HDCColors.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      userLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HDCColors.textLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sign out',
                    onPressed: () => _invoke(context, onSignOut),
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: HDCColors.textLight,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationTile extends StatelessWidget {
  final HDCNavigationItem item;
  final VoidCallback onTap;

  const _NavigationTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final foreground = item.selected
        ? HDCColors.textLight
        : HDCColors.textLight.withValues(alpha: 0.70);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: item.selected
            ? HDCColors.secondary.withValues(alpha: 0.30)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(item.icon, size: 20, color: foreground),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 13,
                      fontWeight: item.selected
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                ),
                if (item.badgeCount > 0)
                  Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: HDCColors.accent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      item.badgeCount > 99 ? '99+' : '${item.badgeCount}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: HDCColors.primaryDeep,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
