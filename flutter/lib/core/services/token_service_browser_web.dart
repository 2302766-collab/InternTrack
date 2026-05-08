import 'dart:html' as html;

const bool usesBrowserStorage = true;

Future<void> saveToken(String key, String value) async {
  html.window.localStorage[key] = value;
}

Future<String?> readToken(String key) async {
  return html.window.localStorage[key];
}

Future<void> clearToken(String key) async {
  html.window.localStorage.remove(key);
}
