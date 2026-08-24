import '../models/employee.dart';
import 'employee_repository.dart';

class MemoryEmployeeRepository
    implements EmployeeRepository {

  final List<Employee> _employees = [];

  @override
  List<Employee> getEmployees() {
    return _employees;
  }

  @override
  List<Employee> forDepartment(
    String departmentId,
  ) {
    return _employees
        .where(
          (e) =>
              e.departmentId ==
              departmentId,
        )
        .toList();
  }

  @override
  Future<void> registerEmployee(
    Employee employee,
  ) async {
    _employees.add(employee);
  }

  @override
  Future<void> updateEmployee(
    Employee employee,
  ) async {

    final index =
        _employees.indexWhere(
      (e) => e.id == employee.id,
    );

    if (index != -1) {
      _employees[index] = employee;
    }
  }

  @override
  Future<void> deleteEmployee(
    String employeeId,
  ) async {

    _employees.removeWhere(
      (e) =>
          e.id == employeeId,
    );
  }
}