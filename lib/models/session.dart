class Session {

  final String userAccountId;

  final DateTime loginTime;

  final bool authenticated;

  const Session({

    required this.userAccountId,

    required this.loginTime,

    required this.authenticated,
  });

  Session copyWith({

    String? userAccountId,

    DateTime? loginTime,

    bool? authenticated,

  }) {

    return Session(

      userAccountId:
          userAccountId ??
          this.userAccountId,

      loginTime:
          loginTime ??
          this.loginTime,

      authenticated:
          authenticated ??
          this.authenticated,
    );
  }
}