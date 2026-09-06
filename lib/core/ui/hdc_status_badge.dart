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
    final semanticTone = switch (tone) {
      HDCStatusTone.neutral => 'Status',
      HDCStatusTone.info => 'Information',
      HDCStatusTone.success => 'Successful status',
      HDCStatusTone.warning => 'Attention status',
      HDCStatusTone.danger => 'Critical status',
    };

    return Semantics(
      label: '$semanticTone: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(HDCSpacing.radiusPill),
          border: Border.all(color: color.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: icon == null ? 7 : 20,
              height: icon == null ? 7 : 20,
              decoration: BoxDecoration(
                color: icon == null ? color : color.withValues(alpha: 0.11),
                shape: icon == null ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: icon == null ? null : BorderRadius.circular(7),
              ),
              alignment: Alignment.center,
              child: icon == null
                  ? null
                  : Icon(icon, size: 13, color: color),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.05,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
