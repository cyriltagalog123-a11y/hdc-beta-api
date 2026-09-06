from pathlib import Path


def replace_once(path: str, old: str, new: str):
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected 1 match, found {count}: {old[:120]!r}')
    p.write_text(text.replace(old, new, 1))

replace_once(
    'lib/features/marketplace/marketplace_catalog_screen.dart',
    "Color _purchaseStatusColor(ProductPurchaseStatus status) => switch (status) {\n      ProductPurchaseStatus.submitted => HDCColors.warning,\n      ProductPurchaseStatus.accepted => HDCColors.success,\n      ProductPurchaseStatus.declined => HDCColors.danger,\n      ProductPurchaseStatus.cancelled => HDCColors.textSecondary,\n    };",
    "Color _purchaseStatusColor(ProductPurchaseStatus status) => switch (status) {\n      ProductPurchaseStatus.submitted => HDCColors.warning,\n      ProductPurchaseStatus.accepted => HDCColors.success,\n      ProductPurchaseStatus.fulfilled => HDCColors.info,\n      ProductPurchaseStatus.completed => HDCColors.success,\n      ProductPurchaseStatus.declined => HDCColors.danger,\n      ProductPurchaseStatus.cancelled => HDCColors.textSecondary,\n    };",
)

replace_once(
    'lib/features/marketplace/sales_center_screen.dart',
    "Color _orderStatusColor(ProductPurchaseStatus status) => switch (status) {\n      ProductPurchaseStatus.submitted => HDCColors.warning,\n      ProductPurchaseStatus.accepted => HDCColors.success,\n      ProductPurchaseStatus.declined => HDCColors.danger,\n      ProductPurchaseStatus.cancelled => HDCColors.textSecondary,\n    };",
    "Color _orderStatusColor(ProductPurchaseStatus status) => switch (status) {\n      ProductPurchaseStatus.submitted => HDCColors.warning,\n      ProductPurchaseStatus.accepted => HDCColors.success,\n      ProductPurchaseStatus.fulfilled => HDCColors.info,\n      ProductPurchaseStatus.completed => HDCColors.success,\n      ProductPurchaseStatus.declined => HDCColors.danger,\n      ProductPurchaseStatus.cancelled => HDCColors.textSecondary,\n    };",
)

replace_once(
    'lib/features/internal/suggestion_management_screen.dart',
    "    if (save != true) {\n      response.dispose();\n      return;\n    }\n    try {\n      final client = context.read<HdcCommunityProvider>().client;",
    "    if (save != true) {\n      response.dispose();\n      return;\n    }\n    if (!context.mounted) {\n      response.dispose();\n      return;\n    }\n    try {\n      final client = context.read<HdcCommunityProvider>().client;",
)

print('Build 26 Flutter follow-up fixes applied')
