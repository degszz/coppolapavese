import 'package:flutter/material.dart';

/// Sistema de validación a nivel de campo, compartido por toda la app.
///
/// Patrón de uso en un State:
/// ```dart
/// final _errores = ErroresCampos();
///
/// // En initState, para limpiar el error automáticamente al escribir:
/// _errores.vincular(_nombreCtrl, 'nombre', refrescar: () { if (mounted) setState(() {}); });
///
/// // En el campo:
/// TextField(
///   controller: _nombreCtrl,
///   decoration: InputDecoration(
///     labelText: 'Nombre *',
///     errorText: _errores['nombre'],   // null = sin error
///     border: const OutlineInputBorder(),
///   ),
/// )
///
/// // Al validar antes de guardar:
/// bool _validar() {
///   setState(() {
///     _errores.limpiarPrefijo('');   // o un prefijo tipo 'pr_' por sección
///     if (_nombreCtrl.text.trim().isEmpty) {
///       _errores['nombre'] = 'Obligatorio: nombre';
///     }
///   });
///   return _errores.vacio;
/// }
/// ```
class ErroresCampos {
  final Map<String, String> _map = {};

  /// Devuelve el mensaje de error del campo, o null si está OK.
  String? operator [](String key) => _map[key];

  /// Marca (o reemplaza) el error de un campo.
  void operator []=(String key, String mensaje) => _map[key] = mensaje;

  void remover(String key) => _map.remove(key);

  /// true si NO hay errores.
  bool get vacio => _map.isEmpty;

  /// Todos los mensajes, en orden de inserción (para el snackbar resumen).
  List<String> get mensajes => _map.values.toList();

  /// Errores cuya key empieza con [prefijo].
  bool hayConPrefijo(String prefijo) =>
      _map.keys.any((k) => k.startsWith(prefijo));

  /// Borra solo los errores de una sección (por prefijo de key).
  void limpiarPrefijo(String prefijo) =>
      _map.removeWhere((k, _) => k.startsWith(prefijo));

  void limpiarTodo() => _map.clear();

  /// Limpia automáticamente el error de [key] cuando el usuario empieza a
  /// escribir en [ctrl]. Llamar una vez por campo en initState (o al crear
  /// filas dinámicas).
  void vincular(TextEditingController ctrl, String key,
      {VoidCallback? refrescar}) {
    ctrl.addListener(() {
      if (_map.containsKey(key)) {
        _map.remove(key);
        refrescar?.call();
      }
    });
  }
}
