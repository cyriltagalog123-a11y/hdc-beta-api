enum ProposalStatus {
  draft,
  submitted,
  viewed,
  shortlisted,
  accepted,
  declined,
  expired,
  withdrawn,
}

enum ProposalPartsArrangement {
  none,
  customerSupplies,
  technicianSupplies,
}

enum ProposalWarrantyType {
  none,
  sevenDays,
  thirtyDays,
  ninetyDays,
  custom,
}

extension ProposalStatusDetails on ProposalStatus {
  String get label {
    switch (this) {
      case ProposalStatus.draft:
        return 'Draft';
      case ProposalStatus.submitted:
        return 'Submitted';
      case ProposalStatus.viewed:
        return 'Viewed';
      case ProposalStatus.shortlisted:
        return 'Shortlisted';
      case ProposalStatus.accepted:
        return 'Accepted';
      case ProposalStatus.declined:
        return 'Declined';
      case ProposalStatus.expired:
        return 'Expired';
      case ProposalStatus.withdrawn:
        return 'Withdrawn';
    }
  }

  bool get canEdit => this == ProposalStatus.draft;

  bool get canWithdraw {
    return this == ProposalStatus.submitted ||
        this == ProposalStatus.viewed ||
        this == ProposalStatus.shortlisted;
  }

  bool get isActive {
    return this == ProposalStatus.submitted ||
        this == ProposalStatus.viewed ||
        this == ProposalStatus.shortlisted;
  }
}

extension ProposalPartsArrangementDetails on ProposalPartsArrangement {
  String get label {
    switch (this) {
      case ProposalPartsArrangement.none:
        return 'No parts required';
      case ProposalPartsArrangement.customerSupplies:
        return 'Customer supplies parts';
      case ProposalPartsArrangement.technicianSupplies:
        return 'Technician supplies parts';
    }
  }
}

extension ProposalWarrantyTypeDetails on ProposalWarrantyType {
  String get label {
    switch (this) {
      case ProposalWarrantyType.none:
        return 'No warranty';
      case ProposalWarrantyType.sevenDays:
        return '7 days';
      case ProposalWarrantyType.thirtyDays:
        return '30 days';
      case ProposalWarrantyType.ninetyDays:
        return '90 days';
      case ProposalWarrantyType.custom:
        return 'Custom warranty';
    }
  }

  int? get fixedDays {
    switch (this) {
      case ProposalWarrantyType.none:
        return 0;
      case ProposalWarrantyType.sevenDays:
        return 7;
      case ProposalWarrantyType.thirtyDays:
        return 30;
      case ProposalWarrantyType.ninetyDays:
        return 90;
      case ProposalWarrantyType.custom:
        return null;
    }
  }
}

class TechnicianReputationSnapshot {
  final String technicianName;
  final bool isVerified;
  final double rating;
  final int completedJobs;
  final int averageResponseMinutes;
  final double successRate;
  final int memberSinceYear;

  const TechnicianReputationSnapshot({
    required this.technicianName,
    required this.isVerified,
    required this.rating,
    required this.completedJobs,
    required this.averageResponseMinutes,
    required this.successRate,
    required this.memberSinceYear,
  });

  Map<String, Object?> toJson() {
    return {
      'technicianName': technicianName,
      'isVerified': isVerified,
      'rating': rating,
      'completedJobs': completedJobs,
      'averageResponseMinutes': averageResponseMinutes,
      'successRate': successRate,
      'memberSinceYear': memberSinceYear,
    };
  }

  factory TechnicianReputationSnapshot.fromJson(
    Map<String, dynamic> json,
  ) {
    return TechnicianReputationSnapshot(
      technicianName: json['technicianName'] as String,
      isVerified: json['isVerified'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      completedJobs: (json['completedJobs'] as num?)?.toInt() ?? 0,
      averageResponseMinutes:
          (json['averageResponseMinutes'] as num?)?.toInt() ?? 0,
      successRate:
          (json['successRate'] as num?)?.toDouble() ?? 0,
      memberSinceYear:
          (json['memberSinceYear'] as num?)?.toInt() ??
              DateTime.now().year,
    );
  }
}

class Proposal {
  final String id;
  final String requestId;
  final String technicianId;
  final ProposalStatus status;
  final double serviceFee;
  final ProposalPartsArrangement partsArrangement;
  final double? estimatedPartsCost;
  final DateTime earliestArrival;
  final int estimatedDurationMinutes;
  final ProposalWarrantyType warrantyType;
  final int? customWarrantyDays;
  final String diagnosis;
  final String repairApproach;
  final String professionalNotes;
  final TechnicianReputationSnapshot reputation;
  final int qualityScore;
  final List<String> attachmentIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? submittedAt;
  final DateTime? viewedAt;
  final DateTime? shortlistedAt;
  final DateTime? acceptedAt;
  final DateTime? declinedAt;
  final DateTime? expiredAt;
  final DateTime? withdrawnAt;

  const Proposal({
    required this.id,
    required this.requestId,
    required this.technicianId,
    required this.status,
    required this.serviceFee,
    required this.partsArrangement,
    required this.earliestArrival,
    required this.estimatedDurationMinutes,
    required this.warrantyType,
    required this.diagnosis,
    required this.repairApproach,
    required this.professionalNotes,
    required this.reputation,
    required this.qualityScore,
    required this.attachmentIds,
    required this.createdAt,
    required this.updatedAt,
    this.estimatedPartsCost,
    this.customWarrantyDays,
    this.submittedAt,
    this.viewedAt,
    this.shortlistedAt,
    this.acceptedAt,
    this.declinedAt,
    this.expiredAt,
    this.withdrawnAt,
  });

  double get estimatedTotal =>
      serviceFee + (estimatedPartsCost ?? 0);

  int get warrantyDays {
    return warrantyType.fixedDays ??
        customWarrantyDays ??
        0;
  }

  bool get hasPartsCost =>
      partsArrangement ==
          ProposalPartsArrangement.technicianSupplies &&
      estimatedPartsCost != null &&
      estimatedPartsCost! > 0;

  DateTime get latestLifecycleAt {
    final values = <DateTime>[
      createdAt,
      updatedAt,
      ?submittedAt,
      ?viewedAt,
      ?shortlistedAt,
      ?acceptedAt,
      ?declinedAt,
      ?expiredAt,
      ?withdrawnAt,
    ];

    values.sort();

    return values.last;
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'requestId': requestId,
      'technicianId': technicianId,
      'status': status.name,
      'serviceFee': serviceFee,
      'partsArrangement': partsArrangement.name,
      'estimatedPartsCost': estimatedPartsCost,
      'earliestArrival':
          earliestArrival.toIso8601String(),
      'estimatedDurationMinutes':
          estimatedDurationMinutes,
      'warrantyType': warrantyType.name,
      'customWarrantyDays': customWarrantyDays,
      'diagnosis': diagnosis,
      'repairApproach': repairApproach,
      'professionalNotes': professionalNotes,
      'reputation': reputation.toJson(),
      'qualityScore': qualityScore,
      'attachmentIds': attachmentIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'submittedAt':
          submittedAt?.toIso8601String(),
      'viewedAt':
          viewedAt?.toIso8601String(),
      'shortlistedAt':
          shortlistedAt?.toIso8601String(),
      'acceptedAt':
          acceptedAt?.toIso8601String(),
      'declinedAt':
          declinedAt?.toIso8601String(),
      'expiredAt':
          expiredAt?.toIso8601String(),
      'withdrawnAt':
          withdrawnAt?.toIso8601String(),
    };
  }

  factory Proposal.fromJson(
    Map<String, dynamic> json,
  ) {
    return Proposal(
      id: json['id'] as String,
      requestId: json['requestId'] as String,
      technicianId:
          json['technicianId'] as String,
      status: ProposalStatus.values.byName(
        json['status'] as String,
      ),
      serviceFee:
          (json['serviceFee'] as num).toDouble(),
      partsArrangement:
          ProposalPartsArrangement.values.byName(
        json['partsArrangement'] as String,
      ),
      estimatedPartsCost:
          (json['estimatedPartsCost'] as num?)
              ?.toDouble(),
      earliestArrival: DateTime.parse(
        json['earliestArrival'] as String,
      ),
      estimatedDurationMinutes:
          (json['estimatedDurationMinutes'] as num)
              .toInt(),
      warrantyType:
          ProposalWarrantyType.values.byName(
        json['warrantyType'] as String,
      ),
      customWarrantyDays:
          (json['customWarrantyDays'] as num?)
              ?.toInt(),
      diagnosis:
          json['diagnosis'] as String? ?? '',
      repairApproach:
          json['repairApproach'] as String? ?? '',
      professionalNotes:
          json['professionalNotes'] as String? ?? '',
      reputation:
          TechnicianReputationSnapshot.fromJson(
        Map<String, dynamic>.from(
          json['reputation'] as Map,
        ),
      ),
      qualityScore:
          (json['qualityScore'] as num?)
                  ?.toInt() ??
              0,
      attachmentIds:
          (json['attachmentIds'] as List?)
                  ?.whereType<String>()
                  .toList(
                    growable: false,
                  ) ??
              const [],
      createdAt: DateTime.parse(
        json['createdAt'] as String,
      ),
      updatedAt: DateTime.parse(
        json['updatedAt'] as String,
      ),
      submittedAt:
          json['submittedAt'] == null
              ? null
              : DateTime.parse(
                  json['submittedAt'] as String,
                ),
      viewedAt:
          json['viewedAt'] == null
              ? _legacyLifecycleTime(
                  json,
                  const {
                    'viewed',
                    'shortlisted',
                    'accepted',
                  },
                )
              : DateTime.parse(
                  json['viewedAt'] as String,
                ),
      shortlistedAt:
          json['shortlistedAt'] == null
              ? _legacyLifecycleTime(
                  json,
                  const {
                    'shortlisted',
                    'accepted',
                  },
                )
              : DateTime.parse(
                  json['shortlistedAt'] as String,
                ),
      acceptedAt:
          json['acceptedAt'] == null
              ? _legacyLifecycleTime(
                  json,
                  const {'accepted'},
                )
              : DateTime.parse(
                  json['acceptedAt'] as String,
                ),
      declinedAt:
          json['declinedAt'] == null
              ? _legacyLifecycleTime(
                  json,
                  const {'declined'},
                )
              : DateTime.parse(
                  json['declinedAt'] as String,
                ),
      expiredAt:
          json['expiredAt'] == null
              ? _legacyLifecycleTime(
                  json,
                  const {'expired'},
                )
              : DateTime.parse(
                  json['expiredAt'] as String,
                ),
      withdrawnAt:
          json['withdrawnAt'] == null
              ? _legacyLifecycleTime(
                  json,
                  const {'withdrawn'},
                )
              : DateTime.parse(
                  json['withdrawnAt'] as String,
                ),
    );
  }

  static DateTime? _legacyLifecycleTime(
    Map<String, dynamic> json,
    Set<String> statuses,
  ) {
    final status =
        json['status'] as String?;

    if (status == null ||
        !statuses.contains(status)) {
      return null;
    }

    final updatedAt =
        json['updatedAt'] as String?;

    if (updatedAt == null) {
      return null;
    }

    return DateTime.tryParse(updatedAt);
  }

  Proposal copyWith({
    ProposalStatus? status,
    double? serviceFee,
    ProposalPartsArrangement? partsArrangement,
    double? estimatedPartsCost,
    bool clearEstimatedPartsCost = false,
    DateTime? earliestArrival,
    int? estimatedDurationMinutes,
    ProposalWarrantyType? warrantyType,
    int? customWarrantyDays,
    bool clearCustomWarrantyDays = false,
    String? diagnosis,
    String? repairApproach,
    String? professionalNotes,
    TechnicianReputationSnapshot? reputation,
    int? qualityScore,
    List<String>? attachmentIds,
    DateTime? updatedAt,
    DateTime? submittedAt,
    bool clearSubmittedAt = false,
    DateTime? viewedAt,
    bool clearViewedAt = false,
    DateTime? shortlistedAt,
    bool clearShortlistedAt = false,
    DateTime? acceptedAt,
    bool clearAcceptedAt = false,
    DateTime? declinedAt,
    bool clearDeclinedAt = false,
    DateTime? expiredAt,
    bool clearExpiredAt = false,
    DateTime? withdrawnAt,
    bool clearWithdrawnAt = false,
  }) {
    return Proposal(
      id: id,
      requestId: requestId,
      technicianId: technicianId,
      status: status ?? this.status,
      serviceFee: serviceFee ?? this.serviceFee,
      partsArrangement:
          partsArrangement ??
              this.partsArrangement,
      estimatedPartsCost:
          clearEstimatedPartsCost
              ? null
              : estimatedPartsCost ??
                  this.estimatedPartsCost,
      earliestArrival:
          earliestArrival ??
              this.earliestArrival,
      estimatedDurationMinutes:
          estimatedDurationMinutes ??
              this.estimatedDurationMinutes,
      warrantyType:
          warrantyType ??
              this.warrantyType,
      customWarrantyDays:
          clearCustomWarrantyDays
              ? null
              : customWarrantyDays ??
                  this.customWarrantyDays,
      diagnosis:
          diagnosis ??
              this.diagnosis,
      repairApproach:
          repairApproach ??
              this.repairApproach,
      professionalNotes:
          professionalNotes ??
              this.professionalNotes,
      reputation:
          reputation ??
              this.reputation,
      qualityScore:
          qualityScore ??
              this.qualityScore,
      attachmentIds:
          attachmentIds ??
              this.attachmentIds,
      createdAt: createdAt,
      updatedAt:
          updatedAt ??
              DateTime.now(),
      submittedAt:
          clearSubmittedAt
              ? null
              : submittedAt ??
                  this.submittedAt,
      viewedAt:
          clearViewedAt
              ? null
              : viewedAt ??
                  this.viewedAt,
      shortlistedAt:
          clearShortlistedAt
              ? null
              : shortlistedAt ??
                  this.shortlistedAt,
      acceptedAt:
          clearAcceptedAt
              ? null
              : acceptedAt ??
                  this.acceptedAt,
      declinedAt:
          clearDeclinedAt
              ? null
              : declinedAt ??
                  this.declinedAt,
      expiredAt:
          clearExpiredAt
              ? null
              : expiredAt ??
                  this.expiredAt,
      withdrawnAt:
          clearWithdrawnAt
              ? null
              : withdrawnAt ??
                  this.withdrawnAt,
    );
  }
}