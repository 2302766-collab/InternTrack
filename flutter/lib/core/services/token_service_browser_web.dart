// This file is conditionally imported only on Flutter web.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

const bool usesBrowserStorage = true;

Future<void> saveValue(String key, String value) async {
  html.window.sessionStorage[key] = value;
}

Future<String?> readValue(String key) async {
  return html.window.sessionStorage[key];
}

Future<void> clearValue(String key) async {
  html.window.sessionStorage.remove(key);
}

Future<void> clearPersistedValue(String key) async {
  html.window.sessionStorage.remove(key);
  html.window.localStorage.remove(key);
}
