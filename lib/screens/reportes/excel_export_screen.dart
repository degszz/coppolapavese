import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:ui' as ui;
import '../../database/database_helper.dart';
import '../../models/inquilino_model.dart';
import '../../models/propietario_model.dart';
import '../../utils/excel_generator.dart';

class ExcelExportScreen extends StatefulWidget {
  const ExcelExportScreen({super.key});

  @override
  State<ExcelExportScreen> createState() => _ExcelExportScreenState();
}

class _ExcelExportScreenState extends State<ExcelExportScreen> {
  final _db = DatabaseHelper();
  static const _magenta = Color(0xFFC2185B);

  // ── Filtros ────────────────────────────────────────────────────
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  PropietarioModel? _propietarioFiltro;
  InquilinoModel? _inquilinoFiltro;
  List<PropietarioModel> _propietarios = [];
  List<InquilinoModel> _inquilinos = [];

  // ── Estado ────────────────────────────────────────────────────
  bool _generandoInq = false;
  bool _generandoProp = false;
  String? _rutaArchivoInq;
  String? _rutaArchivoProp;
  Map<String, int> _estadisticas = {};
  List<_DatoMensual> _datosMensuales = [];

  final _fmtFecha = DateFormat('dd/MM/yyyy');
  final _fmtNombre = DateFormat('yyyyMMdd_HHmm');

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _cargarEstadisticas();
  }

  Future<void> _cargarDatos() async {
    final lista = await _db.obtenerPropietarios();
    final listaInq = await _db.obtenerInquilinos();
    setState(() {
      _propietarios =
          lista.map((p) => PropietarioModel.fromMap(p)).toList();
      _inquilinos =
          listaInq.map((i) => InquilinoModel.fromMap(i)).toList();
    });
  }

  Future<void> _cargarEstadisticas() async {
    final recibos = await _db.obtenerRecibosParaExcel();

    final mapasMensual = <String, int>{};
    for (final r in recibos) {
      final fecha = r['fecha_emision'] as String? ?? '';
      if (fecha.length >= 7) {
        final clave = fecha.substring(0, 7);
        mapasMensual[clave] = (mapasMensual[clave] ?? 0) + 1;
      }
    }
    const mesesEs = [
      '', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    final ahora = DateTime.now();
    final meses = <_DatoMensual>[];
    for (int i = 5; i >= 0; i--) {
      int m = ahora.month - i;
      int y = ahora.year;
      while (m < 1) { m += 12; y--; }
      final clave = '$y-${m.toString().padLeft(2, '0')}';
      meses.add(_DatoMensual(
        etiqueta: mesesEs[m],
        cantidad: mapasMensual[clave] ?? 0,
      ));
    }

    setState(() {
      _estadisticas = {
        'total': recibos.length,
        'pagados': recibos.where((r) => r['estado'] == 'pagado').length,
        'pendientes': recibos
            .where((r) =>
                r['estado'] == 'pendiente' || r['estado'] == 'parcial')
            .length,
      };
      _datosMensuales = meses;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
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
          _panelGraficas(),
          const SizedBox(height: 16),
          _panelFiltros(),
          const SizedBox(height: 20),
          // ── MÓDULO 1: REPORTE INQUILINO ──
          _moduloReporte(
            titulo: 'Reporte por Inquilino',
            icono: Icons.person_search,
            color: const Color(0xFF7B1FA2),
            descripcion: 'Inquilino, Alquiler Mes, Adm. 5% Inmob., Total Propietario, Observaciones',
            hojas: const [
              'Resumen Inquilinos',
              'Historial de Recibos',
              'Recibos Pagados',
              'Recibos Pendientes',
            ],
            generando: _generandoInq,
            rutaArchivo: _rutaArchivoInq,
            onDescargar: _descargarInquilino,
            onCompartir: _compartirInquilino,
          ),
          const SizedBox(height: 20),
          // ── MÓDULO 2: REPORTE PROPIETARIO ──
          _moduloReporte(
            titulo: 'Reporte por Propietario',
            icono: Icons.people,
            color: const Color(0xFF1565C0),
            descripcion: 'Propietario, Inquilino, Dirección, Localidad, Total Recibos, Total Facturado, Total Cobrado, Total Pendiente, Estado',
            hojas: const [
              'Resumen Propietarios',
              'Historial de Recibos',
              'Recibos Pagados',
              'Recibos Pendientes',
            ],
            generando: _generandoProp,
            rutaArchivo: _rutaArchivoProp,
            onDescargar: _descargarPropietario,
            onCompartir: _compartirPropietario,
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // WIDGET: MÓDULO DE REPORTE
  // ════════════════════════════════════════════════════════════════

  Widget _moduloReporte({
    required String titulo,
    required IconData icono,
    required Color color,
    required String descripcion,
    required List<String> hojas,
    required bool generando,
    required String? rutaArchivo,
    required VoidCallback onDescargar,
    required VoidCallback onCompartir,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icono, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: color)),
                      const SizedBox(height: 2),
                      Text(descripcion,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF757575))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Hojas incluidas
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hojas incluidas:',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF616161))),
                  const SizedBox(height: 6),
                  ...hojas.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text('${e.key + 1}',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: color)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(e.value,
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Botones
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: generando ? null : onDescargar,
                      icon: generando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.download_outlined, size: 20),
                      label: Text(
                        generando ? 'Generando...' : 'Descargar',
                        style: const TextStyle(fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: generando ? null : onCompartir,
                      icon: const Icon(Icons.share_outlined, size: 20),
                      label: const Text('Compartir',
                          style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: color,
                        side: BorderSide(color: color),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Archivo generado
            if (rutaArchivo != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF2E7D32).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Color(0xFF2E7D32), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rutaArchivo,
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF757575)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _abrirCarpeta(rutaArchivo),
                      child: const Icon(Icons.folder_open,
                          color: Color(0xFF2E7D32), size: 18),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // LÓGICA — OBTENER RECIBOS FILTRADOS
  // ════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> _obtenerRecibosFiltrados() async {
    return await _db.obtenerRecibosParaExcel(
      fechaDesde: _fechaDesde != null
          ? DateFormat('yyyy-MM-dd').format(_fechaDesde!)
          : null,
      fechaHasta: _fechaHasta != null
          ? DateFormat('yyyy-MM-dd').format(_fechaHasta!)
          : null,
      propietarioId: _propietarioFiltro?.id,
      inquilinoId: _inquilinoFiltro?.id,
    );
  }

  // ── REPORTE INQUILINO ─────────────────────────────────────────

  Future<void> _descargarInquilino() async {
    setState(() => _generandoInq = true);
    try {
      final recibos = await _obtenerRecibosFiltrados();
      if (recibos.isEmpty) {
        _mostrarSinDatos();
        return;
      }
      final bytes = await ExcelGenerator.generarExcelInquilino(
          recibos: recibos);
      final ruta = await _guardarArchivo(bytes, 'Inquilinos');
      setState(() => _rutaArchivoInq = ruta);
      _mostrarExito(ruta);
    } catch (e) {
      _mostrarError(e);
    } finally {
      if (mounted) setState(() => _generandoInq = false);
    }
  }

  Future<void> _compartirInquilino() async {
    setState(() => _generandoInq = true);
    try {
      final recibos = await _obtenerRecibosFiltrados();
      if (recibos.isEmpty) {
        _mostrarSinDatos();
        return;
      }
      final bytes = await ExcelGenerator.generarExcelInquilino(
          recibos: recibos);
      await _compartirBytes(bytes, 'Inquilinos');
    } catch (e) {
      _mostrarError(e);
    } finally {
      if (mounted) setState(() => _generandoInq = false);
    }
  }

  // ── REPORTE PROPIETARIO ───────────────────────────────────────

  Future<void> _descargarPropietario() async {
    setState(() => _generandoProp = true);
    try {
      final recibos = await _obtenerRecibosFiltrados();
      if (recibos.isEmpty) {
        _mostrarSinDatos();
        return;
      }
      final resumen = _construirResumenPropietario(recibos);
      final bytes = await ExcelGenerator.generarExcelPropietario(
        resumenPropietarios: resumen,
        recibos: recibos,
      );
      final ruta = await _guardarArchivo(bytes, 'Propietarios');
      setState(() => _rutaArchivoProp = ruta);
      _mostrarExito(ruta);
    } catch (e) {
      _mostrarError(e);
    } finally {
      if (mounted) setState(() => _generandoProp = false);
    }
  }

  Future<void> _compartirPropietario() async {
    setState(() => _generandoProp = true);
    try {
      final recibos = await _obtenerRecibosFiltrados();
      if (recibos.isEmpty) {
        _mostrarSinDatos();
        return;
      }
      final resumen = _construirResumenPropietario(recibos);
      final bytes = await ExcelGenerator.generarExcelPropietario(
        resumenPropietarios: resumen,
        recibos: recibos,
      );
      await _compartirBytes(bytes, 'Propietarios');
    } catch (e) {
      _mostrarError(e);
    } finally {
      if (mounted) setState(() => _generandoProp = false);
    }
  }

  List<Map<String, dynamic>> _construirResumenPropietario(
      List<Map<String, dynamic>> recibos) {
    final mapa = <int, Map<String, dynamic>>{};
    for (final r in recibos) {
      final pid = r['propietario_id'] as int? ?? 0;
      if (!mapa.containsKey(pid)) {
        mapa[pid] = {
          'propietario_nombre': r['propietario_nombre'] ?? '',
          'inquilino_nombre': r['inquilino_nombre'] ?? '',
          'direccion': r['direccion'] ?? '',
          'localidad': r['localidad'] ?? '',
          'total_recibos': 0,
          'total_monto': 0.0,
          'total_cobrado': 0.0,
          'total_pendiente': 0.0,
        };
      }
      final e = mapa[pid]!;
      e['total_recibos'] = (e['total_recibos'] as int) + 1;
      e['total_monto'] = (e['total_monto'] as double) +
          ((r['monto_total'] as num?)?.toDouble() ?? 0.0);
      e['total_cobrado'] = (e['total_cobrado'] as double) +
          ((r['monto_abonado'] as num?)?.toDouble() ?? 0.0);
      e['total_pendiente'] = (e['total_pendiente'] as double) +
          ((r['saldo'] as num?)?.toDouble() ?? 0.0);
    }
    return mapa.values.toList();
  }

  // ════════════════════════════════════════════════════════════════
  // HELPERS — ARCHIVO / UI
  // ════════════════════════════════════════════════════════════════

  void _mostrarSinDatos() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('No se encontraron recibos con los filtros seleccionados.'),
          backgroundColor: Color(0xFFF57C00),
        ),
      );
    }
  }

  void _mostrarExito(String ruta) {
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
  }

  void _mostrarError(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar Excel: $e'),
          backgroundColor: const Color(0xFFC62828),
        ),
      );
    }
  }

  Future<String> _guardarArchivo(List<int> bytes, String tipo) async {
    final nombre =
        'CoppolaPavese_${tipo}_${_fmtNombre.format(DateTime.now())}.xlsx';
    final dir = await _obtenerDirectorio();
    final archivo = File('${dir.path}/$nombre');
    await archivo.writeAsBytes(bytes);
    return archivo.path;
  }

  Future<void> _compartirBytes(List<int> bytes, String tipo) async {
    final dir = await getTemporaryDirectory();
    final nombre =
        'CoppolaPavese_${tipo}_${_fmtNombre.format(DateTime.now())}.xlsx';
    final archivo = File('${dir.path}/$nombre');
    await archivo.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(archivo.path)],
      text: 'Reporte $tipo — Coppola Pavese Inmobiliaria',
    );
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

  // ════════════════════════════════════════════════════════════════
  // PANELES UI
  // ════════════════════════════════════════════════════════════════

  Widget _panelEstadisticas() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tituloSeccion(
                'Resumen de la Base de Datos', Icons.bar_chart_outlined),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _statCard('${_estadisticas['total'] ?? 0}',
                        'Total Recibos', Icons.receipt_long, const Color(0xFF1565C0))),
                const SizedBox(width: 10),
                Expanded(
                    child: _statCard('${_estadisticas['pagados'] ?? 0}',
                        'Pagados', Icons.check_circle_outline, const Color(0xFF2E7D32))),
                const SizedBox(width: 10),
                Expanded(
                    child: _statCard('${_estadisticas['pendientes'] ?? 0}',
                        'Pendientes', Icons.pending_actions_outlined, const Color(0xFFC62828))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String valor, String label, IconData icono, Color color) {
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
                  fontWeight: FontWeight.bold, fontSize: 18, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF757575)),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _panelFiltros() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tituloSeccion('Filtros (aplican a ambos reportes)', Icons.filter_list),
            const SizedBox(height: 12),
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
            DropdownButtonFormField<PropietarioModel?>(
              value: _propietarioFiltro,
              decoration: const InputDecoration(
                labelText: 'Propietario (opcional)',
                prefixIcon: Icon(Icons.person_outline),
              ),
              items: [
                const DropdownMenuItem<PropietarioModel?>(
                    value: null, child: Text('Todos los propietarios')),
                ..._propietarios.map((p) =>
                    DropdownMenuItem(value: p, child: Text(p.nombre))),
              ],
              onChanged: (p) => setState(() => _propietarioFiltro = p),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<InquilinoModel?>(
              value: _inquilinoFiltro,
              decoration: const InputDecoration(
                labelText: 'Inquilino (opcional)',
                prefixIcon: Icon(Icons.person_search_outlined),
              ),
              items: [
                const DropdownMenuItem<InquilinoModel?>(
                    value: null, child: Text('Todos los inquilinos')),
                ..._inquilinos.map((i) => DropdownMenuItem(
                    value: i, child: Text(i.nombreCompleto))),
              ],
              onChanged: (i) => setState(() => _inquilinoFiltro = i),
            ),
            const SizedBox(height: 10),
            if (_fechaDesde != null ||
                _fechaHasta != null ||
                _propietarioFiltro != null ||
                _inquilinoFiltro != null)
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

  Future<void> _elegirFecha({required bool esDesde}) async {
    final inicial = esDesde
        ? (_fechaDesde ?? DateTime.now())
        : (_fechaHasta ?? DateTime.now());
    final sel = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _magenta)),
        child: child!,
      ),
    );
    if (sel == null) return;
    setState(() {
      if (esDesde) _fechaDesde = sel; else _fechaHasta = sel;
    });
  }

  void _limpiarFiltros() {
    setState(() {
      _fechaDesde = null;
      _fechaHasta = null;
      _propietarioFiltro = null;
      _inquilinoFiltro = null;
    });
  }

  Widget _tituloSeccion(String texto, IconData icono) {
    return Row(
      children: [
        Icon(icono, size: 17, color: _magenta),
        const SizedBox(width: 8),
        Text(texto,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: _magenta)),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFBDBDBD)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 15, color: _magenta),
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
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child:
                    const Icon(Icons.close, size: 16, color: Color(0xFF9E9E9E)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _panelGraficas() {
    final total = _estadisticas['total'] ?? 0;
    final pagados = _estadisticas['pagados'] ?? 0;
    final pendientes = _estadisticas['pendientes'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tituloSeccion('Graficas', Icons.pie_chart_outline),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text('Estado de Recibos',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 160,
                        child: CustomPaint(
                          painter: _DonutChartPainter(
                              pagados: pagados,
                              pendientes: pendientes,
                              total: total),
                          size: Size.infinite,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _leyenda(
                              const Color(0xFF2E7D32), 'Pagados ($pagados)'),
                          const SizedBox(width: 12),
                          _leyenda(const Color(0xFFC62828),
                              'Pendientes ($pendientes)'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: [
                      const Text('Recibos por Mes (ultimos 6)',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 160,
                        child: _datosMensuales.isEmpty
                            ? const Center(
                                child: Text('Sin datos',
                                    style:
                                        TextStyle(color: Color(0xFF9E9E9E))))
                            : CustomPaint(
                                painter:
                                    _BarChartPainter(datos: _datosMensuales),
                                size: Size.infinite,
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _leyenda(Color color, String texto) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(texto, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

// ── Painters ──────────────────────────────────────────────────────────────────

class _DatoMensual {
  final String etiqueta;
  final int cantidad;
  const _DatoMensual({required this.etiqueta, required this.cantidad});
}

class _DonutChartPainter extends CustomPainter {
  final int pagados, pendientes, total;
  const _DonutChartPainter(
      {required this.pagados, required this.pendientes, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 16;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26
      ..strokeCap = StrokeCap.butt;

    const twoPi = 6.283185307179586;
    const startAngle = -1.5707963267948966;

    if (total == 0) {
      paint.color = const Color(0xFFEEEEEE);
      canvas.drawArc(rect, startAngle, twoPi, false, paint);
    } else {
      final pagadosAngle = (pagados / total) * twoPi;
      final pendientesAngle = (pendientes / total) * twoPi;
      paint.color = const Color(0xFF2E7D32);
      canvas.drawArc(rect, startAngle, pagadosAngle, false, paint);
      paint.color = const Color(0xFFC62828);
      canvas.drawArc(
          rect, startAngle + pagadosAngle, pendientesAngle, false, paint);
    }

    final pct = total > 0 ? (pagados * 100 / total).round() : 0;
    final tp = TextPainter(
      text: TextSpan(children: [
        TextSpan(
            text: '$pct%\n',
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
                height: 1.1)),
        const TextSpan(
            text: 'pagados',
            style: TextStyle(fontSize: 10, color: Color(0xFF9E9E9E))),
      ]),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_DonutChartPainter old) =>
      old.pagados != pagados ||
      old.pendientes != pendientes ||
      old.total != total;
}

class _BarChartPainter extends CustomPainter {
  final List<_DatoMensual> datos;
  _BarChartPainter({required this.datos});

  @override
  void paint(Canvas canvas, Size size) {
    if (datos.isEmpty) return;
    final maxVal =
        datos.map((d) => d.cantidad).reduce((a, b) => a > b ? a : b);
    final barPaint = Paint()..color = const Color(0xFFC2185B);
    final emptyPaint = Paint()..color = const Color(0xFFEEEEEE);
    final tp = TextPainter(textDirection: ui.TextDirection.ltr);

    final slotW = size.width / datos.length;
    final barW = slotW * 0.55;
    const topPad = 18.0;
    const bottomPad = 22.0;
    final maxBarH = size.height - topPad - bottomPad;

    for (int i = 0; i < datos.length; i++) {
      final d = datos[i];
      final x = i * slotW + (slotW - barW) / 2;

      if (maxVal == 0) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(x, topPad, barW, maxBarH),
                const Radius.circular(4)),
            emptyPaint);
      } else {
        final barH = (d.cantidad / maxVal) * maxBarH;
        final y = topPad + (maxBarH - barH);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(x, y, barW, barH), const Radius.circular(4)),
            barPaint);
        if (d.cantidad > 0) {
          tp.text = TextSpan(
              text: '${d.cantidad}',
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF424242)));
          tp.layout();
          tp.paint(
              canvas, Offset(x + (barW - tp.width) / 2, y - topPad + 2));
        }
      }
      tp.text = TextSpan(
          text: d.etiqueta,
          style: const TextStyle(fontSize: 10, color: Color(0xFF757575)));
      tp.layout();
      tp.paint(canvas,
          Offset(x + (barW - tp.width) / 2, size.height - bottomPad + 4));
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) => old.datos != datos;
}
