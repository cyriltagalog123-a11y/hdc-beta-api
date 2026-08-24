import 'package:flutter/material.dart';

import '../models/qr_identity.dart';
import '../repositories/qr_identity_repository.dart';

class QRIdentityProvider extends ChangeNotifier {
  final QRIdentityRepository _repository =
      QRIdentityRepository();

  QRIdentity? latest;

  void create({
    required QRIdentityType type,
    required String referenceId,
  }) {
    latest = _repository.createIdentity(
      type: type,
      referenceId: referenceId,
    );

    notifyListeners();
  }
}