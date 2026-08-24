// Legacy unscoped prototype retained for source compatibility. It is not an
// HDC authorization source. New code must use HDCPlatformRole or
// HDCInternalRole from account_identity.dart.
class Role {

  final String id;

  final String name;

  final String description;

  const Role({

    required this.id,

    required this.name,

    required this.description,
  });
}
