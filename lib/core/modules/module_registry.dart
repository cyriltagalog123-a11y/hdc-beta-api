import 'module_info.dart';

class ModuleRegistry {
  ModuleRegistry._();

  static final ModuleRegistry instance =
      ModuleRegistry._();

  final List<ModuleInfo> _modules = [];

  void register(
    ModuleInfo module,
  ) {
    _modules.add(module);
  }

  List<ModuleInfo> get modules =>
      List.unmodifiable(_modules);

  ModuleInfo? findModule(
    String id,
  ) {
    try {
      return _modules.firstWhere(
        (module) => module.id == id,
      );
    } catch (_) {
      return null;
    }
  }
}