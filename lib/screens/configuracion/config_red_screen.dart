import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../database/db_config.dart';
import '../../database/database_helper.dart';

class ConfigRedScreen extends StatefulWidget {
  const ConfigRedScreen({super.key});

  @override
  State<ConfigRedScreen> createState() => _ConfigRedScreenState();
}

class _ConfigRedScreenState extends State<ConfigRedScreen> {
  final _rutaCtrl = TextEditingController();
  String _rutaLocal = '';
  String _rutaActualDb = '';
  bool _cargando = true;
  bool _verificando = false;
  String? _mensaje;
  bool? _mensajeOk;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _rutaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final config = DbConfig.instance;
    await config.cargar();
    final rutaLocal = await config.obtenerRutaLocal();
    final rutaDb = await config.obtenerRutaDb();
    setState(() {
      _rutaLocal = rutaLocal;
      _rutaActualDb = rutaDb;
      _rutaCtrl.text = config.rutaPersonalizada ?? '';
      _cargando = false;
    });
  }

  Future<void> _seleccionarCarpeta() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Seleccionar carpeta compartida para la base de datos',
    );
    if (result != null) {
      setState(() => _rutaCtrl.text = result);
    }
  }

  Future<void> _verificarYGuardar() async {
    setState(() {
      _verificando = true;
      _mensaje = null;
    });

    final ruta = _rutaCtrl.text.trim();

    if (ruta.isEmpty) {
      // Volver a local
      await DbConfig.instance.guardarRuta(null);
      await DatabaseHelper().reconectar();
      final nuevaRuta = await DbConfig.instance.obtenerRutaDb();
      setState(() {
        _verificando = false;
        _rutaActualDb = nuevaRuta;
        _mensaje = 'Configuración guardada. Usando base de datos local.';
        _mensajeOk = true;
      });
      return;
    }

    // Verificar accesibilidad
    final accesible = await DbConfig.instance.verificarRuta(ruta);
    if (!accesible) {
      setState(() {
        _verificando = false;
        _mensaje =
            'No se puede acceder a la carpeta o no tiene permisos de escritura.\n'
            'Verificá que la carpeta compartida esté accesible desde este equipo.';
        _mensajeOk = false;
      });
      return;
    }

    // Guardar y reconectar
    await DbConfig.instance.guardarRuta(ruta);
    await DatabaseHelper().reconectar();
    final nuevaRuta = await DbConfig.instance.obtenerRutaDb();

    setState(() {
      _verificando = false;
      _rutaActualDb = nuevaRuta;
      _mensaje = 'Configuración guardada. Base de datos en carpeta compartida.\n'
          'Asegurate de configurar la misma ruta en el otro equipo.';
      _mensajeOk = true;
    });
  }

  Future<void> _diagnosticarConexion() async {
    final ruta = _rutaCtrl.text.trim();
    if (ruta.isEmpty) {
      setState(() {
        _mensaje = 'Primero indicá una carpeta de red para diagnosticar.';
        _mensajeOk = false;
      });
      return;
    }
    setState(() {
      _verificando = true;
      _mensaje = null;
    });

    final reporte = await DbConfig.instance.diagnosticar(ruta);

    if (!mounted) return;
    setState(() => _verificando = false);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              reporte.ok ? Icons.check_circle : Icons.warning_amber,
              color: reporte.ok
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFFC62828),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                reporte.ok
                    ? 'Conexi\u00F3n OK'
                    : 'Se detectaron problemas',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  'Ruta: ${reporte.ruta}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF616161)),
                ),
                const SizedBox(height: 12),
                for (final paso in reporte.pasos) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        paso.ok
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                        color: paso.ok
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFC62828),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              paso.nombre,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF212121),
                              ),
                            ),
                            const SizedBox(height: 2),
                            SelectableText(
                              paso.detalle,
                              style: TextStyle(
                                fontSize: 12,
                                color: paso.ok
                                    ? const Color(0xFF616161)
                                    : const Color(0xFFC62828),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _copiarBaseLocal() async {
    final ruta = _rutaCtrl.text.trim();
    if (ruta.isEmpty) {
      setState(() {
        _mensaje = 'Primero seleccioná una carpeta de red.';
        _mensajeOk = false;
      });
      return;
    }

    final accesible = await DbConfig.instance.verificarRuta(ruta);
    if (!accesible) {
      setState(() {
        _mensaje = 'La carpeta no es accesible.';
        _mensajeOk = false;
      });
      return;
    }

    setState(() => _verificando = true);

    try {
      final origenPath = await DbConfig.instance.obtenerRutaLocal();
      final origen = File('$origenPath${Platform.pathSeparator}inmobiliaria.db');
      final destino = File('$ruta${Platform.pathSeparator}inmobiliaria.db');

      if (!await origen.exists()) {
        setState(() {
          _verificando = false;
          _mensaje = 'No se encontró la base de datos local.';
          _mensajeOk = false;
        });
        return;
      }

      if (await destino.exists()) {
        final sobreescribir = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Base de datos existente'),
            content: const Text(
                'Ya existe una base de datos en la carpeta de red.\n'
                '¿Querés reemplazarla con la copia local?\n\n'
                'ATENCI\u00D3N: Se perder\u00E1n los datos de la copia en red.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC62828)),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Reemplazar'),
              ),
            ],
          ),
        );
        if (sobreescribir != true) {
          setState(() => _verificando = false);
          return;
        }
      }

      await origen.copy(destino.path);

      setState(() {
        _verificando = false;
        _mensaje = 'Base de datos copiada exitosamente a la carpeta de red.';
        _mensajeOk = true;
      });
    } catch (e) {
      setState(() {
        _verificando = false;
        _mensaje = 'Error al copiar: $e';
        _mensajeOk = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuraci\u00F3n de Red'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 650),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Info ──────────────────────────
                      Card(
                        color: const Color(0xFFFFF3E0),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline,
                                  color: Color(0xFFE65100), size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Para que 2 equipos compartan los datos en tiempo real, '
                                  'ambos deben apuntar a la misma carpeta compartida de red.\n\n'
                                  '1. Cre\u00E1 una carpeta compartida en la red local (ej: \\\\SERVIDOR\\CoppolaPavese)\n'
                                  '2. Configur\u00E1 la misma ruta en ambos equipos\n'
                                  '3. Si ya ten\u00E9s datos, us\u00E1 "Copiar base local a red"',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.brown.shade800,
                                      height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Estado actual ──────────────────
                      const Text('Estado actual',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF212121))),
                      const SizedBox(height: 8),
                      _fichaDato(
                        'Base de datos en:',
                        _rutaActualDb,
                        icono: _rutaCtrl.text.trim().isNotEmpty
                            ? Icons.cloud_outlined
                            : Icons.computer,
                        color: _rutaCtrl.text.trim().isNotEmpty
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFF1565C0),
                      ),
                      const SizedBox(height: 4),
                      _fichaDato(
                        'Ruta local:',
                        _rutaLocal,
                        icono: Icons.folder_outlined,
                        color: const Color(0xFF757575),
                      ),
                      const SizedBox(height: 24),

                      // ── Carpeta compartida ─────────────
                      const Text('Carpeta compartida de red',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF212121))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _rutaCtrl,
                              decoration: const InputDecoration(
                                hintText:
                                    'Ej: \\\\SERVIDOR\\CoppolaPavese  o  Z:\\CoppolaPavese',
                                isDense: true,
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.folder_shared),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            icon: const Icon(Icons.folder_open, size: 18),
                            label: const Text('Examinar'),
                            onPressed: _seleccionarCarpeta,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Botones de acción ──────────────
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            icon: _verificando
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save, size: 18),
                            label: const Text('Guardar configuraci\u00F3n'),
                            style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFC2185B)),
                            onPressed: _verificando ? null : _verificarYGuardar,
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.copy_all, size: 18),
                            label: const Text('Copiar base local a red'),
                            onPressed: _verificando ? null : _copiarBaseLocal,
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Volver a local'),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFE65100)),
                            onPressed: _verificando
                                ? null
                                : () {
                                    _rutaCtrl.clear();
                                    _verificarYGuardar();
                                  },
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.troubleshoot, size: 18),
                            label: const Text('Diagn\u00F3stico completo'),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1565C0)),
                            onPressed: _verificando ? null : _diagnosticarConexion,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Mensaje de estado ──────────────
                      if (_mensaje != null)
                        Card(
                          color: _mensajeOk == true
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFEBEE),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(
                                  _mensajeOk == true
                                      ? Icons.check_circle
                                      : Icons.error,
                                  color: _mensajeOk == true
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFFC62828),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(_mensaje!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _mensajeOk == true
                                            ? const Color(0xFF2E7D32)
                                            : const Color(0xFFC62828),
                                        height: 1.4,
                                      )),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _fichaDato(String label, String valor,
      {required IconData icono, required Color color}) {
    return Row(
      children: [
        Icon(icono, size: 18, color: color),
        const SizedBox(width: 8),
        Text('$label ', style: const TextStyle(fontSize: 12, color: Color(0xFF757575))),
        Flexible(
          child: SelectableText(
            valor,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ),
      ],
    );
  }
}
