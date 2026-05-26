import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

Future<String> persistPickedImage(XFile picked, {required String prefix}) async {
  final dir = await getApplicationDocumentsDirectory();
  final targetPath = '${dir.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
  final copied = await File(picked.path).copy(targetPath);
  return copied.path;
}
