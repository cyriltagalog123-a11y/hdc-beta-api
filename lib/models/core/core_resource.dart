import 'resource_health.dart';
import 'resource_status.dart';

abstract class CoreResource {

  final String id;

  final String name;

  final String description;

  final ResourceStatus status;

  final DateTime createdAt;

  final DateTime updatedAt;

  final List<String> tags;

  final ResourceHealth? health;

  const CoreResource({

    required this.id,

    required this.name,

    required this.description,

    required this.status,

    required this.createdAt,

    required this.updatedAt,

    required this.tags,

    this.health,
  });

}