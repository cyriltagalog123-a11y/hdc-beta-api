// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

Future<bool> openExternalUri(Uri uri) async {
  html.window.open(uri.toString(), '_blank', 'noopener,noreferrer');
  return true;
}
