import 'package:flutter/material.dart';

import 'hdc_brand.dart';
import 'hdc_card.dart';
import 'hdc_colors.dart';
import 'hdc_section_title.dart';
import 'hdc_spacing.dart';
import 'hdc_status_badge.dart';

class HDCFlowTag {
  final String label;
  final IconData icon;
  final Color color;

  const HDCFlowTag({
    required this.label,
    required this.icon,
    this.color = HDCColors.signal,
  });
}

class HDCFlowHero extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;
  final List<HDCFlowTag> tags;
  final Widget? action;

  const HDCFlowHero({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
    this.tags = const [],
    this.action,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(HDCSpacing.lg),
      decoration: BoxDecoration(
        gradient: HDCColors.brandGradient,
        borderRadius: BorderRadius.circular(HDCSpacing.radiusLarge),
        border: Border.all(
          color: HDCColors.accent.withValues(alpha: 0.24),
        ),
        boxShadow: const [
          BoxShadow(
            color: HDCColors.shadow,
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: const TextStyle(
                  color: HDCColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: HDCColors.textLight,
                  fontSize: wide ? 30 : 25,
                  height: 1.14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.55,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                style: TextStyle(
                  color: HDCColors.textLight.withValues(alpha: 0.72),
                  height: 1.5,
                ),
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tags
                      .map(
                        (tag) => HDCSignalPill(
                          label: tag.label,
                          icon: tag.icon,
                          color: tag.color,
                          light: true,
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ],
          );
          final iconPanel = Container(
            width: wide ? 74 : 58,
            height: wide ? 74 : 58,
            decoration: BoxDecoration(
              color: HDCColors.accent.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: HDCColors.accent.withValues(alpha: 0.28),
              ),
            ),
            child: Icon(
              icon,
              color: HDCColors.accent,
              size: wide ? 34 : 28,
            ),
          );

          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: Alignment.centerLeft, child: iconPanel),
                const SizedBox(height: 18),
                copy,
                if (action != null) ...[
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, child: action),
                ],
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              iconPanel,
              const SizedBox(width: 22),
              Expanded(child: copy),
              if (action != null) ...[
                const SizedBox(width: 24),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 230),
                  child: action!,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class HDCFlowProgress extends StatelessWidget {
  final List<String> steps;
  final int currentStep;

  const HDCFlowProgress({
    required this.steps,
    required this.currentStep,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var index = 0; index < steps.length; index += 1)
          HDCStatusBadge(
            label: '${index + 1}. ${steps[index]}',
            tone: index + 1 < currentStep
                ? HDCStatusTone.success
                : index + 1 == currentStep
                ? HDCStatusTone.info
                : HDCStatusTone.neutral,
            icon: index + 1 < currentStep
                ? Icons.check_rounded
                : index + 1 == currentStep
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
          ),
      ],
    );
  }
}

class HDCSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  const HDCSectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return HDCCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackTrailing =
              trailing != null && constraints.maxWidth < 520;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HDCSectionTitle(
                title: title,
                subtitle: subtitle,
                trailing: stackTrailing ? null : trailing,
              ),
              if (stackTrailing) ...[
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: trailing!),
              ],
              const SizedBox(height: 20),
              child,
            ],
          );
        },
      ),
    );
  }
}

class HDCResponsiveActions extends StatelessWidget {
  final List<Widget> actions;
  final double breakpoint;

  const HDCResponsiveActions({
    required this.actions,
    this.breakpoint = 560,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= breakpoint) {
          return Row(
            children: [
              for (var index = 0; index < actions.length; index += 1) ...[
                if (index > 0) const SizedBox(width: 12),
                Expanded(child: actions[index]),
              ],
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < actions.length; index += 1) ...[
              if (index > 0) const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: actions[index]),
            ],
          ],
        );
      },
    );
  }
}

class HDCMetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const HDCMetricTile({
    required this.icon,
    required this.label,
    required this.value,
    this.color = HDCColors.secondary,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(HDCSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(HDCSpacing.radiusSmall),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: HDCColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HDCEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<Widget> actions;
  final Color color;

  const HDCEmptyState({
    required this.icon,
    required this.title,
    required this.description,
    this.actions = const [],
    this.color = HDCColors.secondary,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return HDCCard(
      padding: const EdgeInsets.all(HDCSpacing.xl),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 38, color: color),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: HDCColors.textSecondary,
              height: 1.5,
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}
