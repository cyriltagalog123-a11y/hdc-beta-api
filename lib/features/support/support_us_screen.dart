import 'package:flutter/material.dart';

import '../../core/navigation/hdc_page_route.dart';
import '../../core/ui/hdc_card.dart';
import '../../core/ui/hdc_colors.dart';
import '../../core/ui/hdc_flow.dart';
import '../../core/ui/hdc_spacing.dart';
import '../news/news_screen.dart';
import 'contact_owner_screen.dart';

class SupportUsScreen extends StatelessWidget {
  const SupportUsScreen({super.key});

  void _openOwner(BuildContext context) {
    Navigator.of(context).push(
      HDCPageRoute<void>(page: const ContactOwnerScreen()),
    );
  }

  void _openNews(BuildContext context) {
    Navigator.of(context).push(
      HDCPageRoute<void>(page: const NewsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support HDC')),
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
                    eyebrow: 'SAICORE SUPPORT PROGRAM',
                    title: 'Support HDC without buying influence.',
                    description:
                        'SaiCore accepts support in three forms: one-time contributions, recurring support, and corporate sponsorships. HDC will prioritize payment channels that are available in the Philippines without a required monthly subscription, while keeping fees and trust boundaries clear.',
                    icon: Icons.volunteer_activism_outlined,
                    tags: [
                      HDCFlowTag(
                        label: 'PHP only for now',
                        icon: Icons.currency_exchange_rounded,
                      ),
                      HDCFlowTag(
                        label: 'Recognition by consent',
                        icon: Icons.workspace_premium_outlined,
                      ),
                      HDCFlowTag(
                        label: 'Trust stays independent',
                        icon: Icons.verified_user_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: HDCSpacing.lg),
                  const _SupportProgramOverview(),
                  const SizedBox(height: HDCSpacing.lg),
                  _PaymentChannelsCard(onContactOwner: () => _openOwner(context)),
                  const SizedBox(height: HDCSpacing.lg),
                  _RecognitionCard(onOpenNews: () => _openNews(context)),
                  const SizedBox(height: HDCSpacing.lg),
                  const _PrioritySupportGrid(),
                  const SizedBox(height: HDCSpacing.lg),
                  const _TrustBoundaryCard(),
                  const SizedBox(height: HDCSpacing.lg),
                  const _WhatHelpsMostCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportProgramOverview extends StatelessWidget {
  const _SupportProgramOverview();

  @override
  Widget build(BuildContext context) {
    const options = [
      (
        Icons.favorite_outline_rounded,
        'One-time support',
        'A single voluntary PHP contribution with no special platform privileges attached.',
        HDCColors.signal,
      ),
      (
        Icons.autorenew_rounded,
        'Recurring support',
        'Optional ongoing support through a channel that supports recurring payments without requiring SaiCore to buy a monthly platform plan.',
        HDCColors.secondary,
      ),
      (
        Icons.apartment_outlined,
        'Corporate sponsorship',
        'Businesses and organizations can discuss infrastructure, event, development, or other sponsorship support directly with SaiCore.',
        HDCColors.success,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 850 ? 3 : 1;
        final width = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - 28) / 3;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final option in options)
              SizedBox(
                width: width,
                child: HDCCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: option.$4.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(option.$1, color: option.$4),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        option.$2,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        option.$3,
                        style: const TextStyle(
                          color: HDCColors.textSecondary,
                          height: 1.5,
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

class _PaymentChannelsCard extends StatelessWidget {
  final VoidCallback onContactOwner;

  const _PaymentChannelsCard({required this.onContactOwner});

  @override
  Widget build(BuildContext context) {
    const channels = [
      (
        'GCash / QR',
        'Preferred local one-time route',
        'Destination setup required',
        Icons.qr_code_rounded,
      ),
      (
        'Maya / QR Ph',
        'Local wallet and interoperable QR option',
        'Destination setup required',
        Icons.account_balance_wallet_outlined,
      ),
      (
        'PayPal',
        'Optional online contribution route',
        'Account/link verification required',
        Icons.public_rounded,
      ),
      (
        'Ko-fi or similar',
        'Useful for one-time or recurring support',
        'SaiCore page/link required',
        Icons.local_cafe_outlined,
      ),
      (
        'Bank / transfer route',
        'Useful for larger PHP sponsorships',
        'Published only after owner approval',
        Icons.account_balance_outlined,
      ),
      (
        'Corporate arrangement',
        'Invoice, sponsorship, or resource support discussion',
        'Contact SaiCore first',
        Icons.handshake_outlined,
      ),
    ];

    return HDCCard(
      color: HDCColors.primaryDeep,
      borderColor: HDCColors.accent.withValues(alpha: 0.22),
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PAYMENT CHANNEL STRATEGY',
            style: TextStyle(
              color: HDCColors.accent,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Use several legitimate channels instead of locking SaiCore to one provider.',
            style: TextStyle(
              color: HDCColors.textLight,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            'The current policy is PHP-only and prefers channels with no required setup or monthly subscription cost. A provider may still charge transaction, processor, withdrawal, or conversion fees, so HDC will disclose those instead of advertising any route as universally fee-free.',
            style: TextStyle(
              color: HDCColors.textLight.withValues(alpha: 0.74),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 760 ? 2 : 1;
              final width = columns == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final channel in channels)
                    SizedBox(
                      width: width,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(channel.$4, color: HDCColors.accent),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    channel.$1,
                                    style: const TextStyle(
                                      color: HDCColors.textLight,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    channel.$2,
                                    style: TextStyle(
                                      color: HDCColors.textLight.withValues(
                                        alpha: 0.70,
                                      ),
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    channel.$3.toUpperCase(),
                                    style: const TextStyle(
                                      color: HDCColors.accent,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: onContactOwner,
                icon: const Icon(Icons.mail_outline_rounded),
                label: const Text('Discuss Sponsorship'),
              ),
              Text(
                'Financial intake remains inactive until official SaiCore destination details are verified and published.',
                style: TextStyle(
                  color: HDCColors.textLight.withValues(alpha: 0.68),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecognitionCard extends StatelessWidget {
  final VoidCallback onOpenNews;

  const _RecognitionCard({required this.onOpenNews});

  @override
  Widget build(BuildContext context) {
    return HDCCard(
      borderColor: HDCColors.success.withValues(alpha: 0.25),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.workspace_premium_outlined,
                    color: HDCColors.success,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Public supporter recognition',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              const Text(
                'If a supporter or sponsor agrees to be publicly named, SaiCore may publish a Recognition post in HDC News. The display name and recognition message must match the consent given. Anonymous or private support stays private.',
                style: TextStyle(
                  color: HDCColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Recognition is publicity only. It does not create a rating boost, verification status, moderation exception, dispute advantage, priority service entitlement, or access to private HDC data.',
                style: TextStyle(
                  color: HDCColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          );
          if (constraints.maxWidth < 650) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                copy,
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: onOpenNews,
                  icon: const Icon(Icons.newspaper_outlined),
                  label: const Text('Open HDC News'),
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: 20),
              OutlinedButton.icon(
                onPressed: onOpenNews,
                icon: const Icon(Icons.newspaper_outlined),
                label: const Text('Open HDC News'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PrioritySupportGrid extends StatelessWidget {
  const _PrioritySupportGrid();

  @override
  Widget build(BuildContext context) {
    const items = [
      _SupportPath(
        icon: Icons.bug_report_outlined,
        title: 'Test and report defects',
        description:
            'Use HDC like a real customer, technician, seller, or business. Clear reproduction steps, screenshots, affected workflow, and reference IDs are more valuable than vague bug reports.',
        accent: HDCColors.danger,
      ),
      _SupportPath(
        icon: Icons.fact_check_outlined,
        title: 'Challenge the workflow',
        description:
            'Try unusual but legitimate cases: cancellations, disputes, role changes, multiple offers, slow connections, interrupted sessions, and account switching.',
        accent: HDCColors.warning,
      ),
      _SupportPath(
        icon: Icons.campaign_outlined,
        title: 'Share HDC responsibly',
        description:
            'Recommend HDC to people who genuinely need technology support or technicians who can provide useful beta feedback. Quality adoption matters more than raw sign-ups.',
        accent: HDCColors.secondary,
      ),
      _SupportPath(
        icon: Icons.lightbulb_outline_rounded,
        title: 'Suggest practical improvements',
        description:
            'Send feature ideas tied to a real problem, user type, or workflow. Strong suggestions explain what is difficult today and what a better outcome should look like.',
        accent: HDCColors.signal,
      ),
      _SupportPath(
        icon: Icons.menu_book_outlined,
        title: 'Suggest Knowledge Base topics',
        description:
            'Tell SaiCore which devices, errors, POS issues, software, or recurring technical problems deserve guided troubleshooting coverage in Build 26.',
        accent: HDCColors.electric,
      ),
      _SupportPath(
        icon: Icons.handshake_outlined,
        title: 'Offer partnership or resources',
        description:
            'Businesses, technical groups, schools, service providers, sponsors, or infrastructure partners can contact SaiCore directly for collaboration.',
        accent: HDCColors.success,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Support that does not require money',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Useful evidence, coverage, and responsible referrals remain valuable even after financial-support channels are activated.',
          style: TextStyle(
            color: HDCColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 620
                    ? 2
                    : 1;
            final itemWidth = columns == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - ((columns - 1) * 14)) / columns;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final item in items)
                  SizedBox(
                    width: itemWidth,
                    child: _SupportPathCard(item: item),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SupportPath {
  final IconData icon;
  final String title;
  final String description;
  final Color accent;

  const _SupportPath({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
  });
}

class _SupportPathCard extends StatelessWidget {
  final _SupportPath item;

  const _SupportPathCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return HDCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: item.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: item.accent.withValues(alpha: 0.20)),
            ),
            child: Icon(item.icon, color: item.accent),
          ),
          const SizedBox(height: 16),
          Text(item.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 7),
          Text(
            item.description,
            style: const TextStyle(
              color: HDCColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustBoundaryCard extends StatelessWidget {
  const _TrustBoundaryCard();

  @override
  Widget build(BuildContext context) {
    const rules = [
      'No purchased ratings or review manipulation.',
      'No purchased verification or trust status.',
      'No moderation or dispute exceptions for supporters.',
      'No access to private user, transaction, chat, or internal data.',
      'No guaranteed product decisions in exchange for money or influence.',
      'No special marketplace ranking or technician visibility purchased through support.',
    ];

    return HDCCard(
      borderColor: HDCColors.success.withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: HDCColors.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Support must never buy trust',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Anyone may support SaiCore and HDC, but support does not change platform rules, reputation, verification, safety decisions, ranking, or access controls.',
            style: TextStyle(
              color: HDCColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          for (final rule in rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle_outline_rounded,
                      color: HDCColors.success,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      rule,
                      style: const TextStyle(
                        color: HDCColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _WhatHelpsMostCard extends StatelessWidget {
  const _WhatHelpsMostCard();

  @override
  Widget build(BuildContext context) {
    return HDCCard(
      color: HDCColors.surfaceInteractive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A useful support report includes',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('What you were trying to do')),
              Chip(label: Text('What actually happened')),
              Chip(label: Text('Steps to reproduce')),
              Chip(label: Text('Device / browser / platform')),
              Chip(label: Text('HDC reference ID when relevant')),
              Chip(label: Text('Screenshot without private data')),
              Chip(label: Text('What you expected instead')),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Do not include passwords, one-time codes, recovery answers, full banking details, private keys, or another user’s confidential data in a support report.',
            style: TextStyle(
              color: HDCColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
