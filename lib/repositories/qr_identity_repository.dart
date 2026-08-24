import '../models/qr_identity.dart';

class QRIdentityRepository {
  QRIdentity createIdentity({
    required QRIdentityType type,
    required String referenceId,
  }) {
    return QRIdentity(
      id: DateTime.now()
          .millisecondsSinceEpoch
          .toString(),
      type: type,
      referenceId: referenceId,
      createdAt: DateTime.now(),
    );
  }
}