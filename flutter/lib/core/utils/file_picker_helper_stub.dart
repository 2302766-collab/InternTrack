import 'package:file_picker/file_picker.dart';

import 'picked_file_data.dart';

String _inferMimeType(String fileName) {
  final normalized = fileName.toLowerCase();

  if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) {
    return 'image/jpeg';
  }

  if (normalized.endsWith('.png')) {
    return 'image/png';
  }

  if (normalized.endsWith('.pdf')) {
    return 'application/pdf';
  }

  return 'application/octet-stream';
}

Future<PickedFileData?> pickSingleFile({
  List<String> allowedExtensions = const <String>[],
}) async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: false,
    type: allowedExtensions.isEmpty ? FileType.any : FileType.custom,
    allowedExtensions: allowedExtensions.isEmpty ? null : allowedExtensions,
    withData: true,
  );

  final file = result?.files.single;
  if (file == null || file.bytes == null) {
    return null;
  }

  return PickedFileData(
    name: file.name,
    bytes: file.bytes!,
    mimeType: _inferMimeType(file.name),
  );
}
