import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;
import '../../database/database_helper.dart';
import '../../utils/excel_generator.dart';
import '../../utils/pdf_generator.dart';
import '../../utils/snackbar_helper.dart';

class ExcelExportScreen extends StatefulWidget {
  const ExcelExportScreen({super.key});

  @override
  State<ExcelExportScreen> createState() => _ExcelExportScreenState();
}

class _ExcelExportScreenState extends State<ExcelExportScreen> {
  final _db = DatabaseHelper();
  static const _magenta = Color(0xFFC2185B);

  // ── Estado ────────────────────────────────────────────────────
  static bool _autenticado = false;
  final _passCtrl = TextEditingController();
  String? _passError;
  bool _generandoProp = false;
  String? _rutaArchivoProp;
  Map<String, int> _estadisticas = {};
  Map<String, int> _conteoGeneral = {};
  double _cobradoMes = 0.0;
  double _pendienteTotal = 0.0;
  List<_DatoMensual> _datosMensuales = [];
  List<_DatoFinanciero> _datosFinancieros = [];
  List<_DatoContratos> _datosContratos = [];

  // ── Filtros ───────────────────────────────────────────────────
  DateTime? _filtroDesde;
  DateTime? _filtroHasta;
  int? _filtroPropietarioId;
  List<Map<String, dynamic>> _propietarios = [];
  List<Map<String, dynamic>> _propiedadesDelPropietario = [];
  Set<int> _propiedadesSeleccionadas = {};

  final _fmtNombre = DateFormat('yyyyMMdd_HHmm');
  final _fmtMes = DateFormat('MM/yyyy');

  @override
  void initState() {
    super.initState();
    _cargarEstadisticas();
    _cargarPropietarios();
  }

  Future<void> _cargarPropietarios() async {
    final props = await _db.obtenerPropietarios();
    if (mounted) setState(() => _propietarios = props);
  }

  Future<void> _cargarPropiedadesDelPropietario(int propietarioId) async {
    final props =
        await _db.obtenerPropiedadesDeContratosPorPropietario(propietarioId);
    if (mounted) {
      setState(() {
        _propiedadesDelPropietario = props;
        _propiedadesSeleccionadas =
            props.map((p) => p['id'] as int).toSet(); // todas seleccionadas
      });
    }
  }

  Future<void> _cargarEstadisticas() async {
    final recibos = await _db.obtenerRecibosParaExcel();
    final stats = await _db.obtenerEstadisticasGenerales();
    final financieros = await _db.obtenerDatosMensuales(meses: 12);
    final conteo = await _db.obtenerConteoGeneral();
    final contratosPorMes = await _db.obtenerContratosPorMes(meses: 12);

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

    // Datos financieros para gráfica de línea
    final datFin = <_DatoFinanciero>[];
    for (final f in financieros) {
      final mesStr = f['mes'] as String? ?? '';
      if (mesStr.length >= 7) {
        final partes = mesStr.split('-');
        final mesNum = int.tryParse(partes[1]) ?? 1;
        datFin.add(_DatoFinanciero(
          etiqueta: '${mesesEs[mesNum]} ${partes[0].substring(2)}',
          emitido: (f['total_emitido'] as num?)?.toDouble() ?? 0,
          cobrado: (f['total_cobrado'] as num?)?.toDouble() ?? 0,
        ));
      }
    }

    // Contratos por mes para gráfica
    final datContr = <_DatoContratos>[];
    for (final c in contratosPorMes) {
      final mesStr = c['mes'] as String? ?? '';
      if (mesStr.length >= 7) {
        final partes = mesStr.split('-');
        final mesNum = int.tryParse(partes[1]) ?? 1;
        datContr.add(_DatoContratos(
          etiqueta: '${mesesEs[mesNum]} ${partes[0].substring(2)}',
          cantidad: (c['cantidad'] as int?) ?? 0,
        ));
      }
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
      _conteoGeneral = conteo;
      _cobradoMes = (stats['cobrado_mes'] as num?)?.toDouble() ?? 0.0;
      _pendienteTotal = (stats['pendiente_total'] as num?)?.toDouble() ?? 0.0;
      _datosMensuales = meses;
      _datosFinancieros = datFin;
      _datosContratos = datContr;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_autenticado) return _pantallaPassword();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_outline, size: 20),
            onPressed: () => setState(() {
              _autenticado = false;
              _passCtrl.clear();
              _passError = null;
            }),
            tooltip: 'Bloquear reportes',
          ),
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
          // ── Resumen de la app ──
          _panelResumenApp(),
          const SizedBox(height: 12),
          // ── Resumen financiero ──
          _panelResumenCompacto(),
          const SizedBox(height: 12),
          // ── Reporte propietarios + Filtros lado a lado ──
          _panelReporteConFiltros(),
          const SizedBox(height: 12),
          // ── Gráficas abajo del reporte ──
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _panelGraficas()),
                const SizedBox(width: 12),
                Expanded(child: _panelGraficaContratos()),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // PANEL: REPORTE + FILTROS
  // ════════════════════════════════════════════════════════════════

  Widget _panelReporteConFiltros() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reporte card (izquierda)
        Expanded(
          flex: 3,
          child: _moduloReporte(
            titulo: 'Reporte por Propietario',
            icono: Icons.people,
            color: const Color(0xFF1565C0),
            descripcion:
                'Inquilino, Propiedad, Alquiler Mes,\n10% Administración, Total Propietario, Observaciones',
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
        ),
        const SizedBox(width: 12),
        // Filtros (derecha)
        Expanded(
          flex: 2,
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.filter_list,
                            color: Color(0xFF1565C0), size: 18),
                      ),
                      const SizedBox(width: 8),
                      const Text('Filtros (Opcional)',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1565C0))),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Desde mes
                  InkWell(
                    onTap: () => _elegirMes(esDesde: true),
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Desde mes',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        suffixIcon: _filtroDesde != null
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () => setState(() {
                                  _filtroDesde = null;
                                }),
                              )
                            : const Icon(Icons.calendar_month, size: 16),
                      ),
                      child: Text(
                        _filtroDesde != null
                            ? _fmtMes.format(_filtroDesde!)
                            : 'Todos',
                        style: TextStyle(
                            fontSize: 13,
                            color: _filtroDesde != null
                                ? Colors.black
                                : const Color(0xFF9E9E9E)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Hasta mes
                  InkWell(
                    onTap: () => _elegirMes(esDesde: false),
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Hasta mes',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        suffixIcon: _filtroHasta != null
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () => setState(() {
                                  _filtroHasta = null;
                                }),
                              )
                            : const Icon(Icons.calendar_month, size: 16),
                      ),
                      child: Text(
                        _filtroHasta != null
                            ? _fmtMes.format(_filtroHasta!)
                            : 'Todos',
                        style: TextStyle(
                            fontSize: 13,
                            color: _filtroHasta != null
                                ? Colors.black
                                : const Color(0xFF9E9E9E)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Propietario dropdown
                  DropdownButtonFormField<int?>(
                    value: _filtroPropietarioId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Propietario',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Todos los propietarios',
                            style: TextStyle(fontSize: 12)),
                      ),
                      ..._propietarios.map((p) => DropdownMenuItem<int?>(
                            value: p['id'] as int,
                            child: Text(
                                p['nombre'] as String? ?? 'Sin nombre',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _filtroPropietarioId = v;
                        _propiedadesDelPropietario = [];
                        _propiedadesSeleccionadas = {};
                      });
                      if (v != null) _cargarPropiedadesDelPropietario(v);
                    },
                  ),
                  // Propiedades del propietario seleccionado
                  if (_filtroPropietarioId != null &&
                      _propiedadesDelPropietario.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('Propiedades:',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF424242))),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children:
                          _propiedadesDelPropietario.map((prop) {
                        final id = prop['id'] as int;
                        final dir = prop['direccion'] as String? ?? '';
                        final loc = prop['localidad'] as String? ?? '';
                        final label =
                            loc.isNotEmpty ? '$dir, $loc' : dir;
                        final selected =
                            _propiedadesSeleccionadas.contains(id);
                        return FilterChip(
                          label: Text(label,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: selected
                                      ? Colors.white
                                      : const Color(0xFF424242))),
                          selected: selected,
                          selectedColor: const Color(0xFF1565C0),
                          checkmarkColor: Colors.white,
                          backgroundColor:
                              const Color(0xFF1565C0).withValues(alpha: 0.08),
                          side: BorderSide(
                              color: const Color(0xFF1565C0)
                                  .withValues(alpha: 0.3)),
                          onSelected: (sel) {
                            setState(() {
                              if (sel) {
                                _propiedadesSeleccionadas.add(id);
                              } else {
                                _propiedadesSeleccionadas.remove(id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 14),
                  // Botón limpiar filtros
                  if (_filtroDesde != null ||
                      _filtroHasta != null ||
                      _filtroPropietarioId != null)
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () => setState(() {
                          _filtroDesde = null;
                          _filtroHasta = null;
                          _filtroPropietarioId = null;
                          _propiedadesDelPropietario = [];
                          _propiedadesSeleccionadas = {};
                        }),
                        icon: const Icon(Icons.clear_all, size: 16),
                        label: const Text('Limpiar filtros',
                            style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFC62828)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _elegirMes({required bool esDesde}) async {
    final ahora = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: esDesde ? (_filtroDesde ?? ahora) : (_filtroHasta ?? ahora),
      firstDate: DateTime(2020),
      lastDate: DateTime(ahora.year + 2),
      locale: const Locale('es'),
    );
    if (fecha != null && mounted) {
      setState(() {
        // Normalizar al primer día del mes
        final mesNorm = DateTime(fecha.year, fecha.month, 1);
        if (esDesde) {
          _filtroDesde = mesNorm;
        } else {
          _filtroHasta = DateTime(fecha.year, fecha.month + 1, 0);
        }
      });
    }
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
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icono, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(titulo,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(descripcion,
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF757575), height: 1.4)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: hojas.asMap().entries.map((e) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${e.key + 1}. ${e.value}',
                    style: TextStyle(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.w500)),
              )).toList(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton.icon(
                onPressed: generando ? null : onDescargar,
                icon: generando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_outlined, size: 18),
                label: Text(generando ? 'Generando...' : 'Descargar',
                    style: const TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton.icon(
                onPressed: generando ? null : onCompartir,
                icon: const Icon(Icons.chat_outlined, size: 18),
                label:
                    const Text('WhatsApp', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            if (rutaArchivo != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFF2E7D32).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: const Color(0xFF2E7D32)
                          .withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Color(0xFF2E7D32), size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(rutaArchivo,
                          style: const TextStyle(
                              fontSize: 9, color: Color(0xFF757575)),
                          overflow: TextOverflow.ellipsis),
                    ),
                    GestureDetector(
                      onTap: () => _abrirCarpeta(rutaArchivo),
                      child: const Icon(Icons.folder_open,
                          color: Color(0xFF2E7D32), size: 14),
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

  // ── REPORTE PROPIETARIO ───────────────────────────────────────

  /// Obtener recibos filtrados (con filtro de propiedades si aplica)
  Future<List<Map<String, dynamic>>> _obtenerRecibosFiltrados() async {
    var recibos = await _db.obtenerRecibosParaExcel(
      fechaDesde: _filtroDesde?.toIso8601String(),
      fechaHasta: _filtroHasta?.toIso8601String(),
      propietarioId: _filtroPropietarioId,
    );
    // Filtrar por propiedades seleccionadas si hay filtro activo
    if (_filtroPropietarioId != null &&
        _propiedadesDelPropietario.isNotEmpty &&
        _propiedadesSeleccionadas.length <
            _propiedadesDelPropietario.length) {
      // Solo filtrar si no están todas seleccionadas
      final dirSeleccionadas = _propiedadesDelPropietario
          .where((p) => _propiedadesSeleccionadas.contains(p['id'] as int))
          .map((p) => p['direccion'] as String? ?? '')
          .toSet();
      recibos = recibos
          .where((r) =>
              dirSeleccionadas.contains(r['direccion'] as String? ?? ''))
          .toList();
    }
    return recibos;
  }

  String? _obtenerNombrePropietario() {
    if (_filtroPropietarioId == null) return null;
    final prop = _propietarios.firstWhere(
        (p) => p['id'] == _filtroPropietarioId,
        orElse: () => {});
    return prop['nombre'] as String?;
  }

  String? _obtenerTelefonoPropietario() {
    if (_filtroPropietarioId == null) return null;
    final prop = _propietarios.firstWhere(
        (p) => p['id'] == _filtroPropietarioId,
        orElse: () => {});
    return prop['telefono'] as String?;
  }

  Future<void> _descargarPropietario() async {
    setState(() => _generandoProp = true);
    try {
      final recibos = await _obtenerRecibosFiltrados();
      if (recibos.isEmpty) {
        _mostrarSinDatos();
        return;
      }
      final bytes = await ExcelGenerator.generarExcelPropietario(
        recibos: recibos,
        propietarioNombre: _obtenerNombrePropietario(),
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
      final bytes = await ExcelGenerator.generarExcelPropietario(
        recibos: recibos,
        propietarioNombre: _obtenerNombrePropietario(),
      );

      // Generar PDF del Excel para compartir por WhatsApp
      final dir = await getTemporaryDirectory();
      final nombreProp = _obtenerNombrePropietario() ?? 'Propietarios';
      final fmtNombre = DateFormat('yyyyMMdd_HHmm');

      // Guardar Excel
      final nombreExcel =
          'CoppolaPavese_${nombreProp}_${fmtNombre.format(DateTime.now())}.xlsx';
      final archivoExcel =
          File('${dir.path}${Platform.pathSeparator}$nombreExcel');
      await archivoExcel.writeAsBytes(bytes);

      // Texto de WhatsApp
      final mensaje = StringBuffer();
      mensaje.writeln('*COPPOLA PAVESE Inmobiliaria*');
      mensaje.writeln('Blandengues 188 - San Miguel del Monte');
      mensaje.writeln('Tel: 02226 546317 / 02271 412950');
      mensaje.writeln('');
      mensaje.writeln('*Reporte de Propietario: $nombreProp*');
      if (_filtroDesde != null || _filtroHasta != null) {
        final desde = _filtroDesde != null
            ? DateFormat('MM/yyyy').format(_filtroDesde!)
            : 'inicio';
        final hasta = _filtroHasta != null
            ? DateFormat('MM/yyyy').format(_filtroHasta!)
            : 'actualidad';
        mensaje.writeln('Período: $desde - $hasta');
      }
      mensaje.writeln('');
      mensaje.writeln('Se adjunta el reporte en formato Excel.');

      await Share.shareXFiles(
        [XFile(archivoExcel.path)],
        text: mensaje.toString(),
      );
    } catch (e) {
      _mostrarError(e);
    } finally {
      if (mounted) setState(() => _generandoProp = false);
    }
  }

  // ════════════════════════════════════════════════════════════════
  // HELPERS — ARCHIVO / UI
  // ════════════════════════════════════════════════════════════════

  void _mostrarSinDatos() {
    if (mounted) {
      mostrarNotificacion(context,
          texto: 'No se encontraron recibos con los filtros seleccionados.',
          color: const Color(0xFFF57C00));
    }
  }

  void _mostrarExito(String ruta) {
    if (mounted) {
      mostrarNotificacion(context,
          texto: 'Excel guardado en: $ruta',
          color: const Color(0xFF2E7D32),
          action: SnackBarAction(
            label: 'ABRIR CARPETA',
            textColor: Colors.white,
            onPressed: () => _abrirCarpeta(ruta),
          ));
    }
  }

  void _mostrarError(Object e) {
    if (mounted) {
      mostrarNotificacion(context,
          texto: 'Error al generar Excel: $e',
          color: const Color(0xFFC62828));
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

  Widget _pantallaPassword() {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _magenta.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_outline,
                        color: _magenta, size: 40),
                  ),
                  const SizedBox(height: 20),
                  const Text('Acceso Restringido',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF212121))),
                  const SizedBox(height: 8),
                  const Text(
                      'Ingresá la contraseña para acceder a los reportes',
                      style:
                          TextStyle(fontSize: 13, color: Color(0xFF757575)),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.key),
                      border: const OutlineInputBorder(),
                      errorText: _passError,
                    ),
                    onSubmitted: (_) => _verificarPassword(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton.icon(
                      onPressed: _verificarPassword,
                      icon: const Icon(Icons.login, size: 20),
                      label: const Text('Ingresar',
                          style: TextStyle(fontSize: 14)),
                      style: FilledButton.styleFrom(
                        backgroundColor: _magenta,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _verificarPassword() {
    if (_passCtrl.text.trim() == 'texas') {
      setState(() {
        _autenticado = true;
        _passError = null;
      });
    } else {
      setState(() => _passError = 'Contraseña incorrecta');
    }
  }

  Widget _panelResumenCompacto() {
    final fmt = NumberFormat.currency(
        locale: 'es_AR', symbol: '\$', decimalDigits: 0, customPattern: '\u00A4#,##0');
    final totalFinanciero = _cobradoMes + _pendienteTotal;
    final pctCobrado =
        totalFinanciero > 0 ? _cobradoMes / totalFinanciero : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tituloSeccion('Resumen General', Icons.dashboard_outlined),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _statMini(fmt.format(_cobradoMes), 'Cobrado Mes',
                        Icons.check_circle, const Color(0xFF2E7D32))),
                const SizedBox(width: 8),
                Expanded(
                    child: _statMini(fmt.format(_pendienteTotal),
                        'Pendiente', Icons.pending_actions, const Color(0xFFE65100))),
                const SizedBox(width: 8),
                Expanded(
                    child: _statMini(
                        '${_estadisticas['total'] ?? 0}',
                        'Total Recibos',
                        Icons.receipt_long,
                        const Color(0xFF1565C0))),
                const SizedBox(width: 8),
                Expanded(
                    child: _statMini(
                        '${_estadisticas['pagados'] ?? 0}',
                        'Pagados',
                        Icons.check_circle_outline,
                        const Color(0xFF2E7D32))),
                const SizedBox(width: 8),
                Expanded(
                    child: _statMini(
                        '${_estadisticas['pendientes'] ?? 0}',
                        'Pend. Cobro',
                        Icons.pending_actions_outlined,
                        const Color(0xFFC62828))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                    'Cobrado ${(pctCobrado * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2E7D32))),
                const Spacer(),
                Text(
                    'Pendiente ${((1 - pctCobrado) * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE65100))),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    Expanded(
                      flex: (pctCobrado * 100).round().clamp(1, 100),
                      child: Container(color: const Color(0xFF2E7D32)),
                    ),
                    Expanded(
                      flex:
                          ((1 - pctCobrado) * 100).round().clamp(1, 100),
                      child: Container(color: const Color(0xFFE65100)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statMini(
      String valor, String label, IconData icono, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Icon(icono, color: color, size: 18),
          const SizedBox(height: 3),
          Text(valor,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(label,
              style:
                  const TextStyle(fontSize: 9, color: Color(0xFF757575)),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _tituloSeccion(String texto, IconData icono) {
    return Row(
      children: [
        Icon(icono, size: 17, color: _magenta),
        const SizedBox(width: 8),
        Text(texto,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _magenta)),
      ],
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
                          _leyenda(const Color(0xFF2E7D32),
                              'Pagados ($pagados)'),
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
                                    style: TextStyle(
                                        color: Color(0xFF9E9E9E))))
                            : CustomPaint(
                                painter: _BarChartPainter(
                                    datos: _datosMensuales),
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

  Widget _panelResumenApp() {
    final c = _conteoGeneral;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tituloSeccion('Resumen de la App', Icons.analytics_outlined),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _statMini(
                        '${c['contratos_activos'] ?? 0}',
                        'Contratos Activos',
                        Icons.description,
                        const Color(0xFF1565C0))),
                const SizedBox(width: 8),
                Expanded(
                    child: _statMini(
                        '${c['contratos'] ?? 0}',
                        'Total Contratos',
                        Icons.folder_outlined,
                        const Color(0xFF5E35B1))),
                const SizedBox(width: 8),
                Expanded(
                    child: _statMini(
                        '${c['propiedades'] ?? 0}',
                        'Propiedades',
                        Icons.home_outlined,
                        const Color(0xFFE65100))),
                const SizedBox(width: 8),
                Expanded(
                    child: _statMini(
                        '${c['propietarios'] ?? 0}',
                        'Propietarios',
                        Icons.person_outline,
                        const Color(0xFF00695C))),
                const SizedBox(width: 8),
                Expanded(
                    child: _statMini(
                        '${c['inquilinos'] ?? 0}',
                        'Inquilinos',
                        Icons.people_outline,
                        const Color(0xFF4527A0))),
                const SizedBox(width: 8),
                Expanded(
                    child: _statMini(
                        '${c['recibos'] ?? 0}',
                        'Recibos',
                        Icons.receipt_outlined,
                        _magenta)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _panelGraficaLinea() {
    final fmt = NumberFormat.currency(
        locale: 'es_AR', symbol: '\$', decimalDigits: 0, customPattern: '\u00A4#,##0');
    final totalEmitido = _datosFinancieros.fold<double>(
        0, (sum, d) => sum + d.emitido);
    final totalCobrado = _datosFinancieros.fold<double>(
        0, (sum, d) => sum + d.cobrado);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tituloSeccion(
                'Ingresos y Cobros', Icons.show_chart_outlined),
            const SizedBox(height: 8),
            Row(
              children: [
                _leyenda(const Color(0xFFE65100), 'Emitido'),
                const SizedBox(width: 16),
                _leyenda(const Color(0xFF2E7D32), 'Cobrado'),
                if (_datosFinancieros.isNotEmpty) ...[
                  const Spacer(),
                  Text(
                      'Total emitido: ${fmt.format(totalEmitido)}',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE65100))),
                  const SizedBox(width: 12),
                  Text(
                      'Total cobrado: ${fmt.format(totalCobrado)}',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E7D32))),
                ],
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: _datosFinancieros.isEmpty
                  ? const Center(
                      child: Text(
                          'Los datos se mostrarán cuando haya recibos emitidos',
                          style: TextStyle(
                              color: Color(0xFF9E9E9E), fontSize: 12)))
                  : CustomPaint(
                      painter:
                          _LineChartPainter(datos: _datosFinancieros),
                      size: Size.infinite,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panelGraficaContratos() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tituloSeccion(
                'Contratos por Mes', Icons.timeline_outlined),
            const SizedBox(height: 8),
            _leyenda(const Color(0xFF1565C0), 'Contratos nuevos'),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: _datosContratos.isEmpty
                  ? const Center(
                      child: Text(
                          'Los datos se mostrarán cuando haya contratos con fecha de inicio',
                          style: TextStyle(
                              color: Color(0xFF9E9E9E), fontSize: 12)))
                  : CustomPaint(
                      painter: _ContratosBarPainter(
                          datos: _datosContratos),
                      size: Size.infinite,
                    ),
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
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(texto, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

// ── Data models ─────────────────────────────────────────────────────

class _DatoMensual {
  final String etiqueta;
  final int cantidad;
  const _DatoMensual({required this.etiqueta, required this.cantidad});
}

class _DatoFinanciero {
  final String etiqueta;
  final double emitido;
  final double cobrado;
  const _DatoFinanciero(
      {required this.etiqueta,
      required this.emitido,
      required this.cobrado});
}

class _DatoContratos {
  final String etiqueta;
  final int cantidad;
  const _DatoContratos({required this.etiqueta, required this.cantidad});
}

// ── Painters ────────────────────────────────────────────────────────

class _DonutChartPainter extends CustomPainter {
  final int pagados, pendientes, total;
  const _DonutChartPainter(
      {required this.pagados,
      required this.pendientes,
      required this.total});

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
      canvas.drawArc(rect, startAngle + pagadosAngle, pendientesAngle,
          false, paint);
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
                Rect.fromLTWH(x, y, barW, barH),
                const Radius.circular(4)),
            barPaint);
        if (d.cantidad > 0) {
          tp.text = TextSpan(
              text: '${d.cantidad}',
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF424242)));
          tp.layout();
          tp.paint(canvas,
              Offset(x + (barW - tp.width) / 2, y - topPad + 2));
        }
      }
      tp.text = TextSpan(
          text: d.etiqueta,
          style:
              const TextStyle(fontSize: 10, color: Color(0xFF757575)));
      tp.layout();
      tp.paint(canvas,
          Offset(x + (barW - tp.width) / 2, size.height - bottomPad + 4));
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) => old.datos != datos;
}

class _LineChartPainter extends CustomPainter {
  final List<_DatoFinanciero> datos;
  _LineChartPainter({required this.datos});

  @override
  void paint(Canvas canvas, Size size) {
    if (datos.isEmpty) return;

    const leftPad = 60.0;
    const rightPad = 16.0;
    const topPad = 16.0;
    const bottomPad = 30.0;
    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;

    final maxVal = datos.fold<double>(
        0, (m, d) => math.max(m, math.max(d.emitido, d.cobrado)));
    final safeMax = maxVal > 0 ? maxVal : 1.0;

    // Grilla horizontal
    final gridPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 0.5;
    final tp = TextPainter(textDirection: ui.TextDirection.ltr);
    final fmt = NumberFormat.compact(locale: 'es');

    for (int i = 0; i <= 4; i++) {
      final y = topPad + chartH - (chartH * i / 4);
      canvas.drawLine(
          Offset(leftPad, y), Offset(size.width - rightPad, y), gridPaint);
      final val = safeMax * i / 4;
      tp.text = TextSpan(
          text: '\$${fmt.format(val)}',
          style:
              const TextStyle(fontSize: 9, color: Color(0xFF9E9E9E)));
      tp.layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 4, y - tp.height / 2));
    }

    // Líneas
    final emitidoPaint = Paint()
      ..color = const Color(0xFFE65100)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final cobradoPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final emitidoPath = Path();
    final cobradoPath = Path();
    final divisor = datos.length > 1 ? datos.length - 1 : 1;

    for (int i = 0; i < datos.length; i++) {
      final d = datos[i];
      final x = datos.length == 1
          ? leftPad + chartW / 2
          : leftPad + (chartW * i / divisor);
      final yEmit = topPad + chartH - (d.emitido / safeMax * chartH);
      final yCobr = topPad + chartH - (d.cobrado / safeMax * chartH);

      if (i == 0) {
        emitidoPath.moveTo(x, yEmit);
        cobradoPath.moveTo(x, yCobr);
      } else {
        emitidoPath.lineTo(x, yEmit);
        cobradoPath.lineTo(x, yCobr);
      }

      // Puntos
      canvas.drawCircle(
          Offset(x, yEmit), 4.5, Paint()..color = const Color(0xFFE65100));
      canvas.drawCircle(
          Offset(x, yCobr), 4.5, Paint()..color = const Color(0xFF2E7D32));

      // Línea vertical al eje (para un solo punto, muestra barra guía)
      if (datos.length == 1) {
        final guidePaint = Paint()
          ..color = const Color(0xFFE0E0E0)
          ..strokeWidth = 1;
        canvas.drawLine(
            Offset(x, topPad), Offset(x, topPad + chartH), guidePaint);
      }

      // Valores encima de los puntos
      final fmtVal = NumberFormat.compact(locale: 'es');
      tp.text = TextSpan(
          text: '\$${fmtVal.format(d.emitido)}',
          style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE65100)));
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, yEmit - 14));

      tp.text = TextSpan(
          text: '\$${fmtVal.format(d.cobrado)}',
          style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32)));
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, yCobr + 6));

      // Etiquetas del eje X
      if (i % math.max(1, (datos.length / 8).ceil()) == 0 ||
          i == datos.length - 1) {
        tp.text = TextSpan(
            text: d.etiqueta,
            style: const TextStyle(
                fontSize: 9, color: Color(0xFF757575)));
        tp.layout();
        tp.paint(canvas,
            Offset(x - tp.width / 2, size.height - bottomPad + 6));
      }
    }

    if (datos.length > 1) {
      canvas.drawPath(emitidoPath, emitidoPaint);
      canvas.drawPath(cobradoPath, cobradoPaint);
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) => old.datos != datos;
}

class _ContratosBarPainter extends CustomPainter {
  final List<_DatoContratos> datos;
  _ContratosBarPainter({required this.datos});

  @override
  void paint(Canvas canvas, Size size) {
    if (datos.isEmpty) return;
    final maxVal =
        datos.map((d) => d.cantidad).reduce((a, b) => a > b ? a : b);
    final barPaint = Paint()..color = const Color(0xFF1565C0);
    final emptyPaint = Paint()..color = const Color(0xFFE3F2FD);
    final tp = TextPainter(textDirection: ui.TextDirection.ltr);

    final slotW = size.width / datos.length;
    final barW = slotW * 0.55;
    const topPad = 20.0;
    const bottomPad = 24.0;
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
        // Fondo
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(x, topPad, barW, maxBarH),
                const Radius.circular(4)),
            emptyPaint);
        // Barra
        final barH = (d.cantidad / maxVal) * maxBarH;
        final y = topPad + (maxBarH - barH);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(x, y, barW, barH),
                const Radius.circular(4)),
            barPaint);
        if (d.cantidad > 0) {
          tp.text = TextSpan(
              text: '${d.cantidad}',
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1565C0)));
          tp.layout();
          tp.paint(canvas,
              Offset(x + (barW - tp.width) / 2, y - topPad + 2));
        }
      }
      // Etiqueta
      tp.text = TextSpan(
          text: d.etiqueta,
          style:
              const TextStyle(fontSize: 9, color: Color(0xFF757575)));
      tp.layout();
      tp.paint(canvas,
          Offset(x + (barW - tp.width) / 2, size.height - bottomPad + 6));
    }
  }

  @override
  bool shouldRepaint(_ContratosBarPainter old) => old.datos != datos;
}
