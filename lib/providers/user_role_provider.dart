import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../repositories/user_role_repository.dart';

class UserRoleProvider
    extends ChangeNotifier {

  final UserRoleRepository repository;

  UserRoleProvider({
    required this.repository,
  });

  List<UserRole> get assignments =>
      repository.getAssignments();

  List<UserRole> forUser(
    String id,
  ) {
    return repository.forUser(id);
  }

  Future<void> assignRole(
    UserRole assignment,
  ) async {

    await repository.assignRole(
      assignment,
    );

    notifyListeners();
  }

  Future<void> removeRole(
    String id,
  ) async {

    await repository.removeRole(id);

    notifyListeners();
  }
}