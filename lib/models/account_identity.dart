final RegExp _hdcAccountUuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

bool isValidHdcAccountId(Object? value) {
  return value is String && _hdcAccountUuidPattern.hasMatch(value);
}

enum HDCAccountStatus {
  pendingVerification,
  active,
  suspended,
  disabled,
  deleted,
}

/// Product capabilities that an HDC member can use across the platform.
///
/// Customer is granted by public registration. Every other platform role is
/// activated only by a trusted approval workflow.
enum HDCPlatformRole { customer, technician, seller, business, supplier, store }

extension HDCPlatformRoleDetails on HDCPlatformRole {
  String get code => name;

  String get label {
    switch (this) {
      case HDCPlatformRole.customer:
        return 'Customer';
      case HDCPlatformRole.technician:
        return 'Technician';
      case HDCPlatformRole.seller:
        return 'Seller';
      case HDCPlatformRole.business:
        return 'Business';
      case HDCPlatformRole.supplier:
        return 'Supplier';
      case HDCPlatformRole.store:
        return 'Store';
    }
  }

  bool get requiresApproval => this != HDCPlatformRole.customer;
}

HDCPlatformRole? parseHDCPlatformRole(Object? value) {
  final code = '$value'.trim().toLowerCase().replaceAll('-', '_');
  for (final role in HDCPlatformRole.values) {
    if (role.code == code) return role;
  }
  return null;
}

/// Private HDC operational authority. These roles are never selectable during
/// registration or through a platform-role application.
enum HDCInternalRole { owner, superAdmin, admin, moderator }

extension HDCInternalRoleDetails on HDCInternalRole {
  String get code {
    switch (this) {
      case HDCInternalRole.superAdmin:
        return 'super_admin';
      case HDCInternalRole.owner:
      case HDCInternalRole.admin:
      case HDCInternalRole.moderator:
        return name;
    }
  }

  String get label {
    switch (this) {
      case HDCInternalRole.owner:
        return 'Owner';
      case HDCInternalRole.superAdmin:
        return 'Super Admin';
      case HDCInternalRole.admin:
        return 'Admin';
      case HDCInternalRole.moderator:
        return 'Moderator';
    }
  }

  int get authorityLevel {
    switch (this) {
      case HDCInternalRole.owner:
        return 400;
      case HDCInternalRole.superAdmin:
        return 300;
      case HDCInternalRole.admin:
        return 200;
      case HDCInternalRole.moderator:
        return 100;
    }
  }

  bool get canApprovePlatformRoles =>
      this == HDCInternalRole.owner || this == HDCInternalRole.superAdmin;

  bool get canManageInternalStructure => canApprovePlatformRoles;

  bool get hasPrivilegedResourceAccess =>
      this == HDCInternalRole.owner ||
      this == HDCInternalRole.superAdmin ||
      this == HDCInternalRole.admin;

  bool get canModerateCommunity => true;
}

HDCInternalRole? parseHDCInternalRole(Object? value) {
  final code = '$value'.trim().toLowerCase().replaceAll('-', '_');
  final normalized = code == 'superadmin' ? 'super_admin' : code;
  for (final role in HDCInternalRole.values) {
    if (role.code == normalized) return role;
  }
  return null;
}

class AccountIdentity {
  final String id;
  final String? publicMemberId;
  final String? email;
  final String? phone;
  final String displayName;
  final HDCAccountStatus status;
  final Set<HDCPlatformRole> platformRoles;
  final Set<HDCInternalRole> internalRoles;
  final bool legalAcceptanceRequired;
  final String legalVersion;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AccountIdentity({
    required this.id,
    required this.displayName,
    required this.status,
    required this.platformRoles,
    this.internalRoles = const <HDCInternalRole>{},
    this.legalAcceptanceRequired = false,
    this.legalVersion = '',
    required this.createdAt,
    required this.updatedAt,
    this.email,
    this.phone,
    this.publicMemberId,
  });

  bool get isActive => status == HDCAccountStatus.active;

  bool hasPlatformRole(HDCPlatformRole role) => platformRoles.contains(role);

  bool hasInternalRole(HDCInternalRole role) => internalRoles.contains(role);

  bool get canApprovePlatformRoles =>
      internalRoles.any((role) => role.canApprovePlatformRoles);

  bool get canManageInternalStructure =>
      internalRoles.any((role) => role.canManageInternalStructure);

  bool get hasPrivilegedRole =>
      internalRoles.any((role) => role.hasPrivilegedResourceAccess);

  AccountIdentity copyWith({
    String? publicMemberId,
    String? email,
    String? phone,
    String? displayName,
    HDCAccountStatus? status,
    Set<HDCPlatformRole>? platformRoles,
    Set<HDCInternalRole>? internalRoles,
    bool? legalAcceptanceRequired,
    String? legalVersion,
    DateTime? updatedAt,
  }) {
    return AccountIdentity(
      id: id,
      publicMemberId: publicMemberId ?? this.publicMemberId,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      displayName: displayName ?? this.displayName,
      status: status ?? this.status,
      platformRoles: platformRoles ?? this.platformRoles,
      internalRoles: internalRoles ?? this.internalRoles,
      legalAcceptanceRequired:
          legalAcceptanceRequired ?? this.legalAcceptanceRequired,
      legalVersion: legalVersion ?? this.legalVersion,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
