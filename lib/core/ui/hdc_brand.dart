import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'hdc_colors.dart';
import 'hdc_spacing.dart';

/// A lightweight HDC signal-grid background that works without remote assets.
class HDCSignalBackdrop extends StatelessWidget {
  final Widget child;
  final bool dark;
  final EdgeInsetsGeometry? padding;

  const HDCSignalBackdrop({
    required this.child,
    this.dark = false,
    this.padding,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colors = dark
        ? const [HDCColors.primaryDeep, HDCColors.surfaceDark]
        : const [HDCColors.background, HDCColors.backgroundAlt];

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _HDCSignalGridPainter(dark: dark)),
            ),
          ),
          if (padding == null)
            child
          else
            Padding(padding: padding!, child: child),
        ],
      ),
    );
  }
}

class HDCBrandMark extends StatelessWidget {
  final double size;
  final bool darkSurface;

  const HDCBrandMark({
    this.size = 52,
    this.darkSurface = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'HelpDesk Connect',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: darkSurface
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [HDCColors.primarySoft, HDCColors.secondary],
                )
              : HDCColors.brandGradient,
          borderRadius: BorderRadius.circular(size * 0.28),
          border: Border.all(
            color: HDCColors.accent.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: HDCColors.primaryDeep.withValues(alpha: 0.28),
              blurRadius: size * 0.38,
              offset: Offset(0, size * 0.18),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: const _HDCBrandMarkPainter()),
            Center(
              child: Text(
                'HDC',
                style: TextStyle(
                  color: HDCColors.textLight,
                  fontSize: size * 0.25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: size * 0.018,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HDCBrandLockup extends StatelessWidget {
  final bool light;
  final bool compact;
  final double markSize;

  const HDCBrandLockup({
    this.light = false,
    this.compact = false,
    this.markSize = 48,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = light ? HDCColors.textLight : HDCColors.textPrimary;
    final secondaryText = light
        ? HDCColors.textLight.withValues(alpha: 0.66)
        : HDCColors.textSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HDCBrandMark(size: markSize, darkSurface: light),
        SizedBox(width: compact ? 10 : 14),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                compact ? 'HelpDesk Connect' : 'HELPDESK CONNECT',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: primaryText,
                  fontSize: compact ? 15 : 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: compact ? -0.2 : 1.1,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 3),
                Text(
                  'TECH SUPPORT NETWORK',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class HDCSignalPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final bool light;

  const HDCSignalPill({
    required this.label,
    this.icon,
    this.color = HDCColors.signal,
    this.light = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = light ? HDCColors.textLight : HDCColors.textPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: light
            ? HDCColors.textLight.withValues(alpha: 0.09)
            : color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(HDCSpacing.radiusPill),
        border: Border.all(
          color: light
              ? HDCColors.textLight.withValues(alpha: 0.17)
              : color.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          if (icon != null) ...[
            const SizedBox(width: 7),
            Icon(icon, size: 14, color: foreground),
          ],
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HDCBrandMarkPainter extends CustomPainter {
  const _HDCBrandMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = HDCColors.accent.withValues(alpha: 0.34)
      ..strokeWidth = math.max(1, size.width * 0.025)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = HDCColors.signal;

    final yTop = size.height * 0.20;
    final yBottom = size.height * 0.80;
    canvas.drawLine(
      Offset(size.width * 0.18, yTop),
      Offset(size.width * 0.82, yTop),
      line,
    );
    canvas.drawLine(
      Offset(size.width * 0.18, yBottom),
      Offset(size.width * 0.82, yBottom),
      line,
    );
    canvas.drawCircle(
      Offset(size.width * 0.18, yTop),
      size.width * 0.035,
      dot,
    );
    canvas.drawCircle(
      Offset(size.width * 0.82, yBottom),
      size.width * 0.035,
      dot,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HDCSignalGridPainter extends CustomPainter {
  final bool dark;

  const _HDCSignalGridPainter({required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = (dark ? HDCColors.accent : HDCColors.secondary).withValues(
        alpha: dark ? 0.055 : 0.035,
      )
      ..strokeWidth = 1;
    const step = 48.0;

    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final signal = Paint()
      ..color = (dark ? HDCColors.accent : HDCColors.secondary).withValues(
        alpha: dark ? 0.18 : 0.09,
      )
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(size.width * 0.58, -20)
      ..cubicTo(
        size.width * 0.70,
        size.height * 0.18,
        size.width * 0.76,
        size.height * 0.46,
        size.width + 24,
        size.height * 0.56,
      );
    canvas.drawPath(path, signal);

    final node = Paint()
      ..color = (dark ? HDCColors.signal : HDCColors.secondary).withValues(
        alpha: dark ? 0.5 : 0.18,
      );
    for (final point in [
      Offset(size.width * 0.09, size.height * 0.18),
      Offset(size.width * 0.82, size.height * 0.22),
      Offset(size.width * 0.72, size.height * 0.78),
    ]) {
      canvas.drawCircle(point, 3.2, node);
      canvas.drawCircle(point, 9.5, signal);
    }
  }

  @override
  bool shouldRepaint(covariant _HDCSignalGridPainter oldDelegate) {
    return oldDelegate.dark != dark;
  }
}
