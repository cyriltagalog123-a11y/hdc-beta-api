import 'package:flutter/material.dart';

import 'hdc_colors.dart';
import 'hdc_spacing.dart';

class HDCCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final bool elevated;

  const HDCCard({
    required this.child,
    this.padding = const EdgeInsets.all(HDCSpacing.lg),
    this.onTap,
    this.color,
    this.borderColor,
    this.elevated = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(HDCSpacing.radiusMedium);
    final content = Padding(padding: padding, child: child);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? HDCColors.surface,
        borderRadius: radius,
        border: Border.all(color: borderColor ?? HDCColors.border),
        boxShadow: elevated
            ? const [
                BoxShadow(
                  color: HDCColors.shadow,
                  blurRadius: 26,
                  offset: Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: onTap, child: content),
            ),
    );
  }
}
