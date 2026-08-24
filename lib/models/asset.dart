import 'package:flutter/material.dart';

enum AssetStatus {
  active,
  maintenance,
  retired,
}

class Asset {
  final String id;

  final String assetTag;

  final String name;

  final String category;

  final String brand;

  final String model;

  final String serialNumber;

  final String organizationId;

  final String storeId;

  final DateTime purchaseDate;

  final DateTime? warrantyExpiry;

  final AssetStatus status;

  const Asset({
    required this.id,
    required this.assetTag,
    required this.name,
    required this.category,
    required this.brand,
    required this.model,
    required this.serialNumber,
    required this.organizationId,
    required this.storeId,
    required this.purchaseDate,
    this.warrantyExpiry,
    this.status = AssetStatus.active,
  });

  String get statusLabel {
    switch (status) {
      case AssetStatus.active:
        return "Active";

      case AssetStatus.maintenance:
        return "Maintenance";

      case AssetStatus.retired:
        return "Retired";
    }
  }

  Color get statusColor {
    switch (status) {
      case AssetStatus.active:
        return Colors.green;

      case AssetStatus.maintenance:
        return Colors.orange;

      case AssetStatus.retired:
        return Colors.red;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case AssetStatus.active:
        return Icons.check_circle;

      case AssetStatus.maintenance:
        return Icons.build;

      case AssetStatus.retired:
        return Icons.archive;
    }
  }
}