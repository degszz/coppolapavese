import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../database/database_helper.dart';
import '../../models/propietario_model.dart';
import '../../utils/excel_generator.dart';

class ExcelExportScreen extends StatefulWidget {
  const ExcelExportScreen({super.key});

  @override
  State<ExcelExportScreen> createState() => _ExcelExportScreenState();
}

class _ExcelExportScreenState extends State<ExcelExportScreen> {
  final _db = DatabaseHelper();

  // ── Filtros ────────────────────────────────────────────────────
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  PropietarioModel? _propietarioFiltro;
  List<PropietarioModel> _propietarios = [];

  // ── Estado ────────────────────────────────────────────────────
  bool _generando = false;
  String? _rutaArchivo;
  Map<String, int> _estadisticas = {};

  final _fmtFecha = DateFormat('dd/MM/yyyy');
  final _fmtNombre = DateFormat('yyyyMMdd_HHmm');

  @override
  void initState() {
    super.initState();
    _cargarPropietarios();
    _cargarEstadisticas();
  }

  Future<void> _cargarPropietarios() async {
    final lista = await _db.obtenerPropietarios();
    setState(() {
      _propietarios =
          lista.map((p) => PropietarioModel.fromMap(p)).toList();
    });
  }

  Future<void> _cargarEstadisticas() async {
    final recibos = await _db.obtenerRecibosParaExcel();
    setState(() {
      _estadisticas = {
        'total': recibos.length,
        'pagados':
            recibos.where((r) => r['estado'] == 'pagado').length,
        'pendientes': recibos
            .where((r) =>
                r['estado'] == 'pendiente' ||
                r['estado'] == 'parcial')
            .length,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exportar a Excel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarEstadisticas,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _panelEstadisticas(),
          const SizedBox(height: 16),
          _panelFiltros(),
          const SizedBox(height: 16),
          _panelContenidoExcel(),
          const SizedBox(height: 16),
          _botonesAccion(),
          if (_rutaArchivo != null) ...[
            const SizedBox(height: 16),
            _panelArchivoGenerado(),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ── Panel de estadísticas previas ──────────────────────────────
  Widget _panelEstadisticas() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tituloSeccion('Resumen de la Base de Datos',
                Icons.bar_chart_outlined),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    '${_estadisticas['total'] ?? 0}',
                    'Total Recibos',
                    Icons.receipt_long,
                    const Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard(
                    '${_estadisticas['pagados'] ?? 0}',
                    'Pagados',
                    Icons.check_circle_outline,
                    const Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard(
                    '${_estadisticas['pendientes'] ?? 0}',
                    'Pendientes',
                    Icons.pending_actions_outlined,
                    const Color(0xFFC62828),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(
      String valor, String label, IconData icono, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icono, color: color, size: 22),
          const SizedBox(height: 4),
          Text(valor,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: Color(0xFF757575)),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ── Panel de filtros ───────────────────────────────────────────
  Widget _panelFiltros() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tituloSeccion('Filtros (Opcionales)', Icons.filter_list),
            const SizedBox(height: 12),

            // Rango de fechas
            Row(
              children: [
                Expanded(
                  child: _selectorFecha(
                    label: 'Desde',
                    fecha: _fechaDesde != null
                        ? _fmtFecha.format(_fechaDesde!)
                        : 'Sin filtro',
                    onTap: () => _elegirFecha(esDesde: true),
                    onClear: _fechaDesde != null
                        ? () => setState(() => _fechaDesde = null)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _selectorFecha(
                    label: 'Hasta',
                    fecha: _fechaHasta != null
                        ? _fmtFecha.format(_fechaHasta!)
                        : 'Sin filtro',
                    onTap: () => _elegirFecha(esDesde: false),
                    onClear: _fechaHasta != null
                        ? () => setState(() => _fechaHasta = null)
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Filtro por propietario
            DropdownButtonFormField<PropietarioModel?>(
              value: _propietarioFiltro,
              decoration: const InputDecoration(
                labelText: 'Propietario (opcional)',
                prefixIcon: Icon(Icons.person_outline),
              ),
              items: [
                const DropdownMenuItem<PropietarioModel?>(
                  value: null,
                  child: Text('Todos los propietarios'),
                ),
                ..._propietarios.map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p.nombre),
                    )),
              ],
              onChanged: (p) =>
                  setState(() => _propietarioFiltro = p),
            ),
            const SizedBox(height: 10),

            // Botón limpiar filtros
            if (_fechaDesde != null ||
                _fechaHasta != null ||
                _propietarioFiltro != null)
              TextButton.icon(
                onPressed: _limpiarFiltros,
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Limpiar filtros'),
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF757575)),
              ),
          ],
        ),
      ),
    );
  }

  // ── Panel descripción de hojas ────────────────────────────────
  Widget _panelContenidoExcel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tituloSeccion('Contenido del Excel', Icons.table_chart_outlined),
            const SizedBox(height: 12),
            _hojaItem(
              '1',
              'Resumen General',
              'Una fila por propietario con totales',
              const Color(0xFFC2185B),
            ),
            _hojaItem(
              '2',
              'Historial de Recibos',
              'Todos los recibos ordenados por fecha',
              const Color(0xFF1565C0),
            ),
            _hojaItem(
              '3',
              'Recibos Pagados',
              'Solo recibos con estado = Pagado',
              const Color(0xFF2E7D32),
            ),
            _hojaItem(
              '4',
              'Recibos Pendientes',
              'Recibos con estado Pendiente o Parcial',
              const Color(0xFFF57C00),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hojaItem(
      String num, String titulo, String desc, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(num,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 13)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: color)),
                Text(desc,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF757575))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Botones de acción ─────────────────────────────────────────
  Widget _botonesAccion() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _generando ? null : _generarYDescargar,
            icon: _generando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download_outlined),
            label: Text(
              _generando ? 'Generando Excel...' : 'Generar y Descargar Excel',
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _generando ? null : _generarYCompartir,
            icon: const Icon(Icons.share_outlined),
            label: const Text('Compartir Excel',
                style: TextStyle(fontSize: 15)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFC2185B),
              side: const BorderSide(color: Color(0xFFC2185B)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Panel archivo generado ────────────────────────────────────
  Widget _panelArchivoGenerado() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFF2E7D32).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle,
              color: Color(0xFF2E7D32), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Archivo generado',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32))),
                Text(
                  _rutaArchivo ?? '',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF757575)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share,
                color: Color(0xFFC2185B)),
            onPressed: () => _compartirArchivo(_rutaArchivo!),
            tooltip: 'Compartir',
          ),
        ],
      ),
    );
  }

  // ── Lógica de generación ──────────────────────────────────────

  Future<List<int>> _obtenerDatosYGenerar() async {
    final resumen = await _db.obtenerResumenPorPropietario();
    final recibos = await _db.obtenerRecibosParaExcel(
      fechaDesde: _fechaDesde != null
          ? DateFormat('yyyy-MM-dd').format(_fechaDesde!)
          : null,
      fechaHasta: _fechaHasta != null
          ? DateFormat('yyyy-MM-dd').format(_fechaHasta!)
          : null,
      propietarioId: _propietarioFiltro?.id,
    );

    return ExcelGenerator.generarExcel(
      resumenPropietarios: resumen,
      todosLosRecibos: recibos,
    );
  }

  Future<void> _generarYDescargar() async {
    setState(() => _generando = true);
    try {
      final bytes = await _obtenerDatosYGenerar();
      final ruta = await _guardarArchivo(bytes);
      setState(() => _rutaArchivo = ruta);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel guardado en: $ruta'),
            backgroundColor: const Color(0xFF2E7D32),
            action: SnackBarAction(
              label: 'ABRIR CARPETA',
              textColor: Colors.white,
              onPressed: () => _abrirCarpeta(ruta),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar Excel: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  Future<void> _generarYCompartir() async {
    setState(() => _generando = true);
    try {
      final bytes = await _obtenerDatosYGenerar();
      final dir = await getTemporaryDirectory();
      final nombre =
          'CoppolaPavese_${_fmtNombre.format(DateTime.now())}.xlsx';
      final archivo = File('${dir.path}/$nombre');
      await archivo.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(archivo.path)],
        text: 'Reporte Excel — Coppola Pavese Inmobiliaria',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  Future<String> _guardarArchivo(List<int> bytes) async {
    final nombre =
        'CoppolaPavese_${_fmtNombre.format(DateTime.now())}.xlsx';
    final dir = await _obtenerDirectorio();
    final archivo = File('${dir.path}/$nombre');
    await archivo.writeAsBytes(bytes);
    return archivo.path;
  }

  Future<Directory> _obtenerDirectorio() async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final docs = await getApplicationDocumentsDirectory();
      final carpeta = Directory('${docs.path}\\CoppolaPavese');
      if (!await carpeta.exists()) await carpeta.create(recursive: true);
      return carpeta;
    } else if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) return dir;
      return (await getExternalStorageDirectory()) ??
          await getApplicationDocumentsDirectory();
    } else {
      return await getApplicationDocumentsDirectory();
    }
  }

  void _abrirCarpeta(String ruta) {
    final carpeta = File(ruta).parent.path;
    if (Platform.isWindows) {
      Process.run('explorer', [carpeta]);
    } else if (Platform.isMacOS) {
      Process.run('open', [carpeta]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [carpeta]);
    }
  }

  Future<void> _compartirArchivo(String ruta) async {
    await Share.shareXFiles(
      [XFile(ruta)],
      text: 'Reporte Excel — Coppola Pavese Inmobiliaria',
    );
  }

  // ── Helpers UI ────────────────────────────────────────────────

  Future<void> _elegirFecha({required bool esDesde}) async {
    final inicial =
        esDesde ? (_fechaDesde ?? DateTime.now()) : (_fechaHasta ?? DateTime.now());
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFC2185B),
          ),
        ),
        child: child!,
      ),
    );
    if (seleccionada == null) return;
    setState(() {
      if (esDesde) {
        _fechaDesde = seleccionada;
      } else {
        _fechaHasta = seleccionada;
      }
    });
  }

  void _limpiarFiltros() {
    setState(() {
      _fechaDesde = null;
      _fechaHasta = null;
      _propietarioFiltro = null;
    });
  }

  Widget _tituloSeccion(String texto, IconData icono) {
    return Row(
      children: [
        Icon(icono, size: 17, color: const Color(0xFFC2185B)),
        const SizedBox(width: 8),
        Text(
          texto,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFFC2185B),
          ),
        ),
      ],
    );
  }

  Widget _selectorFecha({
    required String label,
    required String fecha,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFBDBDBD)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                size: 15, color: Color(0xFFC2185B)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 9, color: Color(0xFF9E9E9E))),
                  Text(fecha,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close,
                    size: 16, color: Color(0xFF9E9E9E)),
              ),
          ],
        ),
      ),
    );
  }
}
