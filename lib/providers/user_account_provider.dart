import 'package:flutter/material.dart';

import '../models/user_account.dart';
import '../repositories/user_account_repository.dart';

class UserAccountProvider
    extends ChangeNotifier {

  final UserAccountRepository repository;

  UserAccountProvider({
    required this.repository,
  });

  List<UserAccount> get accounts =>
      repository.getAccounts();

  UserAccount? byEmployee(
    String employeeId,
  ) {
    return repository.byEmployee(
      employeeId,
    );
  }

  Future<void> registerAccount(
    UserAccount account,
  ) async {

    await repository.registerAccount(
      account,
    );

    notifyListeners();
  }

  Future<void> updateAccount(
    UserAccount account,
  ) async {

    await repository.updateAccount(
      account,
    );

    notifyListeners();
  }

  Future<void> deleteAccount(
    String id,
  ) async {

    await repository.deleteAccount(id);

    notifyListeners();
  }
}