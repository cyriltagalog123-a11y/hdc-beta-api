class Employee {

  final String id;

  final String organizationId;

  final String brandId;

  final String regionId;

  final String storeId;

  final String departmentId;

  final String employeeNumber;

  final String firstName;

  final String lastName;

  final String email;

  final String phone;

  final String position;

  final bool active;

  const Employee({

    required this.id,

    required this.organizationId,

    required this.brandId,

    required this.regionId,

    required this.storeId,

    required this.departmentId,

    required this.employeeNumber,

    required this.firstName,

    required this.lastName,

    required this.email,

    required this.phone,

    required this.position,

    required this.active,
  });

  String get fullName =>
      "$firstName $lastName";
}