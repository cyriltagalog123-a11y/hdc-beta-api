from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, found {count}')
    return text.replace(old, new, 1)


main_path = Path('lib/main.dart')
main = main_path.read_text()
main = replace_once(
    main,
    "import 'providers/hdc_marketplace_provider.dart';\n",
    "import 'providers/hdc_marketplace_provider.dart';\nimport 'providers/hdc_news_provider.dart';\n",
    'main import',
)
main = replace_once(
    main,
    "        ChangeNotifierProxyProvider<HDCAuthProvider, HdcRoleCenterProvider>(\n",
    "        ChangeNotifierProxyProvider<HDCAuthProvider, HdcNewsProvider>(\n"
    "          create: (_) => HdcNewsProvider(client: roleApiClient),\n"
    "          update: (_, auth, newsProvider) {\n"
    "            final provider =\n"
    "                newsProvider ?? HdcNewsProvider(client: roleApiClient);\n"
    "            provider.bindIdentity(\n"
    "              auth.authenticated && !auth.guestMode ? auth.identity : null,\n"
    "            );\n"
    "            return provider;\n"
    "          },\n"
    "        ),\n"
    "        ChangeNotifierProxyProvider<HDCAuthProvider, HdcRoleCenterProvider>(\n",
    'main provider',
)
main_path.write_text(main)


dashboard_path = Path('lib/features/dashboard/dashboard_screen.dart')
dashboard = dashboard_path.read_text()
dashboard = replace_once(
    dashboard,
    "import '../marketplace/sales_center_screen.dart';\n",
    "import '../marketplace/sales_center_screen.dart';\n"
    "import '../knowledge_base/knowledge_base_screen.dart';\n"
    "import '../news/news_screen.dart';\n",
    'dashboard imports',
)
dashboard = replace_once(
    dashboard,
    "  void _openContactOwner(BuildContext context) {\n"
    "    Navigator.of(context).push(\n"
    "      HDCPageRoute<void>(page: const ContactOwnerScreen()),\n"
    "    );\n"
    "  }\n",
    "  void _openContactOwner(BuildContext context) {\n"
    "    Navigator.of(context).push(\n"
    "      HDCPageRoute<void>(page: const ContactOwnerScreen()),\n"
    "    );\n"
    "  }\n\n"
    "  void _openNews(BuildContext context) {\n"
    "    Navigator.of(context).push(\n"
    "      HDCPageRoute<void>(page: const NewsScreen()),\n"
    "    );\n"
    "  }\n\n"
    "  void _openKnowledgeBase(BuildContext context) {\n"
    "    Navigator.of(context).push(\n"
    "      HDCPageRoute<void>(page: const KnowledgeBaseScreen()),\n"
    "    );\n"
    "  }\n",
    'dashboard methods',
)
dashboard = replace_once(
    dashboard,
    "      HDCNavigationItem(\n"
    "        label: 'Notifications',\n"
    "        icon: Icons.notifications_none_rounded,\n"
    "        badgeCount: notificationCenter.unreadCount,\n"
    "        onTap: () => _openNotifications(context),\n"
    "      ),\n",
    "      HDCNavigationItem(\n"
    "        label: 'Notifications',\n"
    "        icon: Icons.notifications_none_rounded,\n"
    "        badgeCount: notificationCenter.unreadCount,\n"
    "        onTap: () => _openNotifications(context),\n"
    "      ),\n"
    "      HDCNavigationItem(\n"
    "        label: 'HDC News',\n"
    "        icon: Icons.newspaper_outlined,\n"
    "        onTap: () => _openNews(context),\n"
    "      ),\n"
    "      HDCNavigationItem(\n"
    "        label: 'Knowledge Base',\n"
    "        icon: Icons.menu_book_outlined,\n"
    "        onTap: () => _openKnowledgeBase(context),\n"
    "      ),\n",
    'dashboard secondary navigation',
)
dashboard_path.write_text(dashboard)
print('News provider, public News, and Knowledge Base shell wired.')
