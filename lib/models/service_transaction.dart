enum ServiceTransactionStatus {
  created,
  confirmed,
  scheduled,
  technicianEnRoute,
  arrived,
  inProgress,
  awaitingCustomerConfirmation,
  completed,
  cancelled,
  disputed,
}

extension ServiceTransactionStatusDetails on ServiceTransactionStatus {
  String get label {
    switch (this) {
      case ServiceTransactionStatus.created:
        return 'Created';
      case ServiceTransactionStatus.confirmed:
        return 'Confirmed';
      case ServiceTransactionStatus.scheduled:
        return 'Scheduled';
      case ServiceTransactionStatus.technicianEnRoute:
        return 'Technician En Route';
      case ServiceTransactionStatus.arrived:
        return 'Technician Arrived';
      case ServiceTransactionStatus.inProgress:
        return 'In Progress';
      case ServiceTransactionStatus.awaitingCustomerConfirmation:
        return 'Awaiting Customer Confirmation';
      case ServiceTransactionStatus.completed:
        return 'Completed';
      case ServiceTransactionStatus.cancelled:
        return 'Cancelled';
      case ServiceTransactionStatus.disputed:
        return 'Disputed';
    }
  }

  bool get isTerminal {
    return this == ServiceTransactionStatus.completed ||
        this == ServiceTransactionStatus.cancelled;
  }

  bool get isActive {
    return !isTerminal && this != ServiceTransactionStatus.disputed;
  }

  bool get allowsPrivateMessaging {
    return this != ServiceTransactionStatus.cancelled;
  }
}

enum ServiceTransactionParticipantRole {
  customer,
  technician,
}

extension ServiceTransactionParticipantRoleDetails
    on ServiceTransactionParticipantRole {
  String get label {
    switch (this) {
      case ServiceTransactionParticipantRole.customer:
        return 'Customer';
      case ServiceTransactionParticipantRole.technician:
        return 'Technician';
    }
  }
}

enum ServiceTransactionActivityType {
  transactionCreated,
  transactionConfirmed,
  statusChanged,
  disputeOpened,
  cancelled,
  completed,
}

class AcceptedServiceTerms {
  final double serviceFee;
  final double? estimatedPartsCost;
  final double totalEstimate;
  final DateTime earliestArrival;
  final int estimatedDurationMinutes;
  final int warrantyDays;
  final String diagnosis;
  final String repairApproach;
  final String professionalNotes;

  const AcceptedServiceTerms({
    required this.serviceFee,
    required this.totalEstimate,
    required this.earliestArrival,
    required this.estimatedDurationMinutes,
    required this.warrantyDays,
    required this.diagnosis,
    required this.repairApproach,
    required this.professionalNotes,
    this.estimatedPartsCost,
  });

  Map<String, Object?> toJson() {
    return {
      'serviceFee': serviceFee,
      'estimatedPartsCost': estimatedPartsCost,
      'totalEstimate': totalEstimate,
      'earliestArrival': earliestArrival.toIso8601String(),
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'warrantyDays': warrantyDays,
      'diagnosis': diagnosis,
      'repairApproach': repairApproach,
      'professionalNotes': professionalNotes,
    };
  }

  factory AcceptedServiceTerms.fromJson(Map<String, dynamic> json) {
    return AcceptedServiceTerms(
      serviceFee: (json['serviceFee'] as num).toDouble(),
      estimatedPartsCost:
          (json['estimatedPartsCost'] as num?)?.toDouble(),
      totalEstimate: (json['totalEstimate'] as num).toDouble(),
      earliestArrival: DateTime.parse(json['earliestArrival'] as String),
      estimatedDurationMinutes:
          (json['estimatedDurationMinutes'] as num).toInt(),
      warrantyDays: (json['warrantyDays'] as num).toInt(),
      diagnosis: json['diagnosis'] as String? ?? '',
      repairApproach: json['repairApproach'] as String? ?? '',
      professionalNotes: json['professionalNotes'] as String? ?? '',
    );
  }
}

class ServiceTransactionActivity {
  final String id;
  final ServiceTransactionActivityType type;
  final String message;
  final DateTime createdAt;
  final ServiceTransactionStatus? fromStatus;
  final ServiceTransactionStatus? toStatus;
  final String? actorId;

  const ServiceTransactionActivity({
    required this.id,
    required this.type,
    required this.message,
    required this.createdAt,
    this.fromStatus,
    this.toStatus,
    this.actorId,
  });

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'type': type.name,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'fromStatus': fromStatus?.name,
      'toStatus': toStatus?.name,
      'actorId': actorId,
    };
  }

  factory ServiceTransactionActivity.fromJson(
    Map<String, dynamic> json,
  ) {
    final fromStatusName = json['fromStatus'] as String?;
    final toStatusName = json['toStatus'] as String?;

    return ServiceTransactionActivity(
      id: json['id'] as String,
      type: ServiceTransactionActivityType.values.byName(
        json['type'] as String,
      ),
      message: json['message'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      fromStatus: fromStatusName == null
          ? null
          : ServiceTransactionStatus.values.byName(fromStatusName),
      toStatus: toStatusName == null
          ? null
          : ServiceTransactionStatus.values.byName(toStatusName),
      actorId: json['actorId'] as String?,
    );
  }
}

class ServiceTransaction {
  final String id;
  final String seedId;
  final String requestId;
  final String proposalId;
  final String customerId;
  final String customerName;
  final String technicianId;
  final String technicianName;
  final String requestTitle;
  final String categoryName;
  final String serviceLocation;
  final ServiceTransactionStatus status;
  final AcceptedServiceTerms acceptedTerms;
  final List<ServiceTransactionActivity> activity;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ServiceTransaction({
    required this.id,
    required this.seedId,
    required this.requestId,
    required this.proposalId,
    required this.customerId,
    required this.customerName,
    required this.technicianId,
    required this.technicianName,
    required this.requestTitle,
    required this.categoryName,
    required this.serviceLocation,
    required this.status,
    required this.acceptedTerms,
    required this.activity,
    required this.createdAt,
    required this.updatedAt,
  });

  bool isParticipant(String userId) {
    return customerId == userId || technicianId == userId;
  }

  ServiceTransactionParticipantRole? roleFor(String userId) {
    if (customerId == userId) {
      return ServiceTransactionParticipantRole.customer;
    }
    if (technicianId == userId) {
      return ServiceTransactionParticipantRole.technician;
    }
    return null;
  }

  bool get allowsPrivateMessaging => status.allowsPrivateMessaging;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'seedId': seedId,
      'requestId': requestId,
      'proposalId': proposalId,
      'customerId': customerId,
      'customerName': customerName,
      'technicianId': technicianId,
      'technicianName': technicianName,
      'requestTitle': requestTitle,
      'categoryName': categoryName,
      'serviceLocation': serviceLocation,
      'status': status.name,
      'acceptedTerms': acceptedTerms.toJson(),
      'activity': activity.map((entry) => entry.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ServiceTransaction.fromJson(Map<String, dynamic> json) {
    final customerId = json['customerId'] as String;
    final technicianId = json['technicianId'] as String;

    return ServiceTransaction(
      id: json['id'] as String,
      seedId: json['seedId'] as String,
      requestId: json['requestId'] as String,
      proposalId: json['proposalId'] as String,
      customerId: customerId,
      customerName: json['customerName'] as String? ?? customerId,
      technicianId: technicianId,
      technicianName: json['technicianName'] as String? ?? technicianId,
      requestTitle: json['requestTitle'] as String? ?? '',
      categoryName: json['categoryName'] as String? ?? '',
      serviceLocation: json['serviceLocation'] as String? ?? '',
      status: ServiceTransactionStatus.values.byName(
        json['status'] as String,
      ),
      acceptedTerms: AcceptedServiceTerms.fromJson(
        Map<String, dynamic>.from(json['acceptedTerms'] as Map),
      ),
      activity: (json['activity'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => ServiceTransactionActivity.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  ServiceTransaction copyWith({
    ServiceTransactionStatus? status,
    List<ServiceTransactionActivity>? activity,
    DateTime? updatedAt,
  }) {
    return ServiceTransaction(
      id: id,
      seedId: seedId,
      requestId: requestId,
      proposalId: proposalId,
      customerId: customerId,
      customerName: customerName,
      technicianId: technicianId,
      technicianName: technicianName,
      requestTitle: requestTitle,
      categoryName: categoryName,
      serviceLocation: serviceLocation,
      status: status ?? this.status,
      acceptedTerms: acceptedTerms,
      activity: activity ?? this.activity,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
