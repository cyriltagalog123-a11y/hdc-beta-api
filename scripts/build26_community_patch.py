from pathlib import Path
import hashlib
import json


def replace_once(path: str, old: str, new: str):
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected 1 match, found {count}: {old[:100]!r}')
    p.write_text(text.replace(old, new, 1))

# Backend commerce parser must understand the new fulfillment/completion lifecycle.
replace_once(
    'netlify/functions/_lib/commerce.mts',
    "export const productPurchaseStatuses = ['submitted', 'accepted', 'declined', 'cancelled'] as const;",
    "export const productPurchaseStatuses = ['submitted', 'accepted', 'fulfilled', 'completed', 'declined', 'cancelled'] as const;",
)

# Flutter marketplace parser must accept the same authoritative states.
model = 'lib/models/marketplace_purchase.dart'
replace_once(
    model,
    "enum ProductPurchaseStatus {\n  submitted,\n  accepted,\n  declined,\n  cancelled,\n}",
    "enum ProductPurchaseStatus {\n  submitted,\n  accepted,\n  fulfilled,\n  completed,\n  declined,\n  cancelled,\n}",
)
replace_once(
    model,
    "        ProductPurchaseStatus.accepted => 'Accepted',\n        ProductPurchaseStatus.declined => 'Declined',",
    "        ProductPurchaseStatus.accepted => 'Accepted',\n        ProductPurchaseStatus.fulfilled => 'Fulfilled — awaiting buyer confirmation',\n        ProductPurchaseStatus.completed => 'Completed',\n        ProductPurchaseStatus.declined => 'Declined',",
)

# Register the Community provider in the app-wide provider tree.
main = 'lib/main.dart'
replace_once(
    main,
    "import 'providers/hdc_auth_provider.dart';\n",
    "import 'providers/hdc_auth_provider.dart';\nimport 'providers/hdc_community_provider.dart';\n",
)
replace_once(
    main,
    "        ChangeNotifierProxyProvider<HDCAuthProvider, HdcNewsProvider>(\n",
    "        ChangeNotifierProxyProvider<HDCAuthProvider, HdcCommunityProvider>(\n          create: (_) => HdcCommunityProvider(client: roleApiClient),\n          update: (_, auth, communityProvider) {\n            final provider = communityProvider ?? HdcCommunityProvider(client: roleApiClient);\n            provider.bindUser(\n              auth.authenticated && !auth.guestMode ? auth.identity?.id : null,\n            );\n            return provider;\n          },\n        ),\n        ChangeNotifierProxyProvider<HDCAuthProvider, HdcNewsProvider>(\n",
)

# Navigation: member-facing Community Center plus privileged Suggestion Queue.
dash = 'lib/features/dashboard/dashboard_screen.dart'
replace_once(
    dash,
    "import '../customer_proposals/customer_offers_screen.dart';\n",
    "import '../customer_proposals/customer_offers_screen.dart';\nimport '../community/community_center_screen.dart';\n",
)
replace_once(
    dash,
    "import '../internal/internal_dashboard_screen.dart';\n",
    "import '../internal/internal_dashboard_screen.dart';\nimport '../internal/suggestion_management_screen.dart';\n",
)
replace_once(
    dash,
    "  void _openNews(BuildContext context) {\n",
    "  void _openCommunityCenter(BuildContext context) {\n    Navigator.of(context).push(\n      HDCPageRoute<void>(page: const CommunityCenterScreen()),\n    );\n  }\n\n  void _openSuggestionQueue(BuildContext context) {\n    Navigator.of(context).push(\n      HDCPageRoute<void>(page: const SuggestionManagementScreen()),\n    );\n  }\n\n  void _openNews(BuildContext context) {\n",
)
replace_once(
    dash,
    "    final isTechnician =\n        auth.authenticated &&\n        auth.identity?.hasPlatformRole(HDCPlatformRole.technician) == true;\n",
    "    final isTechnician =\n        auth.authenticated &&\n        auth.identity?.hasPlatformRole(HDCPlatformRole.technician) == true;\n    final canManageSuggestions =\n        auth.authenticated &&\n        auth.identity?.internalRoles.any(\n              (role) => role.hasPrivilegedResourceAccess,\n            ) ==\n            true;\n",
)
replace_once(
    dash,
    "      HDCNavigationItem(\n        label: 'Knowledge Base',\n",
    "      if (isRegisteredUser)\n        HDCNavigationItem(\n          label: 'Ratings & Community',\n          icon: Icons.stars_outlined,\n          onTap: () => _openCommunityCenter(context),\n        ),\n      if (canManageSuggestions)\n        HDCNavigationItem(\n          label: 'Suggestion Queue',\n          icon: Icons.fact_check_outlined,\n          onTap: () => _openSuggestionQueue(context),\n        ),\n      HDCNavigationItem(\n        label: 'Knowledge Base',\n",
)

# Suggestion admin screen uses the already-bound community provider's API client.
admin = 'lib/features/internal/suggestion_management_screen.dart'
replace_once(
    admin,
    "import '../../core/api/hdc_workflow_api_client.dart';\n",
    "import '../../core/api/hdc_workflow_api_client.dart';\nimport '../../providers/hdc_community_provider.dart';\n",
)
replace_once(
    admin,
    "      final client = context.read<HdcWorkflowApiClient>();\n      final response = await client.get('/api/internal/community');",
    "      final client = context.read<HdcCommunityProvider>().client;\n      if (client == null) {\n        throw const HdcWorkflowException(\n          code: 'backend_unavailable',\n          message: 'HDC suggestion management is unavailable.',\n        );\n      }\n      final response = await client.get('/api/internal/community');",
)
replace_once(
    admin,
    "      final client = context.read<HdcWorkflowApiClient>();\n      await client.put('/api/internal/community', body: {",
    "      final client = context.read<HdcCommunityProvider>().client;\n      if (client == null) {\n        throw const HdcWorkflowException(\n          code: 'backend_unavailable',\n          message: 'HDC suggestion management is unavailable.',\n        );\n      }\n      await client.put('/api/internal/community', body: {",
)

# Register immutable migration checksum.
migration = Path('migrations/0022_build26_feedback_reputation.sql')
digest = hashlib.sha256(migration.read_bytes()).hexdigest()
checksums_path = Path('migrations/checksums.json')
checksums = json.loads(checksums_path.read_text())
checksums['0022_build26_feedback_reputation.sql'] = digest
checksums_path.write_text(json.dumps(checksums, indent=2) + '\n')

print(f'Build 26 community integration applied; 0022 checksum {digest}')
