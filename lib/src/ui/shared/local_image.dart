import 'package:flutter/widgets.dart';

import 'local_image_stub.dart'
    if (dart.library.io) 'local_image_io.dart';

Widget localImageFromPath(
  String path, {
  required BoxFit fit,
  required Widget Function(BuildContext, Object, StackTrace?) errorBuilder,
}) {
  return buildLocalImageFromPath(
    path,
    fit: fit,
    errorBuilder: errorBuilder,
  );
}
