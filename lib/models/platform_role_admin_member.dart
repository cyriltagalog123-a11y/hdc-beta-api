import 'account_identity.dart';

class PlatformRoleAdminMember {
  final String id;
  final String publicMemberId;
  final String displayName;
  final String email;
  final String status;
  final Set<HDCPlatformRole> platformRoles;

  const PlatformRoleAdminMember({
    required this.id,
    required this.publicMemberId,
    required this.displayName,
    required this.email,
    required this.status,
    required this.platformRoles,
  });

  factory PlatformRoleAdminMember.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['platformRoles'];
    final roles = <HDCPlatformRole>{};
    if (rawRoles is List) {
      for (final rawRole in rawRoles) {
        final role = parseHDCPlatformRole(rawRole);
        if (role != null) roles.add(role);
      }
    }
    return PlatformRoleAdminMember(
      id: '${json['id'] ?? ''}',
      publicMemberId: '${json['publicMemberId'] ?? ''}',
      displayName: '${json['displayName'] ?? ''}',
      email: '${json['email'] ?? ''}',
      status: '${json['status'] ?? ''}',
      platformRoles: Set<HDCPlatformRole>.unmodifiable(roles),
    );
  }

  PlatformRoleAdminMember copyWithRoles(Set<HDCPlatformRole> roles) {
    return PlatformRoleAdminMember(
      id: id,
      publicMemberId: publicMemberId,
      displayName: displayName,
      email: email,
      status: status,
      platformRoles: Set<HDCPlatformRole>.unmodifiable(roles),
    );
  }
}
