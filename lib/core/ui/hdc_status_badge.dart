import 'package:flutter/material.dart';

import 'hdc_colors.dart';
import 'hdc_spacing.dart';

enum HDCStatusTone { neutral, info, success, warning, danger }

class HDCStatusBadge extends StatelessWidget {
  final String label;
  final HDCStatusTone tone;
  final IconData? icon;

  const HDCStatusBadge({
    required this.label,
    this.tone = HDCStatusTone.neutral,
    this.icon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      HDCStatusTone.neutral => HDCColors.textSecondary,
      HDCStatusTone.info => HDCColors.info,
      HDCStatusTone.success => HDCColors.success,
      HDCStatusTone.warning => HDCColors.warning,
      HDCStatusTone.danger => HDCColors.danger,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(HDCSpacing.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? Icons.circle, size: icon == null ? 7 : 14, color: color),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
