import '../models/user_role.dart';

abstract class UserRoleRepository {

  List<UserRole> getAssignments();

  List<UserRole> forUser(
    String userId,
  );

  Future<void> assignRole(
    UserRole assignment,
  );

  Future<void> removeRole(
    String assignmentId,
  );
}