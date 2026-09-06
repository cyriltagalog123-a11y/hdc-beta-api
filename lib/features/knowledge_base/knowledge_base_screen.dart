import 'package:flutter/material.dart';

import '../../core/ui/hdc_card.dart';
import '../../core/ui/hdc_colors.dart';
import '../../core/ui/hdc_flow.dart';
import '../../core/ui/hdc_spacing.dart';

class KnowledgeBaseScreen extends StatelessWidget {
  const KnowledgeBaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Knowledge Base')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(HDCSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const HDCFlowHero(
                    eyebrow: 'BUILD 26 READY',
                    title: 'HDC Knowledge Base',
                    description:
                        'The public Knowledge Base entry point is prepared now. Search, troubleshooting articles, guided fixes, authoring, review, feedback, and Nexus knowledge integration will be implemented in Build 26.',
                    icon: Icons.menu_book_outlined,
                    tags: [
                      HDCFlowTag(
                        label: 'Public troubleshooting',
                        icon: Icons.build_outlined,
                      ),
                      HDCFlowTag(
                        label: 'Nexus-ready foundation',
                        icon: Icons.psychology_alt_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: HDCSpacing.lg),
                  TextField(
                    enabled: false,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      labelText: 'Search the HDC Knowledge Base',
                      hintText: 'Search becomes active in Build 26',
                      suffixIcon: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: HDCColors.warning.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Center(
                          widthFactor: 1,
                          child: Text(
                            'BUILD 26',
                            style: TextStyle(
                              color: HDCColors.warning,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: HDCSpacing.lg),
                  const _CategoryGrid(),
                  const SizedBox(height: HDCSpacing.lg),
                  HDCCard(
                    borderColor: HDCColors.signal.withValues(alpha: 0.24),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What Build 26 will activate',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 12),
                        _Build26Item(
                          icon: Icons.search_rounded,
                          title: 'Knowledge search and troubleshooting discovery',
                        ),
                        _Build26Item(
                          icon: Icons.account_tree_outlined,
                          title: 'Step-by-step guided troubleshooting flows',
                        ),
                        _Build26Item(
                          icon: Icons.rate_review_outlined,
                          title: 'Article feedback and improvement signals',
                        ),
                        _Build26Item(
                          icon: Icons.edit_note_rounded,
                          title: 'Authorized knowledge authoring and review',
                        ),
                        _Build26Item(
                          icon: Icons.psychology_alt_outlined,
                          title: 'Nexus knowledge retrieval foundation',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: HDCSpacing.lg),
                  const HDCCard(
                    color: HDCColors.surfaceInteractive,
                    child: Text(
                      'This page is intentionally a shell only. It does not fabricate articles, search results, or Nexus answers before Build 26 has the backend knowledge authority and review rules in place.',
                      style: TextStyle(
                        color: HDCColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid();

  @override
  Widget build(BuildContext context) {
    const categories = [
      (Icons.computer_outlined, 'PC & Laptop', 'Hardware, Windows, peripherals'),
      (Icons.phone_android_outlined, 'Phones & Mobile', 'Devices, connectivity, apps'),
      (Icons.point_of_sale_outlined, 'POS & Business Tech', 'POS, KDS, EDC, kiosks'),
      (Icons.router_outlined, 'Network & Internet', 'Wi-Fi, LAN, routing, connectivity'),
      (Icons.print_outlined, 'Printers & Peripherals', 'Printers, scanners, headsets'),
      (Icons.security_outlined, 'Security & Accounts', 'Safe account and device guidance'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 620
                ? 2
                : 1;
        final width = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - ((columns - 1) * 14)) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final item in categories)
              SizedBox(
                width: width,
                child: HDCCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: HDCColors.secondary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(item.$1, color: HDCColors.secondary),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        item.$2,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.$3,
                        style: const TextStyle(
                          color: HDCColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'AVAILABLE IN BUILD 26',
                        style: TextStyle(
                          color: HDCColors.warning,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Build26Item extends StatelessWidget {
  final IconData icon;
  final String title;

  const _Build26Item({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: HDCColors.signal, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(title)),
        ],
      ),
    );
  }
}
