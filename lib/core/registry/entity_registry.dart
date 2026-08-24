import 'entity_definition.dart';

class EntityRegistry {

  static final Map<String, EntityDefinition> _entities = {};

  static void register(EntityDefinition entity) {

    _entities[entity.id] = entity;

  }

  static EntityDefinition? get(String id) {

    return _entities[id];

  }

  static List<EntityDefinition> all() {

    return _entities.values.toList();

  }

  static bool contains(String id) {

    return _entities.containsKey(id);

  }

}