import 'package:flutter/widgets.dart';

Widget buildLocalImageFromPath(
  String path, {
  required BoxFit fit,
  required Widget Function(BuildContext, Object, StackTrace?) errorBuilder,
}) {
  return Image.network(
    path,
    fit: fit,
    errorBuilder: errorBuilder,
  );
}
