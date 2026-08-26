// ignore_for_file: deprecated_member_use

import 'dart:html' as html;

Future<bool> openExternalUri(Uri uri) async {
  html.window.open(uri.toString(), '_blank', 'noopener,noreferrer');
  return true;
}
