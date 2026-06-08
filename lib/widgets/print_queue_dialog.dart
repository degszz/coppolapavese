import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/print_queue.dart';
import '../utils/snackbar_helper.dart';

/// Diálogo flotante que muestra en tiempo real las impresoras y la cola
/// de impresión de Windows. Auto-refresca cada 2 segundos.
///
/// Uso:
/// ```dart
/// showPrintQueueDialog(context);
/// ```
Future<void> showPrintQueueDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _PrintQueueDialog(),
  );
}

class _PrintQueueDialog extends StatefulWidget {
  const _PrintQueueDialog();

  @override
  State<_PrintQueueDialog> createState() => _PrintQueueDialogState();
}

class _PrintQueueDialogState extends State<_PrintQueueDialog> {
  static const _magenta = Color(0xFFC2185B);

  Timer? _timer;
  List<PrintJob> _trabajos = [];
  bool _cargando = true;
  DateTime? _ultimaActualizacion;

  @override
  void initState() {
    super.initState();
    _refrescar();
    // Auto-refresh cada 2 segundos
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refrescar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refrescar() async {
    final trabajos = await PrintQueueService.listarTrabajos();
    if (!mounted) return;
    setState(() {
      _trabajos = trabajos;
      _cargando = false;
      _ultimaActualizacion = DateTime.now();
    });
  }

  Future<void> _cancelarTrabajo(PrintJob j) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar impresión'),
        content: Text(
            '¿Cancelar "${j.document}" en ${j.printerName}?\nEsta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sí, cancelar',
                  style: TextStyle(color: Color(0xFFC62828)))),
        ],
      ),
    );
    if (confirm != true) return;

    final ok = await PrintQueueService.cancelarTrabajo(j.printerName, j.jobId);
    if (!mounted) return;
    mostrarNotificacion(context,
        texto: ok ? 'Trabajo cancelado' : 'No se pudo cancelar el trabajo',
        color: ok ? const Color(0xFF2E7D32) : const Color(0xFFC62828));
    _refrescar();
  }

  Future<void> _vaciarCola(String printerName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vaciar cola'),
        content: Text(
            '¿Cancelar TODOS los trabajos de "$printerName"?\nEsta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sí, vaciar',
                  style: TextStyle(color: Color(0xFFC62828)))),
        ],
      ),
    );
    if (confirm != true) return;

    final ok = await PrintQueueService.vaciarCola(printerName);
    if (!mounted) return;
    mostrarNotificacion(context,
        texto: ok ? 'Cola vaciada' : 'No se pudo vaciar la cola',
        color: ok ? const Color(0xFF2E7D32) : const Color(0xFFC62828));
    _refrescar();
  }

  Future<void> _reiniciarSpooler() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reiniciar servicio de impresión'),
        content: const Text(
            'Esto detiene y vuelve a iniciar el servicio Spooler de Windows.\n\n'
            'Útil cuando los trabajos se quedan trabados.\n'
            'Requiere permisos de administrador.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reiniciar')),
        ],
      ),
    );
    if (confirm != true) return;

    final ok = await PrintQueueService.reiniciarSpooler();
    if (!mounted) return;
    mostrarNotificacion(context,
        texto: ok
            ? 'Servicio reiniciado'
            : 'No se pudo reiniciar (requiere administrador)',
        color: ok ? const Color(0xFF2E7D32) : const Color(0xFFC62828));
    _refrescar();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final width = screen.width * 0.75;
    final maxW = width > 720.0 ? 720.0 : width;
    final maxH = screen.height * 0.85;

    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            const Divider(height: 1),
            Flexible(
              child: _cargando && _trabajos.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _seccionTrabajos(),
                        ],
                      ),
                    ),
            ),
            const Divider(height: 1),
            _footer(),
          ],
        ),
      ),
    );
  }

  // ── HEADER ──────────────────────────────────────────────────────
  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      decoration: const BoxDecoration(
        color: Color(0xFFFCE4EC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Row(
        children: [
          const Icon(Icons.print_outlined, color: _magenta, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Cola de impresión',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _magenta),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            color: _magenta,
            tooltip: 'Refrescar ahora',
            onPressed: _refrescar,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            color: _magenta,
            tooltip: 'Cerrar',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // ── TRABAJOS ────────────────────────────────────────────────────
  Widget _seccionTrabajos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'Trabajos en cola',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF616161),
                  letterSpacing: 0.5),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _trabajos.isEmpty
                    ? const Color(0xFFE0E0E0)
                    : _magenta,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_trabajos.length}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _trabajos.isEmpty
                        ? const Color(0xFF616161)
                        : Colors.white),
              ),
            ),
            const Spacer(),
            if (_trabajos.isNotEmpty)
              TextButton.icon(
                onPressed: () => _vaciarCola(_trabajos.first.printerName),
                icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                label: const Text('Vaciar cola'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFC62828),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_trabajos.isEmpty)
          _cartelInfo('No hay impresiones pendientes.', ok: true)
        else
          ..._trabajos.map(_tarjetaTrabajo),
      ],
    );
  }

  Widget _tarjetaTrabajo(PrintJob j) {
    final progreso = j.progreso;
    final esError = j.estadoTexto.toLowerCase().contains('error') ||
        j.estadoTexto.toLowerCase().contains('sin') ||
        j.estadoTexto.toLowerCase().contains('papel');
    final color =
        esError ? const Color(0xFFC62828) : const Color(0xFF2E7D32);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        j.document.isEmpty
                            ? '(Sin nombre) #${j.jobId}'
                            : j.document,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${j.printerName}  ·  ${j.estadoTexto}'
                        '${j.totalPages > 0 ? '  ·  ${j.pagesPrinted}/${j.totalPages} pág.' : ''}'
                        '${j.sizeBytes > 0 ? '  ·  ${_tamKb(j.sizeBytes)}' : ''}',
                        style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: esError
                                ? FontWeight.w600
                                : FontWeight.normal),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: const Color(0xFFC62828),
                  tooltip: 'Cancelar este trabajo',
                  onPressed: () => _cancelarTrabajo(j),
                ),
              ],
            ),
            if (progreso != null) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progreso,
                  minHeight: 5,
                  backgroundColor: const Color(0xFFF0F0F0),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(_magenta),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cartelInfo(String texto, {bool ok = false}) {
    final color =
        ok ? const Color(0xFF2E7D32) : const Color(0xFF1565C0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.info_outline,
              color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto,
                style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ── FOOTER ──────────────────────────────────────────────────────
  Widget _footer() {
    String actualizado = '';
    if (_ultimaActualizacion != null) {
      final hh = _ultimaActualizacion!.hour.toString().padLeft(2, '0');
      final mm = _ultimaActualizacion!.minute.toString().padLeft(2, '0');
      final ss = _ultimaActualizacion!.second.toString().padLeft(2, '0');
      actualizado = 'Actualizado $hh:$mm:$ss · refresca cada 2 s';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.autorenew, size: 14, color: Color(0xFF9E9E9E)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              actualizado,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF9E9E9E)),
            ),
          ),
          TextButton.icon(
            onPressed: _reiniciarSpooler,
            icon: const Icon(Icons.restart_alt, size: 16),
            label: const Text('Reiniciar servicio'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF616161),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _tamKb(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }
}
