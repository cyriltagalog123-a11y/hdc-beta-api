import '../repositories/master_data_repository.dart';

class ServiceRequestDraft {
  ServiceCategory? category;

  String problemDescription = "";

  String urgency = "Normal";

  ServiceRequestDraft();

  ServiceRequestDraft copy() {
    return ServiceRequestDraft()
      ..category = category
      ..problemDescription = problemDescription
      ..urgency = urgency;
  }
}