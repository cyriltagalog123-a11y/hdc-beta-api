import 'package:flutter/material.dart';

class ModuleInfo {
  final String id;

  final String title;

  final IconData icon;

  final Widget homePage;

  final bool enabled;

  const ModuleInfo({
    required this.id,
    required this.title,
    required this.icon,
    required this.homePage,
    required this.enabled,
  });
}