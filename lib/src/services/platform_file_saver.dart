import 'dart:typed_data';

import 'platform_file_saver_stub.dart'
    if (dart.library.io) 'platform_file_saver_io.dart'
    if (dart.library.html) 'platform_file_saver_web.dart';

class SavedExportFile {
  const SavedExportFile({required this.path});

  final String path;
}

Future<SavedExportFile> saveExportFile({
  required String fileName,
  required String mimeType,
  Uint8List? bytes,
  String? text,
}) async {
  final path = await savePlatformExportFile(
    fileName: fileName,
    mimeType: mimeType,
    bytes: bytes,
    text: text,
  );
  return SavedExportFile(path: path);
}
