import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String> savePlatformExportFile({
  required String fileName,
  required String mimeType,
  Uint8List? bytes,
  String? text,
}) async {
  final base = await getApplicationDocumentsDirectory();
  final dir = Directory('${base.path}${Platform.pathSeparator}studytrace_exports');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  final file = File('${dir.path}${Platform.pathSeparator}$fileName');
  if (bytes != null) {
    await file.writeAsBytes(bytes, flush: true);
  } else {
    await file.writeAsString(text ?? '', encoding: utf8, flush: true);
  }
  return file.path;
}
