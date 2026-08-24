import 'package:flutter/material.dart';

import '../models/employee.dart';
import '../repositories/employee_repository.dart';

class EmployeeProvider
    extends ChangeNotifier {

  final EmployeeRepository repository;

  EmployeeProvider({
    required this.repository,
  });

  List<Employee> get employees =>
      repository.getEmployees();

  List<Employee> forDepartment(
    String departmentId,
  ) {
    return repository.forDepartment(
      departmentId,
    );
  }

  Future<void> registerEmployee(
    Employee employee,
  ) async {

    await repository.registerEmployee(
      employee,
    );

    notifyListeners();
  }

  Future<void> updateEmployee(
    Employee employee,
  ) async {

    await repository.updateEmployee(
      employee,
    );

    notifyListeners();
  }

  Future<void> deleteEmployee(
    String id,
  ) async {

    await repository.deleteEmployee(id);

    notifyListeners();
  }
}