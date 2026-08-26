import 'dart:io';

Future<bool> openExternalUri(Uri uri) async {
  try {
    if (Platform.isWindows) {
      await Process.start('explorer.exe', <String>[
        uri.toString(),
      ], mode: ProcessStartMode.detached);
    } else if (Platform.isMacOS) {
      await Process.start('open', <String>[
        uri.toString(),
      ], mode: ProcessStartMode.detached);
    } else if (Platform.isLinux) {
      await Process.start('xdg-open', <String>[
        uri.toString(),
      ], mode: ProcessStartMode.detached);
    } else {
      return false;
    }
    return true;
  } on Object {
    return false;
  }
}
