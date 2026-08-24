import '../models/department.dart';
import 'department_repository.dart';

class MemoryDepartmentRepository
    implements DepartmentRepository {

  final List<Department> _departments = [];

  @override
  List<Department> getDepartments() =>
      _departments;

  @override
  List<Department> forStore(
    String storeId,
  ) {
    return _departments
        .where(
          (d) => d.storeId == storeId,
        )
        .toList();
  }

  @override
  Future<void> registerDepartment(
    Department department,
  ) async {
    _departments.add(department);
  }

  @override
  Future<void> updateDepartment(
    Department department,
  ) async {

    final index =
        _departments.indexWhere(
      (d) => d.id == department.id,
    );

    if (index != -1) {
      _departments[index] =
          department;
    }
  }

  @override
  Future<void> deleteDepartment(
    String departmentId,
  ) async {
    _departments.removeWhere(
      (d) => d.id == departmentId,
    );
  }
}