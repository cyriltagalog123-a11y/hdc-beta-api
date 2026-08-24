import 'proposal.dart';

class ProposalDraft {
  final String? proposalId;
  final String requestId;
  final String technicianId;
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
  final List<String> attachmentIds;

  const ProposalDraft({
    required this.requestId,
    required this.technicianId,
    required this.serviceFee,
    required this.partsArrangement,
    required this.earliestArrival,
    required this.estimatedDurationMinutes,
    required this.warrantyType,
    required this.diagnosis,
    required this.repairApproach,
    required this.professionalNotes,
    this.proposalId,
    this.estimatedPartsCost,
    this.customWarrantyDays,
    this.attachmentIds = const [],
  });

  List<String> validate() {
    final errors = <String>[];

    if (requestId.trim().isEmpty) {
      errors.add('A service request is required.');
    }
    if (technicianId.trim().isEmpty) {
      errors.add('A technician is required.');
    }
    if (serviceFee < 0) {
      errors.add('The service fee cannot be negative.');
    }
    if (partsArrangement == ProposalPartsArrangement.technicianSupplies &&
        (estimatedPartsCost == null || estimatedPartsCost! < 0)) {
      errors.add('Enter a valid estimated parts cost.');
    }
    if (estimatedDurationMinutes <= 0) {
      errors.add('Estimated duration must be greater than zero.');
    }
    if (warrantyType == ProposalWarrantyType.custom &&
        (customWarrantyDays == null || customWarrantyDays! <= 0)) {
      errors.add('Enter a valid custom warranty period.');
    }

    return errors;
  }
}
