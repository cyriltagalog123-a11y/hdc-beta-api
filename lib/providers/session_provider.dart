import 'package:flutter/material.dart';

import '../models/session.dart';

class SessionProvider extends ChangeNotifier {

  Session? _session;

  Session? get session => _session;

  bool get authenticated =>
      _session?.authenticated ?? false;

  String? get currentUser =>
      _session?.userAccountId;

  void login(
    String userId,
  ) {

    _session = Session(

      userAccountId: userId,

      loginTime: DateTime.now(),

      authenticated: true,
    );

    notifyListeners();
  }

  void logout() {

    _session = null;

    notifyListeners();
  }
}