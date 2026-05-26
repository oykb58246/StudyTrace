import 'dart:typed_data';

Future<String> savePlatformExportFile({
  required String fileName,
  required String mimeType,
  Uint8List? bytes,
  String? text,
}) {
  throw UnsupportedError('当前平台暂不支持文件导出');
}
