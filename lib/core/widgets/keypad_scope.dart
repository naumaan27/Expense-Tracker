import 'package:flutter/material.dart';

/// Broadcasts whether to use the native Android system keyboard for amount
/// inputs instead of the in-app custom numpad.
class KeypadScope extends InheritedWidget {
  const KeypadScope({
    required this.useSystemKeyboard,
    required super.child,
    super.key,
  });

  final bool useSystemKeyboard;

  /// Returns true if the native Android keyboard should be used.
  /// Falls back to false in bare widget tests where [KeypadScope] is absent.
  static bool of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<KeypadScope>();
    return scope?.useSystemKeyboard ?? false;
  }

  @override
  bool updateShouldNotify(KeypadScope oldWidget) =>
      useSystemKeyboard != oldWidget.useSystemKeyboard;
}
