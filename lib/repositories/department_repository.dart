import '../models/department.dart';

abstract class DepartmentRepository {

  List<Department> getDepartments();

  List<Department> forStore(
    String storeId,
  );

  Future<void> registerDepartment(
    Department department,
  );

  Future<void> updateDepartment(
    Department department,
  );

  Future<void> deleteDepartment(
    String departmentId,
  );
}