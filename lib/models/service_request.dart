enum ServiceRequestStatus {
  draft,
  open,
  receivingOffers,
  technicianSelected,
  inProgress,
  completed,
  cancelled,
  expired,
}

enum ServiceRequestUrgency {
  flexible,
  normal,
  urgent,
  emergency,
}

extension ServiceRequestStatusDetails on ServiceRequestStatus {
  String get label {
    switch (this) {
      case ServiceRequestStatus.draft:
        return 'Draft';
      case ServiceRequestStatus.open:
        return 'Open';
      case ServiceRequestStatus.receivingOffers:
        return 'Receiving Offers';
      case ServiceRequestStatus.technicianSelected:
        return 'Technician Selected';
      case ServiceRequestStatus.inProgress:
        return 'In Progress';
      case ServiceRequestStatus.completed:
        return 'Completed';
      case ServiceRequestStatus.cancelled:
        return 'Cancelled';
      case ServiceRequestStatus.expired:
        return 'Expired';
    }
  }

  bool get isActive {
    return this == ServiceRequestStatus.open ||
        this == ServiceRequestStatus.receivingOffers ||
        this == ServiceRequestStatus.technicianSelected ||
        this == ServiceRequestStatus.inProgress;
  }

  bool get acceptsProposals {
    return this == ServiceRequestStatus.open ||
        this == ServiceRequestStatus.receivingOffers;
  }

  bool get canEdit {
    return this == ServiceRequestStatus.draft ||
        this == ServiceRequestStatus.open ||
        this == ServiceRequestStatus.receivingOffers;
  }
}

extension ServiceRequestUrgencyDetails on ServiceRequestUrgency {
  String get label {
    switch (this) {
      case ServiceRequestUrgency.flexible:
        return 'Flexible';
      case ServiceRequestUrgency.normal:
        return 'Normal';
      case ServiceRequestUrgency.urgent:
        return 'Urgent';
      case ServiceRequestUrgency.emergency:
        return 'Emergency';
    }
  }

  String get description {
    switch (this) {
      case ServiceRequestUrgency.flexible:
        return 'Any suitable date is fine.';
      case ServiceRequestUrgency.normal:
        return 'Service is needed within a few days.';
      case ServiceRequestUrgency.urgent:
        return 'Service is needed as soon as possible.';
      case ServiceRequestUrgency.emergency:
        return 'The issue is critical and needs immediate attention.';
    }
  }
}

class ServiceRequest {
  final String id;
  final String customerId;
  final String customerName;
  final String title;
  final String categoryId;
  final String categoryName;
  final String description;
  final String location;
  final DateTime preferredDate;
  final String preferredTime;
  final ServiceRequestUrgency urgency;
  final double? minimumBudget;
  final double? maximumBudget;
  final ServiceRequestStatus status;
  final int offerCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ServiceRequest({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.title,
    required this.categoryId,
    required this.categoryName,
    required this.description,
    required this.location,
    required this.preferredDate,
    required this.preferredTime,
    required this.urgency,
    required this.status,
    required this.offerCount,
    required this.createdAt,
    required this.updatedAt,
    this.minimumBudget,
    this.maximumBudget,
  });

  bool get hasBudget => minimumBudget != null || maximumBudget != null;

  String get budgetLabel {
    if (minimumBudget != null && maximumBudget != null) {
      return 'PHP ${minimumBudget!.toStringAsFixed(0)} - '
          '${maximumBudget!.toStringAsFixed(0)}';
    }
    if (minimumBudget != null) {
      return 'From PHP ${minimumBudget!.toStringAsFixed(0)}';
    }
    if (maximumBudget != null) {
      return 'Up to PHP ${maximumBudget!.toStringAsFixed(0)}';
    }
    return 'Open budget';
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'customerName': customerName,
      'title': title,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'description': description,
      'location': location,
      'preferredDate': preferredDate.toIso8601String(),
      'preferredTime': preferredTime,
      'urgency': urgency.name,
      'minimumBudget': minimumBudget,
      'maximumBudget': maximumBudget,
      'status': status.name,
      'offerCount': offerCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    return ServiceRequest(
      id: json['id'] as String,
      customerId: json['customerId'] as String,
      customerName: json['customerName'] as String,
      title: json['title'] as String,
      categoryId: json['categoryId'] as String,
      categoryName: json['categoryName'] as String,
      description: json['description'] as String,
      location: json['location'] as String,
      preferredDate: DateTime.parse(json['preferredDate'] as String),
      preferredTime: json['preferredTime'] as String,
      urgency: ServiceRequestUrgency.values.byName(
        json['urgency'] as String,
      ),
      minimumBudget: (json['minimumBudget'] as num?)?.toDouble(),
      maximumBudget: (json['maximumBudget'] as num?)?.toDouble(),
      status: ServiceRequestStatus.values.byName(json['status'] as String),
      offerCount: (json['offerCount'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  ServiceRequest copyWith({
    String? title,
    String? categoryId,
    String? categoryName,
    String? description,
    String? location,
    DateTime? preferredDate,
    String? preferredTime,
    ServiceRequestUrgency? urgency,
    double? minimumBudget,
    double? maximumBudget,
    bool clearMinimumBudget = false,
    bool clearMaximumBudget = false,
    ServiceRequestStatus? status,
    int? offerCount,
    DateTime? updatedAt,
  }) {
    return ServiceRequest(
      id: id,
      customerId: customerId,
      customerName: customerName,
      title: title ?? this.title,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      description: description ?? this.description,
      location: location ?? this.location,
      preferredDate: preferredDate ?? this.preferredDate,
      preferredTime: preferredTime ?? this.preferredTime,
      urgency: urgency ?? this.urgency,
      minimumBudget: clearMinimumBudget
          ? null
          : minimumBudget ?? this.minimumBudget,
      maximumBudget: clearMaximumBudget
          ? null
          : maximumBudget ?? this.maximumBudget,
      status: status ?? this.status,
      offerCount: offerCount ?? this.offerCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
