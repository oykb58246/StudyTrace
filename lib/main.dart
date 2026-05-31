import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'src/services/ai_tool_registry.dart';

void main() {
  registerAllTools();
  runApp(const MyApp());
}
