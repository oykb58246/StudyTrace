import 'package:image_picker/image_picker.dart';

Future<String> persistPickedImage(XFile picked, {required String prefix}) async {
  return picked.path;
}
