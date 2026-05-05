// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

Future<bool> downloadBytes({
  required List<int> bytes,
  required String filename,
  required String mimeType,
}) async {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);

  return true;
}

Future<bool> openBytesInNewTab({
  required List<int> bytes,
  required String mimeType,
}) async {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');

  Future<void>.delayed(const Duration(seconds: 30), () {
    html.Url.revokeObjectUrl(url);
  });

  return true;
}
