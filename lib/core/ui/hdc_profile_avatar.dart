import 'package:flutter/material.dart';

import 'hdc_colors.dart';

class HdcProfileAvatar extends StatelessWidget {
  final String avatarUrl;
  final String name;
  final double size;

  const HdcProfileAvatar({
    required this.avatarUrl,
    required this.name,
    this.size = 52,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: HDCColors.secondary.withValues(alpha: 0.11),
      child: const Icon(Icons.person_outline, color: HDCColors.secondary),
    );
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: avatarUrl.startsWith('https://')
            ? Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                semanticLabel: '$name profile photo',
                webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                errorBuilder: (context, error, stack) => fallback,
              )
            : fallback,
      ),
    );
  }
}
