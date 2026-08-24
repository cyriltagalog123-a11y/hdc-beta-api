class Organization {
  final String id;

  final String name;

  final String code;

  final String ownerName;

  final String email;

  final String phone;

  final bool active;

  const Organization({
    required this.id,
    required this.name,
    required this.code,
    required this.ownerName,
    required this.email,
    required this.phone,
    required this.active,
  });
}