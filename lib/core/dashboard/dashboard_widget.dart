import 'package:flutter/widgets.dart';

class DashboardWidget {
  final String id;

  final String title;

  final IconData icon;

  final Widget Function(BuildContext) builder;

  const DashboardWidget({
    required this.id,
    required this.title,
    required this.icon,
    required this.builder,
  });
}