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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        if (action != null) ...[const SizedBox(width: 16), action!],
      ],
    );
  }
}
