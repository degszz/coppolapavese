import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../utils/snackbar_helper.dart';
import 'contrato_form_screen.dart';
import '../recibos/recibo_form_screen.dart';
import '../propietarios/propietario_detalle_screen.dart';

const _mesesCompletosContratos = [
  '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

String _normalizarDescAlquilerContratos(
    String desc, int? numeroCuota, String? fechaEmisionIso) {
  if (!desc.toLowerCase().startsWith('alquiler')) return desc;
  if (numeroCuota == null || fechaEmisionIso == null || fechaEmisionIso.isEmpty) {
    return desc;
  }
  try {
    final dt = DateTime.parse(fechaEmisionIso);
    final mes = _mesesCompletosContratos[dt.month.clamp(1, 12)];
    return 'Alquiler Cuota N°$numeroCuota - $mes ${dt.year}';
  } catch (_) {
    return desc;
  }
}

class ContratosListScreen extends StatefulWidget {
  const ContratosListScreen({super.key});

  @override
  State<ContratosListScreen> createState() => _ContratosListScreenState();
}

class _ContratosListScreenState extends State<ContratosListScreen> {
  static const _mesesAbrev = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];

  final _db = DatabaseHelper();
  List<Map<String, dynamic>> _contratos = [];
  List<Map<String, dynamic>> _contratosFiltrados = [];
  bool _cargando = true;
  final _busquedaCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _autoRefresh;

  // ID del contrato expandido (null = ninguno)
  int? _expandidoId;

  // Filtros por chips
  String? _filtroEstadoCuenta; // null = Todos | 'al_dia' | 'atrasado' | 'pendiente'
  bool _filtroPendientes = false;

  static const _magenta = Color(0xFFC2185B);
  static final _fmtMonto =
      NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0, customPattern: '\u00A4#,##0');

  @override
  void initState() {
    super.initState();
    _busquedaCtrl.addListener(_buscar);
    _cargar();
    _autoRefresh = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refrescoSilencioso(),
    );
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    _busquedaCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _refrescoSilencioso() async {
    try {
      final data = await _cargarDatosCompletos();
      if (mounted) {
        setState(() => _contratos = data);
        _buscar();
      }
    } catch (e) {
      debugPrint('[refrescoSilencioso] error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _cargarDatosCompletos() async {
    final raw = await _db.obtenerContratosActivos();
    final data = raw.map((c) => Map<String, dynamic>.from(c)).toList();
    for (final c in data) {
      final cId = c['id'] as int?;
      if (cId != null) {
        try {
          c['_garantes'] = await _db.obtenerGarantesPorContrato(cId);
          c['_periodos'] = await _db.obtenerPeriodosPorContrato(cId);
          c['_conceptos'] = await _db.obtenerConceptosPorContrato(cId);
          c['_serviciosUltimoRecibo'] = await _db.obtenerServiciosUltimoRecibo(cId);
        } catch (e) {
          debugPrint('[cargarDatosCompletos] contrato $cId falló: $e');
          c['_garantes'] = <Map<String, dynamic>>[];
          c['_periodos'] = <Map<String, dynamic>>[];
          c['_conceptos'] = <Map<String, dynamic>>[];
          c['_serviciosUltimoRecibo'] = <Map<String, dynamic>>[];
        }
      } else {
        c['_garantes'] = <Map<String, dynamic>>[];
        c['_periodos'] = <Map<String, dynamic>>[];
        c['_conceptos'] = <Map<String, dynamic>>[];
        c['_serviciosUltimoRecibo'] = <Map<String, dynamic>>[];
      }
      // Cargar foto de la propiedad
      final propiedadId = c['propiedad_id'] as int?;
      if (propiedadId != null) {
        try {
          final imgs = await _db.obtenerImagenesPropiedad(propiedadId);
          if (imgs.isNotEmpty) {
            c['_foto_propiedad'] = imgs.first['ruta'] as String?;
          }
        } catch (e) {
          debugPrint('[cargarDatosCompletos] foto propiedad $propiedadId falló: $e');
        }
      }
    }
    return data;
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final data = await _cargarDatosCompletos();
      if (mounted) {
        setState(() {
          _contratos = data;
          _cargando = false;
        });
        _buscar();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        mostrarNotificacion(context,
            texto: 'Error al cargar contratos: $e',
            color: const Color(0xFFC62828));
      }
    }
  }

  void _buscar() {
    final q = _busquedaCtrl.text.toLowerCase().trim();
    final hayFiltros = q.isNotEmpty ||
        _filtroEstadoCuenta != null ||
        _filtroPendientes;
    if (!hayFiltros) {
      setState(() => _contratosFiltrados = List.from(_contratos));
      return;
    }
    setState(() {
      _contratosFiltrados = _contratos.where((c) {
        // Texto
        if (q.isNotEmpty) {
          final dir =
              (c['propiedad_direccion'] as String? ?? '').toLowerCase();
          final inq = (c['inquilino_nombre'] as String? ?? '').toLowerCase();
          final prop =
              (c['propietario_nombre'] as String? ?? '').toLowerCase();
          if (!dir.contains(q) && !inq.contains(q) && !prop.contains(q)) {
            return false;
          }
        }
        // Con pendientes
        if (_filtroPendientes) {
          final pend = c['_recibos_pendientes'] as int? ?? 0;
          if (pend <= 0) return false;
        }
        // Estado de cuenta
        if (_filtroEstadoCuenta != null) {
          if (_estadoCuentaDe(c) != _filtroEstadoCuenta) return false;
        }
        return true;
      }).toList();
    });
  }

  String _estadoCuentaDe(Map<String, dynamic> c) {
    final emitidos = c['_recibos_emitidos'] as int? ?? 0;
    if (emitidos == 0) return 'al_dia';
    final saldo = (c['_ultimo_saldo'] as num?)?.toDouble() ?? 0;
    if (saldo <= 0) return 'al_dia';
    final vtoStr = c['_ultimo_vencimiento'] as String? ?? '';
    try {
      final diff = DateTime.now().difference(DateTime.parse(vtoStr)).inDays;
      return diff > 0 ? 'atrasado' : 'pendiente';
    } catch (_) {
      return 'pendiente';
    }
  }

  Future<void> _eliminar(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar contrato'),
        content: const Text(
          '¿Estas seguro de eliminar este contrato?\n\n'
          'Se eliminaran tambien todos sus periodos fijos asociados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC62828)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar == true && mounted) {
      try {
        await _db.eliminarContrato(id);
        if (mounted) {
          mostrarNotificacion(context,
              texto: 'Contrato eliminado',
              color: const Color(0xFF2E7D32));
          _cargar();
        }
      } catch (e) {
        if (mounted) {
          mostrarNotificacion(context,
              texto: 'Error al eliminar: $e',
              color: const Color(0xFFC62828));
        }
      }
    }
  }

  Future<void> _irAFormulario([Map<String, dynamic>? datos]) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ContratoFormScreen(datosExistentes: datos),
      ),
    );
    if (resultado == true) _refrescoSilencioso();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contratos'),
        backgroundColor: _magenta,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _cargar,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _busquedaCtrl,
              decoration: InputDecoration(
                hintText:
                    'Buscar por propiedad, inquilino o propietario...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _busquedaCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _busquedaCtrl.clear();
                          _buscar();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
            ),
          ),
          // ── FILA DE FILTROS (chips) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                  selected: _filtroPendientes,
                  onSelected: (v) {
                    setState(() => _filtroPendientes = v);
                    _buscar();
                  },
                  label: const Text('Con pendientes',
                      style: TextStyle(fontSize: 11)),
                  avatar: const Icon(Icons.pending_actions, size: 14),
                  selectedColor: const Color(0xFFE65100).withOpacity(0.18),
                  backgroundColor: const Color(0xFFE65100).withOpacity(0.06),
                  side: BorderSide(
                    color: _filtroPendientes
                        ? const Color(0xFFE65100)
                        : const Color(0xFFE65100).withOpacity(0.3),
                  ),
                  labelStyle: TextStyle(
                    color: _filtroPendientes
                        ? const Color(0xFFE65100)
                        : const Color(0xFF757575),
                    fontWeight: _filtroPendientes
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                  showCheckmark: false,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                FilterChip(
                  selected: _filtroEstadoCuenta == 'al_dia',
                  onSelected: (v) {
                    setState(() => _filtroEstadoCuenta =
                        v ? 'al_dia' : null);
                    _buscar();
                  },
                  label: const Text('Al día',
                      style: TextStyle(fontSize: 11)),
                  avatar: const Icon(Icons.check_circle_outline, size: 14),
                  selectedColor: const Color(0xFF2E7D32).withOpacity(0.18),
                  backgroundColor: const Color(0xFF2E7D32).withOpacity(0.06),
                  side: BorderSide(
                    color: _filtroEstadoCuenta == 'al_dia'
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFF2E7D32).withOpacity(0.3),
                  ),
                  labelStyle: TextStyle(
                    color: _filtroEstadoCuenta == 'al_dia'
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFF757575),
                    fontWeight: _filtroEstadoCuenta == 'al_dia'
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                  showCheckmark: false,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                FilterChip(
                  selected: _filtroEstadoCuenta == 'atrasado',
                  onSelected: (v) {
                    setState(() => _filtroEstadoCuenta =
                        v ? 'atrasado' : null);
                    _buscar();
                  },
                  label: const Text('Atrasado',
                      style: TextStyle(fontSize: 11)),
                  avatar: const Icon(Icons.error_outline, size: 14),
                  selectedColor: const Color(0xFFC62828).withOpacity(0.18),
                  backgroundColor: const Color(0xFFC62828).withOpacity(0.06),
                  side: BorderSide(
                    color: _filtroEstadoCuenta == 'atrasado'
                        ? const Color(0xFFC62828)
                        : const Color(0xFF2E7D32).withOpacity(0.3),
                  ),
                  labelStyle: TextStyle(
                    color: _filtroEstadoCuenta == 'atrasado'
                        ? const Color(0xFFC62828)
                        : const Color(0xFF757575),
                    fontWeight: _filtroEstadoCuenta == 'atrasado'
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                  showCheckmark: false,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                FilterChip(
                  selected: _filtroEstadoCuenta == 'pendiente',
                  onSelected: (v) {
                    setState(() => _filtroEstadoCuenta =
                        v ? 'pendiente' : null);
                    _buscar();
                  },
                  label: const Text('Pendiente',
                      style: TextStyle(fontSize: 11)),
                  avatar: const Icon(Icons.schedule, size: 14),
                  selectedColor: const Color(0xFFE65100).withOpacity(0.18),
                  backgroundColor: const Color(0xFFE65100).withOpacity(0.06),
                  side: BorderSide(
                    color: _filtroEstadoCuenta == 'pendiente'
                        ? const Color(0xFFE65100)
                        : const Color(0xFFE65100).withOpacity(0.3),
                  ),
                  labelStyle: TextStyle(
                    color: _filtroEstadoCuenta == 'pendiente'
                        ? const Color(0xFFE65100)
                        : const Color(0xFF757575),
                    fontWeight: _filtroEstadoCuenta == 'pendiente'
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                  showCheckmark: false,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                if (_filtroPendientes || _filtroEstadoCuenta != null)
                  ActionChip(
                    label: const Text('Quitar filtros',
                        style: TextStyle(fontSize: 11)),
                    avatar: const Icon(Icons.clear, size: 14),
                    onPressed: () {
                      setState(() {
                        _filtroPendientes = false;
                        _filtroEstadoCuenta = null;
                      });
                      _buscar();
                    },
                    backgroundColor: const Color(0xFFE0E0E0).withOpacity(0.5),
                    labelStyle: const TextStyle(color: Color(0xFF616161)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
          Expanded(child: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _contratosFiltrados.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        (_filtroPendientes || _filtroEstadoCuenta != null)
                            ? Icons.filter_alt_off_outlined
                            : Icons.description_outlined,
                        size: 72,
                        color: Colors.grey.withOpacity(0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        (_filtroPendientes || _filtroEstadoCuenta != null)
                            ? 'Ningún contrato coincide con los filtros'
                            : 'No hay contratos registrados',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF9E9E9E),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      if (_filtroPendientes || _filtroEstadoCuenta != null) ...[
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _filtroPendientes = false;
                              _filtroEstadoCuenta = null;
                            });
                            _buscar();
                          },
                          icon: const Icon(Icons.clear, size: 18),
                          label: const Text('Quitar filtros'),
                        ),
                      ] else
                        const Text(
                          'Toca el boton + para agregar uno',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFFBDBDBD)),
                        ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
                    itemCount: _contratosFiltrados.length,
                    itemBuilder: (context, i) =>
                        _tarjetaContrato(_contratosFiltrados[i]),
                  ),
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _magenta,
        foregroundColor: Colors.white,
        onPressed: () => _irAFormulario(),
        child: const Icon(Icons.add),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // TARJETA DE CONTRATO (expandible)
  // ════════════════════════════════════════════════════════════════

  Widget _tarjetaContrato(Map<String, dynamic> c) {
    final id = c['id'] as int;
    final expandido = _expandidoId == id;

    final direccion =
        c['propiedad_direccion'] as String? ?? 'Sin propiedad asignada';
    final localidad = c['propiedad_localidad'] as String? ?? '';
    final tipo = c['propiedad_tipo'] as String? ?? '';
    final inquilino = c['inquilino_nombre'] as String? ?? '';
    final inquilinoApellido = c['inquilino_apellido'] as String? ?? '';
    final inquilinoFull = inquilinoApellido.isNotEmpty
        ? '$inquilino $inquilinoApellido'
        : inquilino.isNotEmpty
            ? inquilino
            : 'Sin inquilino';
    final propietario =
        c['propietario_nombre'] as String? ?? 'Sin propietario';
    final rescindido = (c['rescindido'] as int? ?? 0) == 1;
    final fechaInicio = c['fecha_inicio'] as String? ?? '';
    final fechaFin = c['fecha_fin'] as String? ?? '';

    final colorEstado =
        rescindido ? const Color(0xFFC62828) : const Color(0xFF2E7D32);
    final labelEstado = rescindido ? 'RESCINDIDO' : 'ACTIVO';
    final finalizado = (c['_recibos_emitidos'] as int? ?? 0) >=
        (c['cuotas_total'] as int? ?? 0) &&
        (c['cuotas_total'] as int? ?? 0) > 0;

    return Card(
      elevation: expandido ? 4 : 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: expandido ? _magenta.withOpacity(0.4) : Colors.transparent,
          width: expandido ? 1.5 : 0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── HEADER (siempre visible) ──
          InkWell(
            onTap: () {
              setState(() {
                _expandidoId = expandido ? null : id;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Foto propiedad o ícono
                  _buildFotoPropiedad(c, colorEstado),
                  const SizedBox(width: 12),
                  // Info principal
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(direccion,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(
                          '$inquilinoFull  •  $propietario',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF757575)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Badge estado
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorEstado,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(labelEstado,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                  if (finalizado) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFA000),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('FINALIZADO',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                  const SizedBox(width: 4),
                  Icon(
                    expandido
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFF9E9E9E),
                  ),
                ],
              ),
            ),
          ),

          // ── CONTENIDO EXPANDIDO ──
          if (expandido) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ═══ ROW 1: Partes (izq) | Propiedad (der) ═══
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _seccionTitulo('Partes', Icons.people_outline),
                            const SizedBox(height: 8),
                            _filaDetalle('Locador', propietario, Icons.person, labelWidth: 75),
                            _filaDetalle('Locatario', inquilinoFull, Icons.person_outline, labelWidth: 75),
                            ..._buildGarantes(c),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _seccionTitulo('Propiedad', Icons.apartment_outlined),
                            const SizedBox(height: 8),
                            _filaDetalle('Direccion', direccion, Icons.location_on_outlined, labelWidth: 75),
                            if (localidad.isNotEmpty)
                              _filaDetalle('Localidad', localidad, Icons.map_outlined, labelWidth: 75),
                            if (tipo.isNotEmpty)
                              _filaDetalle('Tipo', tipo, Icons.category_outlined, labelWidth: 75),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ═══ ROW 2: Vigencia (izq) | Estado de Cuenta (der) ═══
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _seccionTitulo('Vigencia del Contrato', Icons.date_range_outlined),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _cajaDato(
                                    'Inicio',
                                    _fmtFecha(fechaInicio),
                                    const Color(0xFF1565C0),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _cajaDato(
                                    'Fin',
                                    _fmtFecha(fechaFin),
                                    const Color(0xFFE65100),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _buildProgresoCuotas(c),
                            if (rescindido) ...[
                              const SizedBox(height: 8),
                              _filaDetalle(
                                'Fecha Rescision',
                                _fmtFecha(c['fecha_rescision'] as String? ?? ''),
                                Icons.cancel_outlined,
                                color: const Color(0xFFC62828),
                                labelWidth: 75,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _buildEstadoCuenta(c)),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ═══ ROW 3: Condiciones Económicas (full width) ═══
                  _seccionTitulo('Condiciones Economicas', Icons.attach_money),
                  const SizedBox(height: 8),
                  _buildCondicionesEconomicas(c),

                  const SizedBox(height: 12),

                  // ═══ ROW 4: Periodos Fijos (flex:3) | Servicios (flex:2) ═══
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ..._buildPeriodos(c),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildUltimoReciboResumen(c),
                            ..._buildConceptos(c),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── HISTORIAL PROPIETARIO ──
                  _buildBotonHistorial(c),

                  const SizedBox(height: 8),

                  // ── BOTONES DE ACCIÓN ──
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _irAFormulario(c),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Editar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1565C0),
                            side: const BorderSide(
                                color: Color(0xFF1565C0)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ReciboFormScreen(contratoIdInicial: id),
                              ),
                            );
                          },
                          icon:
                              const Icon(Icons.receipt_long_outlined, size: 18),
                          label: const Text('Nuevo Recibo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _eliminar(id),
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: const Color(0xFFC62828),
                        tooltip: 'Eliminar',
                        style: IconButton.styleFrom(
                          backgroundColor:
                              const Color(0xFFC62828).withOpacity(0.08),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // SECCIONES DEL DETALLE
  // ════════════════════════════════════════════════════════════════

  Widget _buildFotoPropiedad(Map<String, dynamic> c, Color colorEstado) {
    final fotoRuta = c['_foto_propiedad'] as String?;
    if (fotoRuta != null && fotoRuta.isNotEmpty) {
      final file = File(fotoRuta);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Image.file(
              file,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _iconoContrato(colorEstado),
            ),
          ),
        );
      }
    }
    return _iconoContrato(colorEstado);
  }

  Widget _iconoContrato(Color colorEstado) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colorEstado.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.description, color: colorEstado, size: 24),
    );
  }

  Widget _seccionTitulo(String texto, IconData icono) {
    return Row(
      children: [
        Icon(icono, size: 16, color: _magenta),
        const SizedBox(width: 6),
        Text(texto,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _magenta)),
      ],
    );
  }

  Widget _filaDetalle(String label, String valor, IconData icono,
      {Color? color, double labelWidth = 100}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 15, color: color ?? const Color(0xFF9E9E9E)),
          const SizedBox(width: 8),
          SizedBox(
            width: labelWidth,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF757575),
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(valor,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _cajaDato(String label, String valor, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(valor,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  List<Widget> _buildGarantes(Map<String, dynamic> c) {
    final garantes =
        (c['_garantes'] as List<Map<String, dynamic>>?) ?? [];
    if (garantes.isEmpty) return [];
    return garantes.map((g) {
      final nombre = g['nombre'] as String? ?? '';
      final tel = g['telefono'] as String? ?? '';
      final tipo = g['tipo_garantia'] as String? ?? '';
      final detalle = [
        nombre,
        if (tel.isNotEmpty) tel,
        if (tipo.isNotEmpty) '($tipo)',
      ].join('  •  ');
      return _filaDetalle('Garante', detalle, Icons.verified_user_outlined);
    }).toList();
  }

  Widget _buildCondicionesEconomicas(Map<String, dynamic> c) {
    // Mostrar el monto del último período fijo si existe, sino alquiler_primer_periodo
    final periodos =
        (c['_periodos'] as List<Map<String, dynamic>>?) ?? [];
    double alquiler;
    String alquilerLabel;
    if (periodos.isNotEmpty) {
      final ultimo = periodos.last;
      alquiler = (ultimo['monto'] as num?)?.toDouble() ?? 0.0;
      final desde = ultimo['cuota_desde'] as int? ?? 0;
      final hasta = ultimo['cuota_hasta'] as int? ?? 0;
      alquilerLabel = 'Alquiler (cuota #$desde-#$hasta)';
    } else {
      alquiler = (c['alquiler_primer_periodo'] as num?)?.toDouble() ?? 0.0;
      alquilerLabel = 'Alquiler';
    }
    final hastaCuota = c['hasta_cuota'] as int? ?? 0;
    final extras = (c['extras'] as num?)?.toDouble() ?? 0.0;
    final primerDia = c['primer_dia_pago'] as int? ?? 1;
    final pagoFinal = c['pago_final'] as int? ?? 10;
    final diasGracia = c['dias_gracia'] as int? ?? 10;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _cajaDato(
                alquilerLabel,
                _fmtMonto.format(alquiler),
                const Color(0xFF2E7D32),
              ),
            ),
            if (hastaCuota > 0) ...[
              const SizedBox(width: 8),
              Expanded(
                child: _cajaDato(
                  'Hasta cuota',
                  '#$hastaCuota',
                  const Color(0xFF1565C0),
                ),
              ),
            ],
            if (extras > 0) ...[
              const SizedBox(width: 8),
              Expanded(
                child: _cajaDato(
                  'Extras',
                  _fmtMonto.format(extras),
                  const Color(0xFF6A1B9A),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              _miniDato('Pago del', 'dia $primerDia'),
              _separadorVertical(),
              _miniDato('Hasta el', 'dia $pagoFinal'),
              _separadorVertical(),
              _miniDato('Gracia', '$diasGracia dias'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniDato(String label, String valor) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: Color(0xFF9E9E9E))),
          Text(valor,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _separadorVertical() {
    return Container(
      width: 1,
      height: 28,
      color: const Color(0xFFE0E0E0),
    );
  }

  List<Widget> _buildPeriodos(Map<String, dynamic> c) {
    final periodos =
        (c['_periodos'] as List<Map<String, dynamic>>?) ?? [];

    if (periodos.isEmpty) {
      return [
        _seccionTitulo('Periodos Fijos', Icons.calendar_month_outlined),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Color(0xFF9E9E9E)),
              const SizedBox(width: 8),
              Text('Sin periodos fijos configurados',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF9E9E9E))),
            ],
          ),
        ),
      ];
    }

    // Usar los valores manuales del contrato (cuota_inicial, mes_emision)
    // en lugar de los calculados desde recibos (_cuota_actual, _ultimo_mes_recibo)
    final cuotaManual = c['cuota_inicial'] as int? ?? 0;
    final mesEmision = c['mes_emision'] as int? ?? DateTime.now().month;

    return [
      _seccionTitulo('Periodos Fijos', Icons.calendar_month_outlined),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
                borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
              ),
              child: const Row(
                children: [
                  Expanded(
                      flex: 3,
                      child: Text('Cuotas',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600))),
                  Expanded(
                      flex: 2,
                      child: Text('Monto',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.right)),
                  Expanded(
                      flex: 2,
                      child: Text('Va por',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center)),
                ],
              ),
            ),
            ...periodos.asMap().entries.map((e) {
              final p = e.value;
              final desde = p['cuota_desde'] as int? ?? 0;
              final hasta = p['cuota_hasta'] as int? ?? 0;
              final monto = (p['monto'] as num?)?.toDouble() ?? 0.0;
              final entre = cuotaManual >= desde && cuotaManual <= hasta;
              final esUltimo = e.key == periodos.length - 1;
              final multiplesPeriodos = periodos.length > 1;

              // Va por: cuota manual (cuota_inicial) + mes manual (mes_emision)
              final mesLabel = _mesesAbrev[(mesEmision - 1).clamp(0, 11)];
              String? vaPorText;
              if (multiplesPeriodos && esUltimo) {
                final num = cuotaManual >= desde ? cuotaManual : desde;
                vaPorText = '$num $mesLabel';
              } else if (!multiplesPeriodos) {
                vaPorText = entre ? '$cuotaManual $mesLabel' : null;
              }
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: e.key % 2 == 0
                      ? Colors.white
                      : const Color(0xFFFCF3F6),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                          entre
                              ? '#$desde — #$hasta'
                              : '#$desde — #$hasta',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  entre ? FontWeight.w700 : FontWeight.normal,
                              color: entre
                                  ? const Color(0xFFC2185B)
                                  : Colors.black87)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(_fmtMonto.format(monto),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: entre
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: entre
                                  ? const Color(0xFFC2185B)
                                  : Colors.black87),
                          textAlign: TextAlign.right),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                          vaPorText ?? '—',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  vaPorText != null ? FontWeight.w600 : FontWeight.normal,
                              color: vaPorText != null
                                  ? const Color(0xFFC2185B)
                                  : const Color(0xFF9E9E9E)),
                          textAlign: TextAlign.center),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildConceptos(Map<String, dynamic> c) {
    final servicios =
        (c['_serviciosUltimoRecibo'] as List<Map<String, dynamic>>?) ?? [];
    final numRecibo = c['_ultimo_num_recibo'] as int?;

    if (servicios.isEmpty) {
      final mensaje = numRecibo == null
          ? 'Aun no se emitieron recibos'
          : 'Sin servicios cargados';
      return [
        _seccionTitulo('Servicios del último recibo', Icons.receipt_long_outlined),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Color(0xFF9E9E9E)),
              const SizedBox(width: 8),
              Text(mensaje,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF9E9E9E))),
            ],
          ),
        ),
      ];
    }

    return [
      _seccionTitulo('Servicios del último recibo', Icons.receipt_long_outlined),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Column(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(7)),
              ),
              child: const Row(
                children: [
                  Expanded(
                      flex: 3,
                      child: Text('Servicio',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600))),
                  Expanded(
                      flex: 1,
                      child: Text('Monto',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.right)),
                ],
              ),
            ),
            ...servicios.asMap().entries.map((e) {
              final sp = e.value;
              final descRaw = sp['descripcion'] as String? ?? '';
              final desc = _normalizarDescAlquilerContratos(
                  descRaw,
                  c['_ultimo_numero_cuota'] as int?,
                  c['_ultimo_fecha_emision'] as String?);
              final monto = (sp['monto'] as num?)?.toDouble() ?? 0.0;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: e.key % 2 == 0
                      ? Colors.white
                      : const Color(0xFFFCF3F6),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(desc,
                          style: const TextStyle(fontSize: 12)),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        monto > 0 ? _fmtMonto.format(monto) : '—',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    ];
  }

  // ════════════════════════════════════════════════════════════════
  // NUEVAS SECCIONES DEL DETALLE
  // ════════════════════════════════════════════════════════════════

  Widget _buildProgresoCuotas(Map<String, dynamic> c) {
    final cuotaActual = c['_cuota_actual'] as int? ?? 0;
    final cuotasTotal = c['cuotas_total'] as int? ?? 0;
    final mesEmision = (c['_ultimo_mes_recibo'] as int?) ?? DateTime.now().month;
    if (cuotaActual == 0) return const SizedBox.shrink();
    final mesLabel = _mesesAbrev[(mesEmision - 1).clamp(0, 11)];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5).withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFC2185B).withOpacity(0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.trending_up, size: 18, color: Color(0xFFC2185B)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Va por la cuota #$cuotaActual de $cuotasTotal  ·  $mesLabel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFFC2185B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoCuenta(Map<String, dynamic> c) {
    final emitidos = c['_recibos_emitidos'] as int? ?? 0;
    final pendientes = c['_recibos_pendientes'] as int? ?? 0;
    if (emitidos == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _seccionTitulo('Estado de Cuenta', Icons.account_balance_wallet_outlined),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Color(0xFF9E9E9E)),
                const SizedBox(width: 8),
                Text('Sin recibos emitidos',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9E9E9E))),
              ],
            ),
          ),
        ],
      );
    }
    final pagados = emitidos - pendientes;
    final ultimoSaldo = (c['_ultimo_saldo'] as num?)?.toDouble() ?? 0;
    final ultimoVto = c['_ultimo_vencimiento'] as String? ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _seccionTitulo('Estado de Cuenta', Icons.account_balance_wallet_outlined),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _cajaDato('Recibos', '$emitidos', const Color(0xFF1565C0)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _cajaDato('Pendientes', '$pendientes', const Color(0xFFE65100)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _cajaDato('Pagados', '$pagados', const Color(0xFF2E7D32)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildEstadoLinea(ultimoSaldo, ultimoVto),
      ],
    );
  }

  Widget _buildEstadoLinea(double saldo, String vtoStr) {
    final ahora = DateTime.now();
    String texto;
    Color color;
    IconData icono;
    if (saldo <= 0) {
      texto = 'Al dia — todo al corriente';
      color = const Color(0xFF2E7D32);
      icono = Icons.check_circle_outline;
    } else {
      try {
        final vto = DateTime.parse(vtoStr);
        final diff = ahora.difference(vto).inDays;
        if (diff > 0) {
          texto = 'Atrasado $diff dia${diff == 1 ? '' : 's'}';
          color = const Color(0xFFC62828);
          icono = Icons.error_outline;
        } else {
          texto = 'Pendiente — vence ${_fmtFecha(vtoStr)}';
          color = const Color(0xFFE65100);
          icono = Icons.warning_amber_outlined;
        }
      } catch (_) {
        texto = 'Pendiente';
        color = const Color(0xFFE65100);
        icono = Icons.warning_amber_outlined;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icono, size: 18, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildUltimoReciboResumen(Map<String, dynamic> c) {
    final numRecibo = c['_ultimo_num_recibo'] as int?;
    if (numRecibo == null) return const SizedBox.shrink();
    final fechaEmision = c['_ultimo_fecha_emision'] as String? ?? '';
    final saldo = (c['_ultimo_saldo'] as num?)?.toDouble() ?? 0;
    final estaPagado = saldo <= 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: estaPagado
              ? const Color(0xFF2E7D32).withOpacity(0.06)
              : const Color(0xFFE65100).withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: estaPagado
                ? const Color(0xFF2E7D32).withOpacity(0.2)
                : const Color(0xFFE65100).withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              estaPagado ? Icons.check_circle : Icons.pending_outlined,
              size: 20,
              color: estaPagado
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFFE65100),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recibo N° $numRecibo',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _fmtFecha(fechaEmision),
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF757575)),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: estaPagado
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFE65100),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                estaPagado ? 'PAGADO' : 'PENDIENTE',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonHistorial(Map<String, dynamic> c) {
    final propId = c['propietario_id'] as int?;
    final propNombre = c['propietario_nombre'] as String? ?? '';
    if (propId == null) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PropietarioDetalleScreen(
                propietarioId: propId,
                nombrePropietario: propNombre,
              ),
            ),
          );
        },
        icon: const Icon(Icons.history_outlined, size: 18),
        label: const Text('Ver historial del propietario'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF6A1B9A),
          side: BorderSide(
              color: Color(0xFF6A1B9A).withOpacity(0.4)),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════════

  String _fmtFecha(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return iso;
    }
  }
}
