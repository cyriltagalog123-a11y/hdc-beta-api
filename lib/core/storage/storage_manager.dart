enum HDCStorageOwnershipMode {
  hdcManaged,
  userOwned,
  organizationOwned,
}

enum HDCStorageBindingStatus {
  pending,
  active,
  degraded,
  revoked,
}

class HDCStorageBindingSummary {
  final String bindingId;
  final HDCStorageOwnershipMode mode;
  final HDCStorageBindingStatus status;
  final String providerLabel;
  final int quotaBytes;
  final int usedBytes;
  final bool isPrimary;

  const HDCStorageBindingSummary({
    required this.bindingId,
    required this.mode,
    required this.status,
    required this.providerLabel,
    required this.quotaBytes,
    required this.usedBytes,
    required this.isPrimary,
  });
}

class HDCStorageMigrationSummary {
  final String migrationId;
  final String sourceBindingId;
  final String destinationBindingId;
  final String status;
  final int copiedObjects;
  final int copiedBytes;

  const HDCStorageMigrationSummary({
    required this.migrationId,
    required this.sourceBindingId,
    required this.destinationBindingId,
    required this.status,
    required this.copiedObjects,
    required this.copiedBytes,
  });
}

/// Flutter receives sanitized storage state through the HDC API only.
/// Provider credentials, OAuth refresh tokens, database URLs, and privileged
/// provider SDKs must never be exposed through this gateway.
abstract interface class HDCStorageControlGateway {
  Future<List<HDCStorageBindingSummary>> loadBindings();

  Future<HDCStorageMigrationSummary> requestMigration({
    required String sourceBindingId,
    required String destinationBindingId,
    required String scope,
  });
}

class StorageManager {
  final HDCStorageControlGateway gateway;
  List<HDCStorageBindingSummary> _bindings = const [];

  StorageManager({required this.gateway});

  List<HDCStorageBindingSummary> get bindings =>
      List<HDCStorageBindingSummary>.unmodifiable(_bindings);

  HDCStorageBindingSummary? get primaryBinding {
    for (final binding in _bindings) {
      if (binding.isPrimary) return binding;
    }
    return null;
  }

  Future<void> initialize() async {
    _bindings = List<HDCStorageBindingSummary>.unmodifiable(
      await gateway.loadBindings(),
    );
  }

  Future<HDCStorageMigrationSummary> requestMigration({
    required String sourceBindingId,
    required String destinationBindingId,
    required String scope,
  }) {
    if (sourceBindingId == destinationBindingId) {
      throw ArgumentError(
        'Storage migration requires two different bindings.',
      );
    }
    return gateway.requestMigration(
      sourceBindingId: sourceBindingId,
      destinationBindingId: destinationBindingId,
      scope: scope,
    );
  }
}
