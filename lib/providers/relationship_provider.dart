import 'package:flutter/material.dart';

import '../models/relationships/resource_relationship.dart';
import '../repositories/relationships/relationship_repository.dart';

class RelationshipProvider
    extends ChangeNotifier {

  final RelationshipRepository repository;

  RelationshipProvider({

    required this.repository,
  });

  List<ResourceRelationship> relatedTo(
    String id,
  ) {

    return repository.relatedTo(id);
  }

  Future<void> create(
    ResourceRelationship relationship,
  ) async {

    await repository.create(
      relationship,
    );

    notifyListeners();
  }

  Future<void> remove(
    String id,
  ) async {

    await repository.delete(id);

    notifyListeners();
  }

}