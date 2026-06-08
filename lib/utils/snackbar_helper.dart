import 'package:flutter/material.dart';

/// Muestra un SnackBar flotante con ✕ para cerrar y auto-cierre a los 3 segundos.
///
/// Uso:
/// ```dart
/// mostrarNotificacion(context, texto: 'Guardado', color: Colors.green);
/// mostrarNotificacion(context, texto: 'Error', color: Colors.red);
/// ```
void mostrarNotificacion(
  BuildContext context, {
  required String texto,
  Color? color,
  SnackBarAction? action,
}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(texto),
      backgroundColor: color,
      action: action,
      duration: const Duration(seconds: 3),
      showCloseIcon: true,
      closeIconColor: Colors.white,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}
