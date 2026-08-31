import 'package:flutter/material.dart';

import 'hdc_colors.dart';

enum HDCButtonStyle { primary, secondary, ghost, danger }

class HDCButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final bool expanded;
  final HDCButtonStyle style;

  const HDCButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expanded = false,
    this.style = HDCButtonStyle.primary,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          )
        else if (icon != null)
          Icon(icon, size: 19),
        if (busy || icon != null) const SizedBox(width: 10),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
    final action = busy ? null : onPressed;

    final button = switch (style) {
      HDCButtonStyle.primary => FilledButton(onPressed: action, child: content),
      HDCButtonStyle.secondary => OutlinedButton(
        onPressed: action,
        child: content,
      ),
      HDCButtonStyle.ghost => TextButton(onPressed: action, child: content),
      HDCButtonStyle.danger => FilledButton(
        style: FilledButton.styleFrom(backgroundColor: HDCColors.danger),
        onPressed: action,
        child: content,
      ),
    };

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}
