class ServiceLocator {

  static final Map<Type, dynamic> _services = {};

  static void register<T>(T service) {
    _services[T] = service;
  }

  static T get<T>() {

    final service = _services[T];

    if (service == null) {
      throw Exception(
        'Service of type $T is not registered.',
      );
    }

    return service as T;
  }

  static bool isRegistered<T>() {
    return _services.containsKey(T);
  }

  static void clear() {
    _services.clear();
  }
}