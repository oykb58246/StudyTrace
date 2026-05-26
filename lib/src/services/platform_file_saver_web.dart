import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

Future<String> savePlatformExportFile({
  required String fileName,
  required String mimeType,
  Uint8List? bytes,
  String? text,
}) async {
  final data = bytes ?? Uint8List.fromList(utf8.encode(text ?? ''));
  final blob = html.Blob([data], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = fileName
    ..click();
  html.Url.revokeObjectUrl(url);
  return fileName;
}
