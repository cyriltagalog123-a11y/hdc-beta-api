import 'package:flutter/material.dart';

enum AssetHistoryType {
  created,
  assigned,
 transferred,
 maintenance,
 serviceRequest,
 inspection,
 warranty,
 softwareUpdate,
 retired,
}

class AssetHistory {
  final String id;

  final String assetId;

  final AssetHistoryType type;

  final String title;

  final String description;

  final DateTime createdAt;

  const AssetHistory({
    required this.id,
    required this.assetId,
    required this.type,
    required this.title,
    required this.description,
    required this.createdAt,
  });

  IconData get icon {
    switch (type) {
      case AssetHistoryType.created:
        return Icons.add_circle;

      case AssetHistoryType.assigned:
        return Icons.store;

      case AssetHistoryType.transferred:
        return Icons.swap_horiz;

      case AssetHistoryType.maintenance:
        return Icons.build;

      case AssetHistoryType.serviceRequest:
        return Icons.campaign;

      case AssetHistoryType.inspection:
        return Icons.fact_check;

      case AssetHistoryType.warranty:
        return Icons.verified;

      case AssetHistoryType.softwareUpdate:
        return Icons.system_update;

      case AssetHistoryType.retired:
        return Icons.archive;
    }
  }

  Color get color {
    switch (type) {
      case AssetHistoryType.created:
        return Colors.green;

      case AssetHistoryType.assigned:
        return Colors.blue;

      case AssetHistoryType.transferred:
        return Colors.orange;

      case AssetHistoryType.maintenance:
        return Colors.deepPurple;

      case AssetHistoryType.serviceRequest:
        return Colors.teal;

      case AssetHistoryType.inspection:
        return Colors.indigo;

      case AssetHistoryType.warranty:
        return Colors.green;

      case AssetHistoryType.softwareUpdate:
        return Colors.cyan;

      case AssetHistoryType.retired:
        return Colors.red;
    }
  }
}