import '../repositories/master_data_repository.dart';
import 'service_request.dart';

class ServiceRequestFormData {
  final String title;
  final ServiceCategory category;
  final String description;
  final String location;
  final DateTime preferredDate;
  final String preferredTime;
  final ServiceRequestUrgency urgency;
  final double? minimumBudget;
  final double? maximumBudget;

  const ServiceRequestFormData({
    required this.title,
    required this.category,
    required this.description,
    required this.location,
    required this.preferredDate,
    required this.preferredTime,
    required this.urgency,
    this.minimumBudget,
    this.maximumBudget,
  });
}
