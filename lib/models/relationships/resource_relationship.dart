import 'relationship_type.dart';

class ResourceRelationship {

  final String id;

  final String sourceId;

  final String targetId;

  final RelationshipType type;

  final DateTime createdAt;

  const ResourceRelationship({

    required this.id,

    required this.sourceId,

    required this.targetId,

    required this.type,

    required this.createdAt,

  });

}