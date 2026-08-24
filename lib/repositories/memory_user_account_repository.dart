import '../models/user_account.dart';
import 'user_account_repository.dart';

class MemoryUserAccountRepository
    implements UserAccountRepository {

  final List<UserAccount> _accounts = [];

  @override
  List<UserAccount> getAccounts() =>
      _accounts;

  @override
  UserAccount? byEmployee(
    String employeeId,
  ) {

    try {
      return _accounts.firstWhere(
        (a) => a.employeeId == employeeId,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> registerAccount(
    UserAccount account,
  ) async {
    _accounts.add(account);
  }

  @override
  Future<void> updateAccount(
    UserAccount account,
  ) async {

    final index =
        _accounts.indexWhere(
      (a) => a.id == account.id,
    );

    if (index != -1) {
      _accounts[index] = account;
    }
  }

  @override
  Future<void> deleteAccount(
    String id,
  ) async {
    _accounts.removeWhere(
      (a) => a.id == id,
    );
  }
}