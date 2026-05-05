// ignore_for_file: deprecated_member_use, deprecated_member_use_from_same_package, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'picked_file_data.dart';

Future<PickedFileData?> pickSingleFile({
  List<String> allowedExtensions = const <String>[],
}) async {
  final input = html.FileUploadInputElement()
    ..multiple = false
    ..style.display = 'none';

  if (allowedExtensions.isNotEmpty) {
    input.accept = allowedExtensions.map((ext) => '.$ext').join(',');
  }

  final completer = Completer<PickedFileData?>();
  html.document.body?.append(input);

  void completeWith(PickedFileData? value) {
    if (!completer.isCompleted) {
      completer.complete(value);
    }
    input.remove();
  }

  input.onChange.listen((_) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completeWith(null);
      return;
    }

    final file = files.first;
    final reader = html.FileReader();

    reader.onLoad.listen((_) {
      final result = reader.result;
      Uint8List? bytes;

      if (result is ByteBuffer) {
        bytes = Uint8List.view(result);
      } else if (result is Uint8List) {
        bytes = result;
      } else if (result is List<int>) {
        bytes = Uint8List.fromList(result);
      }

      if (bytes == null) {
        completeWith(null);
        return;
      }

      completeWith(
        PickedFileData(
          name: file.name,
          bytes: bytes,
          mimeType: file.type.isNotEmpty
              ? file.type
              : 'application/octet-stream',
        ),
      );
    });

    reader.onError.listen((_) {
      completeWith(null);
    });

    reader.readAsArrayBuffer(file);
  });

  input.click();
  return completer.future;
}
