import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import 'contrato_form_screen.dart';
import '../recibos/recibo_form_screen.dart';

class ContratosListScreen extends StatefulWidget {
  const ContratosListScreen({super.key});

  @override
  State<ContratosListScreen> createState() => _ContratosListScreenState();
}

class _ContratosListScreenState extends State<ContratosListScreen> {
  final _db = DatabaseHelper();
  List<Map<String, dynamic>> _contratos = [];
  List<Map<String, dynamic>> _contratosFiltrados = [];
  bool _cargando = true;
  final _busquedaCtrl = TextEditingController();
  Timer? _autoRefresh;

  // ID del contrato expandido (null = ninguno)
  int? _expandidoId;

  static const _magenta = Color(0xFFC2185B);
  static const _navy = Color(0xFF1A3A5C);
  static final _fmtMonto =
      NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);

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
    super.dispose();
  }

  Future<void> _refrescoSilencioso() async {
    try {
      final data = await _cargarDatosCompletos();
      if (mounted) {
        setState(() => _contratos = data);
        _buscar();
      }
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _cargarDatosCompletos() async {
    final raw = await _db.obtenerContratosActivos();
    final data = raw.map((c) => Map<String, dynamic>.from(c)).toList();
    for (final c in data) {
      final cId = c['id'] as int?;
      if (cId != null) {
        c['_garantes'] = await _db.obtenerGarantesPorContrato(cId);
        c['_periodos'] = await _db.obtenerPeriodosPorContrato(cId);
        c['_conceptos'] = await _db.obtenerConceptosPorContrato(cId);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar contratos: $e')),
        );
      }
    }
  }

  void _buscar() {
    final q = _busquedaCtrl.text.toLowerCase().trim();
    if (q.isEmpty) {
      setState(() => _contratosFiltrados = List.from(_contratos));
      return;
    }
    setState(() {
      _contratosFiltrados = _contratos.where((c) {
        final dir =
            (c['propiedad_direccion'] as String? ?? '').toLowerCase();
        final inq = (c['inquilino_nombre'] as String? ?? '').toLowerCase();
        final prop =
            (c['propietario_nombre'] as String? ?? '').toLowerCase();
        return dir.contains(q) || inq.contains(q) || prop.contains(q);
      }).toList();
    });
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contrato eliminado'),
              backgroundColor: Color(0xFF2E7D32),
            ),
          );
          _cargar();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: const Color(0xFFC62828),
            ),
          );
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
    if (resultado == true) _cargar();
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            color: _magenta,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _busquedaCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText:
                    'Buscar por propiedad, inquilino o propietario...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.white70),
                suffixIcon: _busquedaCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            color: Colors.white70),
                        onPressed: () {
                          _busquedaCtrl.clear();
                          _buscar();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
            ),
          ),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _contratosFiltrados.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_outlined,
                          size: 72,
                          color: Colors.grey.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      const Text(
                        'No hay contratos registrados',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF9E9E9E),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
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
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
                    itemCount: _contratosFiltrados.length,
                    itemBuilder: (context, i) =>
                        _tarjetaContrato(_contratosFiltrados[i]),
                  ),
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
    final cuotasTotal = c['cuotas_total'] as int? ?? 0;

    final colorEstado =
        rescindido ? const Color(0xFFC62828) : const Color(0xFF2E7D32);
    final labelEstado = rescindido ? 'RESCINDIDO' : 'ACTIVO';

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
                  // Icono
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colorEstado.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.description, color: colorEstado, size: 24),
                  ),
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
                  // ── PARTES ──
                  _seccionTitulo('Partes', Icons.people_outline),
                  const SizedBox(height: 8),
                  _filaDetalle('Locador', propietario, Icons.person),
                  _filaDetalle(
                      'Locatario', inquilinoFull, Icons.person_outline),
                  ..._buildGarantes(c),

                  const SizedBox(height: 16),

                  // ── PROPIEDAD ──
                  _seccionTitulo('Propiedad', Icons.apartment_outlined),
                  const SizedBox(height: 8),
                  _filaDetalle('Direccion', direccion, Icons.location_on_outlined),
                  if (localidad.isNotEmpty)
                    _filaDetalle('Localidad', localidad, Icons.map_outlined),
                  if (tipo.isNotEmpty)
                    _filaDetalle('Tipo', tipo, Icons.category_outlined),

                  const SizedBox(height: 16),

                  // ── VIGENCIA ──
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: _cajaDato(
                          'Fin',
                          _fmtFecha(fechaFin),
                          const Color(0xFFE65100),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _cajaDato(
                          'Cuotas',
                          '$cuotasTotal',
                          _navy,
                        ),
                      ),
                    ],
                  ),
                  if (rescindido) ...[
                    const SizedBox(height: 8),
                    _filaDetalle(
                      'Fecha Rescision',
                      _fmtFecha(c['fecha_rescision'] as String? ?? ''),
                      Icons.cancel_outlined,
                      color: const Color(0xFFC62828),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ── CONDICIONES ECONÓMICAS ──
                  _seccionTitulo(
                      'Condiciones Economicas', Icons.attach_money),
                  const SizedBox(height: 8),
                  _buildCondicionesEconomicas(c),

                  const SizedBox(height: 16),

                  // ── PERÍODOS FIJOS ──
                  ..._buildPeriodos(c),

                  // ── CONCEPTOS REGULARES ──
                  ..._buildConceptos(c),

                  // ── BOTONES DE ACCIÓN ──
                  const SizedBox(height: 8),
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
      {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icono, size: 15, color: color ?? const Color(0xFF9E9E9E)),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
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
                  fontSize: 10, color: color, fontWeight: FontWeight.w500)),
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
    final alquiler =
        (c['alquiler_primer_periodo'] as num?)?.toDouble() ?? 0.0;
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
                'Alquiler',
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
    if (periodos.isEmpty) return [];

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
                      flex: 2,
                      child: Text('Cuotas',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600))),
                  Expanded(
                      flex: 2,
                      child: Text('Monto',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.right)),
                ],
              ),
            ),
            ...periodos.asMap().entries.map((e) {
              final p = e.value;
              final desde = p['cuota_desde'] as int? ?? 0;
              final hasta = p['cuota_hasta'] as int? ?? 0;
              final monto = (p['monto'] as num?)?.toDouble() ?? 0.0;
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
                      flex: 2,
                      child: Text('#$desde — #$hasta',
                          style: const TextStyle(fontSize: 12)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(_fmtMonto.format(monto),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.right),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildConceptos(Map<String, dynamic> c) {
    final conceptos =
        (c['_conceptos'] as List<Map<String, dynamic>>?) ?? [];
    if (conceptos.isEmpty) return [];

    return [
      _seccionTitulo('Conceptos Regulares', Icons.repeat),
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
                      child: Text('Concepto',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600))),
                  Expanded(
                      flex: 1,
                      child: Text('Monto',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.right)),
                  Expanded(
                      flex: 1,
                      child: Text('Tipo',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.right)),
                ],
              ),
            ),
            ...conceptos.asMap().entries.map((e) {
              final cp = e.value;
              final desc = cp['descripcion'] as String? ?? '';
              final monto = (cp['monto'] as num?)?.toDouble() ?? 0.0;
              final tipo = cp['tipo'] as String? ?? 'regular';
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
                    Expanded(
                      flex: 1,
                      child: Text(
                        tipo == 'regular' ? 'Regular' : 'Unico',
                        style: TextStyle(
                          fontSize: 10,
                          color: tipo == 'regular'
                              ? const Color(0xFF1565C0)
                              : const Color(0xFFE65100),
                          fontWeight: FontWeight.w600,
                        ),
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
      const SizedBox(height: 16),
    ];
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
