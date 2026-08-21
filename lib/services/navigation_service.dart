import 'package:flutter/material.dart';

/// Navegación imperativa centralizada sin alterar las rutas actuales.
abstract final class AppNavigation {
  static Future<T?> push<T>(BuildContext context, Widget page) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute<T>(builder: (_) => page),
    );
  }
}
