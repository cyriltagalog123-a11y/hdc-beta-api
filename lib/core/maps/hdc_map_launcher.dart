import 'hdc_map_config.dart';
import 'hdc_map_launcher_stub.dart'
    if (dart.library.io) 'hdc_map_launcher_io.dart'
    if (dart.library.html) 'hdc_map_launcher_web.dart'
    as platform;

class HdcMapLauncher {
  const HdcMapLauncher._();

  static Future<bool> openServiceArea(String serviceArea) {
    return platform.openExternalUri(HdcMapConfig.serviceAreaUri(serviceArea));
  }
}
