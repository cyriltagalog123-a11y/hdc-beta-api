import '../models/user_role.dart';
import 'user_role_repository.dart';

class MemoryUserRoleRepository
    implements UserRoleRepository {

  final List<UserRole> _assignments = [];

  @override
  List<UserRole> getAssignments() =>
      _assignments;

  @override
  List<UserRole> forUser(
    String userId,
  ) {
    return _assignments
        .where(
          (r) =>
              r.userAccountId ==
              userId,
        )
        .toList();
  }

  @override
  Future<void> assignRole(
    UserRole assignment,
  ) async {

    _assignments.add(
      assignment,
    );
  }

  @override
  Future<void> removeRole(
    String assignmentId,
  ) async {

    _assignments.removeWhere(
      (a) =>
          a.id ==
          assignmentId,
    );
  }
}