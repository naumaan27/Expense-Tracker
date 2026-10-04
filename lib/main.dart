import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  widgetsBinding.deferFirstFrame();
  runApp(const ProviderScope(child: XpencApp()));
}
