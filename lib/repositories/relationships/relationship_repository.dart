import '../../models/relationships/resource_relationship.dart';

abstract class RelationshipRepository {

  List<ResourceRelationship> getAll();

  List<ResourceRelationship> relatedTo(
    String resourceId,
  );

  Future<void> create(
    ResourceRelationship relationship,
  );

  Future<void> delete(
    String relationshipId,
  );

}