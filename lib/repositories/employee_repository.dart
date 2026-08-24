import '../models/employee.dart';

abstract class EmployeeRepository {

  List<Employee> getEmployees();

  List<Employee> forDepartment(
    String departmentId,
  );

  Future<void> registerEmployee(
    Employee employee,
  );

  Future<void> updateEmployee(
    Employee employee,
  );

  Future<void> deleteEmployee(
    String employeeId,
  );
}