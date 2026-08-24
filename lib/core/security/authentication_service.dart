import '../../models/user_account.dart';

class AuthenticationService {

  UserAccount? login({

    required List<UserAccount> accounts,

    required String username,

    required String email,

  }) {

    try {

      return accounts.firstWhere(

        (a) =>

            a.username == username &&

            a.email == email &&

            a.enabled,
      );

    } catch (_) {

      return null;
    }
  }
}