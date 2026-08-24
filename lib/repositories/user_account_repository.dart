import '../models/user_account.dart';

abstract class UserAccountRepository {

  List<UserAccount> getAccounts();

  UserAccount? byEmployee(
    String employeeId,
  );

  Future<void> registerAccount(
    UserAccount account,
  );

  Future<void> updateAccount(
    UserAccount account,
  );

  Future<void> deleteAccount(
    String id,
  );
}