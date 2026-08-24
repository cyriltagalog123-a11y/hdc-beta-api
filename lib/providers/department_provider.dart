import 'package:flutter/material.dart';

import '../models/department.dart';
import '../repositories/department_repository.dart';

class DepartmentProvider
    extends ChangeNotifier {

  final DepartmentRepository repository;

  DepartmentProvider({
    required this.repository,
  });

  List<Department> get departments =>
      repository.getDepartments();

  List<Department> forStore(
    String storeId,
  ) {
    return repository.forStore(
      storeId,
    );
  }

  Future<void> registerDepartment(
    Department department,
  ) async {

    await repository.registerDepartment(
      department,
    );

    notifyListeners();
  }

  Future<void> updateDepartment(
    Department department,
  ) async {

    await repository.updateDepartment(
      department,
    );

    notifyListeners();
  }

  Future<void> deleteDepartment(
    String id,
  ) async {

    await repository.deleteDepartment(id);

    notifyListeners();
  }
}