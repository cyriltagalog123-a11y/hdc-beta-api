class NexusMemory {

  final Map<String, dynamic> _memory = {};

  void remember({

    required String key,

    required dynamic value,

  }) {

    _memory[key] = value;
  }

  dynamic recall(
    String key,
  ) {

    return _memory[key];
  }

  bool contains(
    String key,
  ) {

    return _memory.containsKey(key);
  }

  void forget(
    String key,
  ) {

    _memory.remove(key);
  }

  void clear() {

    _memory.clear();
  }
}