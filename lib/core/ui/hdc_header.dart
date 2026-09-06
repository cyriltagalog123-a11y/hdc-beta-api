import 'package:flutter/material.dart';

import 'hdc_colors.dart';

class HDCHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? eyebrow;
  final Widget? action;

  const HDCHeader({
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.action,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackAction = action != null && constraints.maxWidth < 560;
        final copy = _HeaderCopy(
          title: title,
          subtitle: subtitle,
          eyebrow: eyebrow,
        );

        if (stackAction) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              copy,
              const SizedBox(height: 16),
              Align(alignment: Alignment.centerLeft, child: action!),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: copy),
            if (action != null) ...[const SizedBox(width: 20), action!],
          ],
        );
      },
    );
  }
}

class _HeaderCopy extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? eyebrow;

  const _HeaderCopy({
    required this.title,
    required this.subtitle,
    required this.eyebrow,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: eyebrow == null ? 42 : 58,
          margin: const EdgeInsets.only(top: 2, right: 14),
          decoration: BoxDecoration(
            gradient: HDCColors.signalGradient,
            borderRadius: BorderRadius.circular(99),
            boxShadow: [
              BoxShadow(
                color: HDCColors.accent.withValues(alpha: 0.22),
                blurRadius: 12,
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow!.toUpperCase(),
                  style: const TextStyle(
                    color: HDCColors.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.25,
                  ),
                ),
                const SizedBox(height: 7),
              ],
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
