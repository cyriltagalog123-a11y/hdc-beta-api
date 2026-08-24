class NexusKnowledge {

  final Map<String, dynamic> _knowledge = {};

  void register({

    required String key,

    required dynamic source,

  }) {

    _knowledge[key] = source;
  }

  T? source<T>(String key) {

    final value = _knowledge[key];

    if (value is T) {
      return value;
    }

    return null;
  }

  bool has(String key) {

    return _knowledge.containsKey(key);
  }

  List<String> get availableSources {

    return _knowledge.keys.toList();
  }
}