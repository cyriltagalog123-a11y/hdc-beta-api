enum QRIdentityType {
  asset,
  store,
  technician,
  seller,
  supplier,
  inventory,
}

class QRIdentity {
  final String id;

  final QRIdentityType type;

  final String referenceId;

  final DateTime createdAt;

  const QRIdentity({
    required this.id,
    required this.type,
    required this.referenceId,
    required this.createdAt,
  });

  String get qrData {
    return "HDC|${type.name}|$referenceId";
  }
}