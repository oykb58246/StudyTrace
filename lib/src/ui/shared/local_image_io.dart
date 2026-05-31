import 'dart:io';

import 'package:flutter/widgets.dart';

Widget buildLocalImageFromPath(
  String path, {
  required BoxFit fit,
  required Widget Function(BuildContext, Object, StackTrace?) errorBuilder,
}) {
  final uri = Uri.tryParse(path);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
    return Image.network(
      path,
      fit: fit,
      errorBuilder: errorBuilder,
    );
  }
  return Image.file(
    File(path),
    fit: fit,
    errorBuilder: errorBuilder,
  );
}
