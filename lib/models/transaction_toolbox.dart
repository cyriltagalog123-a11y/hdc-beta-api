class HdcScheduleChange {
  final String id;
  final String proposedBy;
  final DateTime proposedFor;
  final String note;
  final String status;
  final DateTime createdAt;

  const HdcScheduleChange({
    required this.id,
    required this.proposedBy,
    required this.proposedFor,
    required this.note,
    required this.status,
    required this.createdAt,
  });

  bool get isPending => status == 'pending';

  factory HdcScheduleChange.fromJson(Map<String, dynamic> json) {
    return HdcScheduleChange(
      id: _string(json, 'id'),
      proposedBy: _string(json, 'proposedBy'),
      proposedFor: _date(json, 'proposedFor'),
      note: _string(json, 'note'),
      status: _string(json, 'status'),
      createdAt: _date(json, 'createdAt'),
    );
  }
}

class HdcChangeOrder {
  final String id;
  final String proposedBy;
  final String reason;
  final int serviceFeeMinor;
  final int partsCostMinor;
  final int totalMinor;
  final String currency;
  final String status;
  final DateTime createdAt;

  const HdcChangeOrder({
    required this.id,
    required this.proposedBy,
    required this.reason,
    required this.serviceFeeMinor,
    required this.partsCostMinor,
    required this.totalMinor,
    required this.currency,
    required this.status,
    required this.createdAt,
  });

  bool get isPending => status == 'pending';

  factory HdcChangeOrder.fromJson(Map<String, dynamic> json) {
    return HdcChangeOrder(
      id: _string(json, 'id'),
      proposedBy: _string(json, 'proposedBy'),
      reason: _string(json, 'reason'),
      serviceFeeMinor: _integer(json, 'serviceFeeMinor'),
      partsCostMinor: _integer(json, 'partsCostMinor'),
      totalMinor: _integer(json, 'totalMinor'),
      currency: _string(json, 'currency'),
      status: _string(json, 'status'),
      createdAt: _date(json, 'createdAt'),
    );
  }
}

class HdcTransactionException {
  final String id;
  final String reportedBy;
  final String exceptionType;
  final String reason;
  final String status;
  final DateTime createdAt;

  const HdcTransactionException({
    required this.id,
    required this.reportedBy,
    required this.exceptionType,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  factory HdcTransactionException.fromJson(Map<String, dynamic> json) {
    return HdcTransactionException(
      id: _string(json, 'id'),
      reportedBy: _string(json, 'reportedBy'),
      exceptionType: _string(json, 'exceptionType'),
      reason: _string(json, 'reason'),
      status: _string(json, 'status'),
      createdAt: _date(json, 'createdAt'),
    );
  }
}

class HdcServicePayment {
  final String id;
  final String recordedBy;
  final int amountMinor;
  final String currency;
  final String paymentMethod;
  final String status;
  final String note;
  final String? externalReference;
  final int refundedMinor;
  final DateTime createdAt;

  const HdcServicePayment({
    required this.id,
    required this.recordedBy,
    required this.amountMinor,
    required this.currency,
    required this.paymentMethod,
    required this.status,
    required this.note,
    required this.refundedMinor,
    required this.createdAt,
    this.externalReference,
  });

  int get remainingRefundableMinor => amountMinor - refundedMinor;

  factory HdcServicePayment.fromJson(Map<String, dynamic> json) {
    return HdcServicePayment(
      id: _string(json, 'id'),
      recordedBy: _string(json, 'recordedBy'),
      amountMinor: _integer(json, 'amountMinor'),
      currency: _string(json, 'currency'),
      paymentMethod: _string(json, 'paymentMethod'),
      status: _string(json, 'status'),
      note: _string(json, 'note'),
      externalReference: _optionalString(json['externalReference']),
      refundedMinor: _integer(json, 'refundedMinor'),
      createdAt: _date(json, 'createdAt'),
    );
  }
}

class HdcPaymentEvent {
  final String id;
  final String paymentId;
  final String actorId;
  final String? relatedEventId;
  final String eventType;
  final int? amountMinor;
  final String note;
  final DateTime createdAt;

  const HdcPaymentEvent({
    required this.id,
    required this.paymentId,
    required this.actorId,
    required this.eventType,
    required this.note,
    required this.createdAt,
    this.amountMinor,
    this.relatedEventId,
  });

  factory HdcPaymentEvent.fromJson(Map<String, dynamic> json) {
    return HdcPaymentEvent(
      id: _string(json, 'id'),
      paymentId: _string(json, 'paymentId'),
      actorId: _string(json, 'actorId'),
      relatedEventId: _optionalString(json['relatedEventId']),
      eventType: _string(json, 'eventType'),
      amountMinor: json['amountMinor'] is num
          ? (json['amountMinor'] as num).toInt()
          : null,
      note: _string(json, 'note'),
      createdAt: _date(json, 'createdAt'),
    );
  }
}

class HdcServiceReceipt {
  final String id;
  final String paymentId;
  final String receiptType;
  final int amountMinor;
  final String currency;
  final String verificationLevel;
  final DateTime issuedAt;

  const HdcServiceReceipt({
    required this.id,
    required this.paymentId,
    required this.receiptType,
    required this.amountMinor,
    required this.currency,
    required this.verificationLevel,
    required this.issuedAt,
  });

  factory HdcServiceReceipt.fromJson(Map<String, dynamic> json) {
    return HdcServiceReceipt(
      id: _string(json, 'id'),
      paymentId: _string(json, 'paymentId'),
      receiptType: _string(json, 'receiptType'),
      amountMinor: _integer(json, 'amountMinor'),
      currency: _string(json, 'currency'),
      verificationLevel: _string(json, 'verificationLevel'),
      issuedAt: _date(json, 'issuedAt'),
    );
  }
}

class HdcServiceDocument {
  final String id;
  final String? disputeId;
  final String createdBy;
  final String documentType;
  final String title;
  final String content;
  final String contentSha256;
  final int byteSize;
  final String status;
  final DateTime createdAt;

  const HdcServiceDocument({
    required this.id,
    required this.createdBy,
    required this.documentType,
    required this.title,
    required this.content,
    required this.contentSha256,
    required this.byteSize,
    required this.status,
    required this.createdAt,
    this.disputeId,
  });

  factory HdcServiceDocument.fromJson(Map<String, dynamic> json) {
    return HdcServiceDocument(
      id: _string(json, 'id'),
      disputeId: _optionalString(json['disputeId']),
      createdBy: _string(json, 'createdBy'),
      documentType: _string(json, 'documentType'),
      title: _string(json, 'title'),
      content: _string(json, 'content'),
      contentSha256: _string(json, 'contentSha256'),
      byteSize: _integer(json, 'byteSize'),
      status: _string(json, 'status'),
      createdAt: _date(json, 'createdAt'),
    );
  }
}

class HdcServiceDispute {
  final String id;
  final String transactionId;
  final String openedBy;
  final String reasonCode;
  final String summary;
  final String requestedOutcome;
  final String priorTransactionStatus;
  final String status;
  final String? resolutionOutcome;
  final String resolutionNote;
  final DateTime createdAt;
  final String? requestTitle;
  final String? customerName;
  final String? technicianName;

  const HdcServiceDispute({
    required this.id,
    required this.transactionId,
    required this.openedBy,
    required this.reasonCode,
    required this.summary,
    required this.requestedOutcome,
    required this.priorTransactionStatus,
    required this.status,
    required this.resolutionNote,
    required this.createdAt,
    this.resolutionOutcome,
    this.requestTitle,
    this.customerName,
    this.technicianName,
  });

  bool get isActive => status == 'open' || status == 'underReview';

  factory HdcServiceDispute.fromJson(Map<String, dynamic> json) {
    return HdcServiceDispute(
      id: _string(json, 'id'),
      transactionId: _string(json, 'transactionId'),
      openedBy: _string(json, 'openedBy'),
      reasonCode: _string(json, 'reasonCode'),
      summary: _string(json, 'summary'),
      requestedOutcome: _string(json, 'requestedOutcome'),
      priorTransactionStatus: _string(json, 'priorTransactionStatus'),
      status: _string(json, 'status'),
      resolutionOutcome: _optionalString(json['resolutionOutcome']),
      resolutionNote: _string(json, 'resolutionNote'),
      createdAt: _date(json, 'createdAt'),
      requestTitle: _optionalString(json['requestTitle']),
      customerName: _optionalString(json['customerName']),
      technicianName: _optionalString(json['technicianName']),
    );
  }
}

class HdcDisputeEvent {
  final String id;
  final String disputeId;
  final String actorId;
  final String eventType;
  final String message;
  final DateTime createdAt;

  const HdcDisputeEvent({
    required this.id,
    required this.disputeId,
    required this.actorId,
    required this.eventType,
    required this.message,
    required this.createdAt,
  });

  factory HdcDisputeEvent.fromJson(Map<String, dynamic> json) {
    return HdcDisputeEvent(
      id: _string(json, 'id'),
      disputeId: _string(json, 'disputeId'),
      actorId: _string(json, 'actorId'),
      eventType: _string(json, 'eventType'),
      message: _string(json, 'message'),
      createdAt: _date(json, 'createdAt'),
    );
  }
}

class HdcTransactionToolbox {
  final String transactionId;
  final int authorizedTotalMinor;
  final int confirmedPaidMinor;
  final int balanceMinor;
  final String currency;
  final List<HdcScheduleChange> schedules;
  final List<HdcChangeOrder> changeOrders;
  final List<HdcTransactionException> exceptions;
  final List<HdcServicePayment> payments;
  final List<HdcPaymentEvent> paymentEvents;
  final List<HdcServiceReceipt> receipts;
  final List<HdcServiceDocument> documents;
  final List<HdcServiceDispute> disputes;
  final List<HdcDisputeEvent> disputeEvents;
  final DateTime updatedAt;

  const HdcTransactionToolbox({
    required this.transactionId,
    required this.authorizedTotalMinor,
    required this.confirmedPaidMinor,
    required this.balanceMinor,
    required this.currency,
    required this.schedules,
    required this.changeOrders,
    required this.exceptions,
    required this.payments,
    required this.paymentEvents,
    required this.receipts,
    required this.documents,
    required this.disputes,
    required this.disputeEvents,
    required this.updatedAt,
  });

  HdcScheduleChange? get pendingSchedule {
    for (final item in schedules) {
      if (item.isPending) return item;
    }
    return null;
  }

  HdcChangeOrder? get pendingChangeOrder {
    for (final item in changeOrders) {
      if (item.isPending) return item;
    }
    return null;
  }

  HdcServiceDispute? get activeDispute {
    for (final item in disputes) {
      if (item.isActive) return item;
    }
    return null;
  }

  factory HdcTransactionToolbox.fromJson(Map<String, dynamic> json) {
    return HdcTransactionToolbox(
      transactionId: _string(json, 'transactionId'),
      authorizedTotalMinor: _integer(json, 'authorizedTotalMinor'),
      confirmedPaidMinor: _integer(json, 'confirmedPaidMinor'),
      balanceMinor: _integer(json, 'balanceMinor'),
      currency: _string(json, 'currency'),
      schedules: _objects(json['schedules'])
          .map(HdcScheduleChange.fromJson)
          .toList(growable: false),
      changeOrders: _objects(json['changeOrders'])
          .map(HdcChangeOrder.fromJson)
          .toList(growable: false),
      exceptions: _objects(json['exceptions'])
          .map(HdcTransactionException.fromJson)
          .toList(growable: false),
      payments: _objects(json['payments'])
          .map(HdcServicePayment.fromJson)
          .toList(growable: false),
      paymentEvents: _objects(json['paymentEvents'])
          .map(HdcPaymentEvent.fromJson)
          .toList(growable: false),
      receipts: _objects(json['receipts'])
          .map(HdcServiceReceipt.fromJson)
          .toList(growable: false),
      documents: _objects(json['documents'])
          .map(HdcServiceDocument.fromJson)
          .toList(growable: false),
      disputes: _objects(json['disputes'])
          .map(HdcServiceDispute.fromJson)
          .toList(growable: false),
      disputeEvents: _objects(json['disputeEvents'])
          .map(HdcDisputeEvent.fromJson)
          .toList(growable: false),
      updatedAt: _date(json, 'updatedAt'),
    );
  }
}

List<Map<String, dynamic>> _objects(Object? value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map((item) {
    return item.map((key, value) => MapEntry('$key', value));
  }).toList(growable: false);
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value == null ? '' : '$value';
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  final normalized = '$value'.trim();
  return normalized.isEmpty ? null : normalized;
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}

DateTime _date(Map<String, dynamic> json, String key) {
  return DateTime.tryParse('${json[key]}') ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
