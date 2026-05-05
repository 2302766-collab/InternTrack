import 'dart:typed_data';

class PickedFileData {
  final String name;
  final Uint8List bytes;
  final String mimeType;

  const PickedFileData({
    required this.name,
    required this.bytes,
    required this.mimeType,
  });
}
