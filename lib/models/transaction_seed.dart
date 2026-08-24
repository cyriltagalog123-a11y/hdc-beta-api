enum TransactionSeedStatus {
  readyForWorkspace,
  consumed,
  cancelled,
}

class TransactionSeed {
  final String id;
  final String requestId;
  final String proposalId;
  final String customerId;
  final String technicianId;
  final double acceptedEstimate;
  final TransactionSeedStatus status;
  final DateTime createdAt;

  const TransactionSeed({
    required this.id,
    required this.requestId,
    required this.proposalId,
    required this.customerId,
    required this.technicianId,
    required this.acceptedEstimate,
    required this.status,
    required this.createdAt,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'requestId': requestId,
        'proposalId': proposalId,
        'customerId': customerId,
        'technicianId': technicianId,
        'acceptedEstimate': acceptedEstimate,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TransactionSeed.fromJson(Map<String, dynamic> json) {
    return TransactionSeed(
      id: json['id'] as String,
      requestId: json['requestId'] as String,
      proposalId: json['proposalId'] as String,
      customerId: json['customerId'] as String,
      technicianId: json['technicianId'] as String,
      acceptedEstimate: (json['acceptedEstimate'] as num).toDouble(),
      status: TransactionSeedStatus.values.byName(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  TransactionSeed copyWith({
    TransactionSeedStatus? status,
  }) {
    return TransactionSeed(
      id: id,
      requestId: requestId,
      proposalId: proposalId,
      customerId: customerId,
      technicianId: technicianId,
      acceptedEstimate: acceptedEstimate,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}
