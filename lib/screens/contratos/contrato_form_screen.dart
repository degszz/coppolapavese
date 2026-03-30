// lib/screens/contratos/contrato_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/propiedad_model.dart';
import '../../models/inquilino_model.dart';
import '../../models/periodo_fijo_model.dart';

// ════════════════════════════════════════════════════════════
// MAIN SCREEN
// ════════════════════════════════════════════════════════════

class ContratoFormScreen extends StatefulWidget {
  final Map<String, dynamic>? datosExistentes;

  const ContratoFormScreen({super.key, this.datosExistentes});

  @override
  State<ContratoFormScreen> createState() => _ContratoFormScreenState();
}

class _ContratoFormScreenState extends State<ContratoFormScreen> {
  static const _magenta = Color(0xFFC2185B);
  static const _navy = Color(0xFF1A3A5C);

  final DatabaseHelper _db = DatabaseHelper();
  bool _guardando = false;

  bool get _esEdicion => widget.datosExistentes != null;

  // ── Selecciones ───────────────────────────────────────────
  PropiedadModel? _propiedadSel;
  InquilinoModel? _inquilinoSel;
  List<PropiedadModel> _propiedades = [];
  List<InquilinoModel> _inquilinos = [];

  // ── Propietario ───────────────────────────────────────────
  List<Map<String, dynamic>> _propietariosRaw = [];
  int? _propietarioManualId; // usado cuando propiedad/inquilino no tienen propietario

  // ── Períodos ──────────────────────────────────────────────
  DateTime? _fechaInicio;
  int _cuotasTotal = 36;
  DateTime? _fechaFin;

  final _alquilerCtrl = TextEditingController(text: '0');
  final _hastaCuotaCtrl = TextEditingController(text: '12');
  List<PeriodoFijoModel> _periodosFijos = [];

  // ── Recargos ──────────────────────────────────────────────
  final _primerDiaPagoCtrl = TextEditingController(text: '1');
  final _diasGraciaCtrl = TextEditingController(text: '10');
  final _cobrarDesdiaDiaCtrl = TextEditingController(text: '1');
  final _pagoFinalCtrl = TextEditingController(text: '10');
  final _punitoriosPctCtrl = TextEditingController(text: '0');
  final _punitoriosFijosCtrl = TextEditingController(text: '0');

  // ── Rescindir ─────────────────────────────────────────────
  bool _rescindido = false;
  DateTime? _fechaRescision;

  // ── Garantes ──────────────────────────────────────────────
  List<Map<String, dynamic>> _garantes = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _alquilerCtrl.dispose();
    _hastaCuotaCtrl.dispose();
    _primerDiaPagoCtrl.dispose();
    _diasGraciaCtrl.dispose();
    _cobrarDesdiaDiaCtrl.dispose();
    _pagoFinalCtrl.dispose();
    _punitoriosPctCtrl.dispose();
    _punitoriosFijosCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    try {
      final props =
          await _db.obtenerPropiedades();
      final inqs = await _db.obtenerInquilinos();
      final propsRaw = await _db.obtenerPropietarios();

      final propiedades =
          props.map((m) => PropiedadModel.fromMap(m)).toList();
      final inquilinos =
          inqs.map((m) => InquilinoModel.fromMap(m)).toList();

      PropiedadModel? propSel;
      InquilinoModel? inqSel;

      if (_esEdicion) {
        final d = widget.datosExistentes!;
        final propId = d['propiedad_id'] as int?;
        final inqId = d['inquilino_id'] as int?;

        if (propId != null) {
          try {
            propSel = propiedades.firstWhere((p) => p.id == propId);
          } catch (_) {}
        }
        if (inqId != null) {
          try {
            inqSel = inquilinos.firstWhere((i) => i.id == inqId);
          } catch (_) {}
        }

        // Fechas
        final fi = d['fecha_inicio'] as String?;
        if (fi != null && fi.isNotEmpty) {
          try {
            _fechaInicio = DateTime.parse(fi);
          } catch (_) {}
        }
        final ff = d['fecha_fin'] as String?;
        if (ff != null && ff.isNotEmpty) {
          try {
            _fechaFin = DateTime.parse(ff);
          } catch (_) {}
        }

        _cuotasTotal = d['cuotas_total'] as int? ?? 36;

        _alquilerCtrl.text =
            (d['alquiler_primer_periodo'] as num? ?? 0).toString();
        _hastaCuotaCtrl.text =
            (d['hasta_cuota'] as int? ?? 12).toString();
        _primerDiaPagoCtrl.text =
            (d['primer_dia_pago'] as int? ?? 1).toString();
        _diasGraciaCtrl.text = (d['dias_gracia'] as int? ?? 10).toString();
        _cobrarDesdiaDiaCtrl.text =
            (d['punitorios_desde_dia'] as int? ?? 1).toString();
        _pagoFinalCtrl.text = (d['pago_final'] as int? ?? 10).toString();
        _punitoriosPctCtrl.text =
            (d['punitorios_porcentaje'] as num? ?? 0).toString();
        _punitoriosFijosCtrl.text =
            (d['punitorios_fijos'] as num? ?? 0).toString();

        _rescindido = (d['rescindido'] as int? ?? 0) == 1;
        final fr = d['fecha_rescision'] as String?;
        if (fr != null && fr.isNotEmpty) {
          try {
            _fechaRescision = DateTime.parse(fr);
          } catch (_) {}
        }

        // Cargar períodos fijos y garantes
        final contratoId = d['id'] as int?;
        if (contratoId != null) {
          final periodosMaps =
              await _db.obtenerPeriodosPorContrato(contratoId);
          _periodosFijos = periodosMaps
              .map((m) => PeriodoFijoModel.fromMap(m))
              .toList();
          _garantes = (await _db.obtenerGarantesPorContrato(contratoId))
              .map((g) => Map<String, dynamic>.from(g))
              .toList();
        }
      }

      if (mounted) {
        setState(() {
          _propiedades = propiedades;
          _inquilinos = inquilinos;
          _propiedadSel = propSel;
          _inquilinoSel = inqSel;
          _propietariosRaw = List<Map<String, dynamic>>.from(propsRaw);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
      }
    }
  }

  void _recalcularFin() {
    if (_fechaInicio == null) return;
    setState(() {
      _fechaFin = DateTime(
        _fechaInicio!.year,
        _fechaInicio!.month + _cuotasTotal,
        _fechaInicio!.day,
      );
    });
  }

  Future<void> _seleccionarFechaInicio() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaInicio ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _fechaInicio = picked);
      _recalcularFin();
    }
  }

  Future<void> _seleccionarFechaRescision() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaRescision ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _fechaRescision = picked);
    }
  }

  Future<void> _guardar() async {
    if (_propiedadSel == null && _inquilinoSel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Debe seleccionar al menos una propiedad o un inquilino'),
          backgroundColor: Color(0xFFC62828),
        ),
      );
      return;
    }

    final propietarioId = _propiedadSel?.propietarioId
        ?? _inquilinoSel?.propietarioId
        ?? _propietarioManualId;

    if (propietarioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Seleccione un propietario para el contrato'),
          backgroundColor: Color(0xFFC62828),
        ),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      final Map<String, dynamic> datos = {
        'propiedad_id': _propiedadSel?.id,
        'inquilino_id': _inquilinoSel?.id,
        'propietario_id': propietarioId,
        'fecha_inicio': _fechaInicio?.toIso8601String(),
        'cuotas_total': _cuotasTotal,
        'fecha_fin': _fechaFin?.toIso8601String(),
        'alquiler_primer_periodo':
            double.tryParse(_alquilerCtrl.text) ?? 0,
        'hasta_cuota': int.tryParse(_hastaCuotaCtrl.text) ?? 12,
        'extras': 0,
        'primer_dia_pago':
            int.tryParse(_primerDiaPagoCtrl.text) ?? 1,
        'dias_gracia': int.tryParse(_diasGraciaCtrl.text) ?? 10,
        'punitorios_desde_dia':
            int.tryParse(_cobrarDesdiaDiaCtrl.text) ?? 1,
        'pago_final': int.tryParse(_pagoFinalCtrl.text) ?? 10,
        'punitorios_porcentaje':
            double.tryParse(_punitoriosPctCtrl.text) ?? 0,
        'punitorios_fijos':
            double.tryParse(_punitoriosFijosCtrl.text) ?? 0,
        'rescindido': _rescindido ? 1 : 0,
        'fecha_rescision': _fechaRescision?.toIso8601String(),
        'fecha_alta': DateTime.now().toIso8601String(),
      };

      int contratoId;
      if (_esEdicion) {
        contratoId = widget.datosExistentes!['id'] as int;
        await _db.actualizarContrato(contratoId, datos);
      } else {
        contratoId = await _db.insertarContrato(datos);
      }

      // Upsert períodos fijos
      final periodosMaps = _periodosFijos
          .map((p) => {
                'cuota_desde': p.cuotaDesde,
                'cuota_hasta': p.cuotaHasta,
                'monto': p.monto,
              })
          .toList();
      await _db.upsertPeriodosFijos(contratoId, periodosMaps);

      // Upsert garantes
      await _db.upsertGarantes(contratoId, _garantes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_esEdicion
                ? 'Contrato actualizado correctamente'
                : 'Contrato registrado correctamente'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _abrirPropiedadDialog() async {
    final nueva = await showDialog<PropiedadModel>(
      context: context,
      builder: (_) => const PropiedadDialog(),
    );
    if (nueva != null && mounted) {
      final props = await _db.obtenerPropiedades();
      setState(() {
        _propiedades = props.map((m) => PropiedadModel.fromMap(m)).toList();
        _propiedadSel = nueva;
      });
    }
  }

  Future<void> _abrirPropietarioDialog() async {
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const PropietarioDialog(),
    );
    if (resultado != null && mounted) {
      // Recargar propietarios
      final props = await _db.obtenerPropietarios();
      _propietariosRaw = props;
      _propietarioManualId = resultado['propietario_id'] as int?;

      // Si se creó inquilino, recargar y auto-seleccionar
      final inquilinoId = resultado['inquilino_id'] as int?;
      if (inquilinoId != null) {
        final inqs = await _db.obtenerInquilinos();
        _inquilinos = inqs.map((m) => InquilinoModel.fromMap(m)).toList();
        _inquilinoSel = _inquilinos
            .where((i) => i.id == inquilinoId)
            .firstOrNull;
      }

      // Recargar propiedades (por si se creó domicilio)
      final propsData = await _db.obtenerPropiedades();
      _propiedades = propsData.map((m) => PropiedadModel.fromMap(m)).toList();

      setState(() {});
    }
  }

  Future<void> _abrirInquilinoDialog() async {
    // Determinar propietario actual para pasarlo al dialog
    final propIdActual = _propiedadSel?.propietarioId ?? _propietarioManualId;
    final nuevo = await showDialog<InquilinoModel>(
      context: context,
      builder: (_) => InquilinoDialog(propietarioId: propIdActual),
    );
    if (nuevo != null && mounted) {
      final inqs = await _db.obtenerInquilinos();
      setState(() {
        _inquilinos = inqs.map((m) => InquilinoModel.fromMap(m)).toList();
        _inquilinoSel = nuevo;
      });
    }
  }

  Future<void> _abrirPeriodosFijosDialog() async {
    final resultado = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (_) => PeriodosFijosDialog(periodosIniciales: _periodosFijos),
    );
    if (resultado != null && mounted) {
      setState(() {
        _periodosFijos = resultado
            .map((m) => PeriodoFijoModel(
                  contratoId: 0,
                  cuotaDesde: m['desde'] as int,
                  cuotaHasta: m['hasta'] as int,
                  monto: (m['monto'] as num).toDouble(),
                ))
            .toList();
      });
    }
  }

  // ── Helpers de formato ────────────────────────────────────

  String _fmtFecha(DateTime? d) {
    if (d == null) return 'Sin fecha';
    return DateFormat('dd/MM/yyyy').format(d);
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar Contrato' : 'Nuevo Contrato'),
        backgroundColor: _magenta,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Columna izquierda ─────────────────────
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _seccionPropiedad(),
                        const SizedBox(height: 16),
                        _seccionInquilino(),
                        const SizedBox(height: 16),
                        _seccionPeriodos(),
                      ],
                    ),
                  ),
                ),
                // Divider vertical
                const VerticalDivider(width: 1, thickness: 1),
                // ── Columna derecha ───────────────────────
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _seccionRecargos(),
                        const SizedBox(height: 16),
                        _seccionGarantes(),
                        const SizedBox(height: 16),
                        _seccionRescindir(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Botones inferiores ────────────────────────────
          _botonesInferiores(),
        ],
      ),
    );
  }

  // ── Sección Propiedad ─────────────────────────────────────

  Widget _seccionPropiedad() {
    return _seccionCard(
      titulo: 'Propiedad',
      icono: Icons.home_work_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _magenta,
                  side: const BorderSide(color: _magenta),
                ),
                onPressed: _abrirPropiedadDialog,
                icon: const Text('🏠', style: TextStyle(fontSize: 14)),
                label: const Text('Nueva propiedad'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<PropiedadModel?>(
                  isExpanded: true,
                  value: _propiedadSel,
                  hint: const Text('O Elegir...'),
                  onChanged: (v) => setState(() => _propiedadSel = v),
                  items: [
                    const DropdownMenuItem<PropiedadModel?>(
                      value: null,
                      child: Text('O Elegir...'),
                    ),
                    ..._propiedades.map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(
                          p.direccionCompleta,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_propiedadSel != null) ...[
            const SizedBox(height: 4),
            Text(
              'Propiedad: ${_propiedadSel!.direccionCompleta}',
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF1565C0)),
            ),
          ],
          const SizedBox(height: 10),
          _filaPropietario(),
        ],
      ),
    );
  }

  Widget _filaPropietario() {
    // Propietario derivado de la propiedad seleccionada
    if (_propiedadSel?.propietarioId != null) {
      final p = _propietariosRaw
          .where((m) => m['id'] == _propiedadSel!.propietarioId)
          .firstOrNull;
      final nombre = p?['nombre'] as String? ??
          'ID: ${_propiedadSel!.propietarioId}';
      return Row(
        children: [
          const Icon(Icons.person_pin_outlined,
              size: 14, color: Color(0xFF2E7D32)),
          const SizedBox(width: 4),
          Text('Propietario: $nombre',
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF2E7D32))),
        ],
      );
    }

    // Propietario derivado del inquilino seleccionado
    if (_inquilinoSel?.propietarioId != null) {
      final p = _propietariosRaw
          .where((m) => m['id'] == _inquilinoSel!.propietarioId)
          .firstOrNull;
      final nombre = p?['nombre'] as String? ??
          'ID: ${_inquilinoSel!.propietarioId}';
      return Row(
        children: [
          const Icon(Icons.person_pin_outlined,
              size: 14, color: Color(0xFF2E7D32)),
          const SizedBox(width: 4),
          Text('Propietario: $nombre',
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF2E7D32))),
        ],
      );
    }

    // Sin propietario derivado → botón Nuevo + dropdown (mismo patrón que Propiedad)
    return Row(
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: _magenta,
            side: const BorderSide(color: _magenta),
          ),
          onPressed: _abrirPropietarioDialog,
          icon: const Icon(Icons.person_add_outlined, size: 16),
          label: const Text('Nuevo Propietario'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButton<int?>(
            isExpanded: true,
            value: _propietarioManualId,
            hint: const Text('O Elegir...'),
            onChanged: (v) =>
                setState(() => _propietarioManualId = v),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('O Elegir...'),
              ),
              ..._propietariosRaw.map(
                (p) => DropdownMenuItem<int?>(
                  value: p['id'] as int?,
                  child: Text(
                    p['nombre'] as String? ?? '',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Sección Inquilino ─────────────────────────────────────

  Widget _seccionInquilino() {
    return _seccionCard(
      titulo: 'Inquilino',
      icono: Icons.person_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _magenta,
                  side: const BorderSide(color: _magenta),
                ),
                onPressed: _abrirInquilinoDialog,
                icon: const Text('👤', style: TextStyle(fontSize: 14)),
                label: const Text('Nuevo Inquilino'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<InquilinoModel?>(
                  isExpanded: true,
                  value: _inquilinoSel,
                  hint: const Text('O Elegir...'),
                  onChanged: (v) => setState(() => _inquilinoSel = v),
                  items: [
                    const DropdownMenuItem<InquilinoModel?>(
                      value: null,
                      child: Text('O Elegir...'),
                    ),
                    ..._inquilinos.map(
                      (i) => DropdownMenuItem(
                        value: i,
                        child: Text(
                          i.nombreCompleto,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_inquilinoSel != null) ...[
            const SizedBox(height: 4),
            Text(
              'Inquilino: ${_inquilinoSel!.nombreCompleto}',
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF1565C0)),
            ),
          ],
        ],
      ),
    );
  }

  // ── Sección Períodos ──────────────────────────────────────

  Widget _seccionPeriodos() {
    return _seccionCard(
      titulo: 'Períodos',
      icono: Icons.calendar_month_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila: fecha inicio, cuotas, fecha fin
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _seleccionarFechaInicio,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha inicio',
                      isDense: true,
                      suffixIcon: Icon(Icons.calendar_today, size: 16),
                    ),
                    child: Text(
                      _fmtFecha(_fechaInicio),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: TextFormField(
                  initialValue: _cuotasTotal.toString(),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Cuotas',
                    isDense: true,
                  ),
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n > 0) {
                      _cuotasTotal = n;
                      _recalcularFin();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha fin',
                    isDense: true,
                  ),
                  child: Text(
                    _fmtFecha(_fechaFin),
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF757575)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Botón períodos fijos
          Row(
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _magenta,
                  side: const BorderSide(color: _magenta),
                ),
                onPressed: _abrirPeriodosFijosDialog,
                icon: const Text('📅', style: TextStyle(fontSize: 14)),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Períodos fijos'),
                    if (_periodosFijos.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _magenta,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_periodosFijos.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Fila: alquiler, hasta cuota, extras
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _alquilerCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d*'))
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Alquiler 1er. período \$',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: TextFormField(
                  controller: _hastaCuotaCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Hasta cuota',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Sección Recargos ──────────────────────────────────────

  Widget _seccionRecargos() {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con fondo navy
          Container(
            width: double.infinity,
            color: _navy,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            child: Row(
              children: const [
                Icon(Icons.percent, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'Recargos',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _campoRecargo(
                    'Primer día de pago', _primerDiaPagoCtrl),
                const SizedBox(height: 8),
                _campoRecargo('Días de gracia', _diasGraciaCtrl),
                const SizedBox(height: 8),
                _campoRecargo(
                    'Cobrar a partir del día', _cobrarDesdiaDiaCtrl),
                const SizedBox(height: 8),
                _campoRecargo('Pago final', _pagoFinalCtrl),
                const SizedBox(height: 8),
                _campoRecargo(
                    'Punitorios % por día', _punitoriosPctCtrl),
                const SizedBox(height: 8),
                _campoRecargo(
                    r'Punitorios fijos por día $',
                    _punitoriosFijosCtrl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _campoRecargo(
      String label, TextEditingController controller) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF424242)),
          ),
        ),
        SizedBox(
          width: 80,
          child: TextField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
            ],
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  // ── Sección Garantes ───────────────────────────────────────

  Widget _seccionGarantes() {
    return _seccionCard(
      titulo: 'Garantes',
      icono: Icons.verified_user_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._garantes.asMap().entries.map((entry) {
            final i = entry.key;
            final g = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              color: const Color(0xFFF5F5F5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Garante ${i + 1}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12)),
                        const Spacer(),
                        InkWell(
                          onTap: () => setState(() => _garantes.removeAt(i)),
                          child: const Icon(Icons.close,
                              size: 18, color: Color(0xFFC62828)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: g['nombre'] as String? ?? '',
                      decoration: const InputDecoration(
                        labelText: 'Nombre *',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => _garantes[i]['nombre'] = v.trim(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: g['telefono'] as String? ?? '',
                            decoration: const InputDecoration(
                              labelText: 'Teléfono',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) =>
                                _garantes[i]['telefono'] = v.trim(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: g['email'] as String? ?? '',
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => _garantes[i]['email'] = v.trim(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Tipo de garantía:',
                        style: TextStyle(fontSize: 11, color: Color(0xFF757575))),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Recibo de sueldo',
                                style: TextStyle(fontSize: 12)),
                            value: 'recibo_sueldo',
                            groupValue:
                                g['tipo_garantia'] as String? ?? 'recibo_sueldo',
                            onChanged: (v) =>
                                setState(() => _garantes[i]['tipo_garantia'] = v),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Garantía propietaria',
                                style: TextStyle(fontSize: 12)),
                            value: 'garante_propietario',
                            groupValue:
                                g['tipo_garantia'] as String? ?? 'recibo_sueldo',
                            onChanged: (v) =>
                                setState(() => _garantes[i]['tipo_garantia'] = v),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.person_add_outlined, size: 18),
              label: const Text('Agregar garante'),
              style: OutlinedButton.styleFrom(foregroundColor: _navy),
              onPressed: () {
                setState(() {
                  _garantes.add({
                    'nombre': '',
                    'telefono': '',
                    'email': '',
                    'tipo_garantia': 'recibo_sueldo',
                  });
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Sección Rescindir ─────────────────────────────────────

  Widget _seccionRescindir() {
    return _seccionCard(
      titulo: 'Rescindir',
      icono: Icons.cancel_outlined,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _seleccionarFechaRescision,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Fecha rescisión',
                  isDense: true,
                  suffixIcon: Icon(Icons.calendar_today, size: 16),
                ),
                child: Text(
                  _fmtFecha(_fechaRescision),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: _rescindido,
                activeColor: const Color(0xFFC62828),
                onChanged: (v) => setState(() => _rescindido = v),
              ),
              Text(
                'Rescindir',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _rescindido
                      ? const Color(0xFFC62828)
                      : const Color(0xFF757575),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Botones inferiores ────────────────────────────────────

  Widget _botonesInferiores() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _guardando
                ? null
                : () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _magenta,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 12),
            ),
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_esEdicion ? 'Guardar cambios' : 'Guardar'),
          ),
        ],
      ),
    );
  }

  // ── Helper: sección con card ──────────────────────────────

  Widget _seccionCard({
    required String titulo,
    required IconData icono,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, size: 18, color: _magenta),
                const SizedBox(width: 8),
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _magenta,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// DIALOG: PropiedadDialog
// ════════════════════════════════════════════════════════════

class PropiedadDialog extends StatefulWidget {
  const PropiedadDialog({super.key});

  @override
  State<PropiedadDialog> createState() => _PropiedadDialogState();
}

class _PropiedadDialogState extends State<PropiedadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper();
  bool _guardando = false;

  final _carpetaCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _entreCallesCtrl = TextEditingController();
  final _provinciaCtrl = TextEditingController();
  final _localidadCtrl = TextEditingController();
  final _barrioCtrl = TextEditingController();
  final _codigoPostalCtrl = TextEditingController();

  String _tipo = 'Vivienda';
  String _estado = 'Disponible';

  static const _tipos = [
    'Vivienda',
    'Departamento',
    'Local',
    'Terreno',
    'Quinta',
    'Oficina',
    'Cochera',
    'Otro',
  ];

  static const _estados = [
    'Disponible',
    'Alquilado',
    'En venta',
    'Vendido',
    'Nulo',
  ];

  @override
  void dispose() {
    _carpetaCtrl.dispose();
    _direccionCtrl.dispose();
    _entreCallesCtrl.dispose();
    _provinciaCtrl.dispose();
    _localidadCtrl.dispose();
    _barrioCtrl.dispose();
    _codigoPostalCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final model = PropiedadModel(
        carpeta: _carpetaCtrl.text.trim(),
        tipo: _tipo,
        estado: _estado,
        direccion: _direccionCtrl.text.trim(),
        entreCalles: _entreCallesCtrl.text.trim(),
        provincia: _provinciaCtrl.text.trim(),
        localidad: _localidadCtrl.text.trim(),
        barrio: _barrioCtrl.text.trim(),
        codigoPostal: _codigoPostalCtrl.text.trim(),
      );
      final id = await _db.insertarPropiedad(model.toMap());
      final creado = model.copyWith(id: id);
      if (mounted) Navigator.pop(context, creado);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva Propiedad'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _campo(_carpetaCtrl, 'Carpeta (opcional)'),
                const SizedBox(height: 10),
                // Tipo
                DropdownButtonFormField<String>(
                  value: _tipo,
                  decoration: const InputDecoration(
                      labelText: 'Tipo', isDense: true),
                  items: _tipos
                      .map((t) => DropdownMenuItem(
                          value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _tipo = v);
                  },
                ),
                const SizedBox(height: 10),
                // Estado
                DropdownButtonFormField<String>(
                  value: _estado,
                  decoration: const InputDecoration(
                      labelText: 'Estado', isDense: true),
                  items: _estados
                      .map((e) => DropdownMenuItem(
                          value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _estado = v);
                  },
                ),
                const SizedBox(height: 10),
                _campoRequerido(
                    _direccionCtrl, 'Dirección *', 'La dirección es obligatoria'),
                const SizedBox(height: 10),
                _campo(_entreCallesCtrl, 'Entre calles'),
                const SizedBox(height: 10),
                _campo(_provinciaCtrl, 'Provincia'),
                const SizedBox(height: 10),
                _campo(_localidadCtrl, 'Localidad'),
                const SizedBox(height: 10),
                _campo(_barrioCtrl, 'Barrio'),
                const SizedBox(height: 10),
                _campo(_codigoPostalCtrl, 'Código postal'),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC2185B),
            foregroundColor: Colors.white,
          ),
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }

  Widget _campo(TextEditingController ctrl, String label) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label, isDense: true),
    );
  }

  Widget _campoRequerido(
      TextEditingController ctrl, String label, String errorMsg) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label, isDense: true),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? errorMsg : null,
    );
  }
}

// ════════════════════════════════════════════════════════════
// DIALOG: InquilinoDialog
// ════════════════════════════════════════════════════════════

class InquilinoDialog extends StatefulWidget {
  final int? propietarioId;
  final InquilinoModel? inquilinoExistente;
  const InquilinoDialog({super.key, this.propietarioId, this.inquilinoExistente});

  @override
  State<InquilinoDialog> createState() => _InquilinoDialogState();
}

class _InquilinoDialogState extends State<InquilinoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper();
  bool _guardando = false;

  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _domicilioCtrl = TextEditingController();
  final _localidadCtrl = TextEditingController();
  final _provinciaCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _celularCtrl = TextEditingController();
  final _telefonoAltCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // Propietario — se usa el que viene o se elige del dropdown
  int? _propietarioSelId;
  List<Map<String, dynamic>> _propietarios = [];

  @override
  void initState() {
    super.initState();
    _propietarioSelId = widget.propietarioId;
    // Si estamos editando, pre-cargar campos
    final e = widget.inquilinoExistente;
    if (e != null) {
      _nombreCtrl.text = e.nombre;
      _apellidoCtrl.text = e.apellido ?? '';
      _domicilioCtrl.text = e.domicilio ?? '';
      _localidadCtrl.text = e.localidad ?? '';
      _provinciaCtrl.text = e.provincia ?? '';
      _telefonoCtrl.text = e.telefono ?? '';
      _celularCtrl.text = e.celular ?? '';
      _telefonoAltCtrl.text = e.telefonoAlternativo ?? '';
      _emailCtrl.text = e.email ?? '';
      _propietarioSelId ??= e.propietarioId;
    }
    _cargarPropietarios();
  }

  Future<void> _cargarPropietarios() async {
    final data = await _db.obtenerPropietarios();
    if (mounted) setState(() => _propietarios = data);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _domicilioCtrl.dispose();
    _localidadCtrl.dispose();
    _provinciaCtrl.dispose();
    _telefonoCtrl.dispose();
    _celularCtrl.dispose();
    _telefonoAltCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_propietarioSelId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione un propietario'),
          backgroundColor: Color(0xFFC62828),
        ),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      final model = InquilinoModel(
        id: widget.inquilinoExistente?.id,
        nombre: _nombreCtrl.text.trim(),
        apellido: _apellidoCtrl.text.trim(),
        domicilio: _domicilioCtrl.text.trim(),
        localidad: _localidadCtrl.text.trim(),
        provincia: _provinciaCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim(),
        celular: _celularCtrl.text.trim(),
        telefonoAlternativo: _telefonoAltCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        propietarioId: _propietarioSelId,
      );
      if (widget.inquilinoExistente != null) {
        await _db.actualizarInquilino(model.id!, model.toMap());
        if (mounted) Navigator.pop(context, model);
      } else {
        final id = await _db.insertarInquilino(model.toMap());
        final creado = model.copyWith(id: id);
        if (mounted) Navigator.pop(context, creado);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.inquilinoExistente != null;
    return AlertDialog(
      title: Text(esEdicion ? 'Editar Inquilino' : 'Nuevo Inquilino'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dropdown propietario
                DropdownButtonFormField<int>(
                  value: _propietarioSelId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Propietario *',
                    isDense: true,
                    prefixIcon: Icon(Icons.person_outline, size: 18),
                  ),
                  items: _propietarios.map((p) {
                    return DropdownMenuItem<int>(
                      value: p['id'] as int,
                      child: Text(
                        p['nombre'] as String? ?? 'Sin nombre',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _propietarioSelId = v),
                  validator: (v) =>
                      v == null ? 'Seleccione un propietario' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Nombre *', isDense: true),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'El nombre es obligatorio'
                      : null,
                ),
                const SizedBox(height: 10),
                _campo(_apellidoCtrl, 'Apellido'),
                const SizedBox(height: 10),
                _campo(_domicilioCtrl, 'Domicilio'),
                const SizedBox(height: 10),
                _campo(_localidadCtrl, 'Localidad'),
                const SizedBox(height: 10),
                _campo(_provinciaCtrl, 'Provincia'),
                const SizedBox(height: 10),
                _campo(_telefonoCtrl, 'Teléfono'),
                const SizedBox(height: 10),
                _campo(_celularCtrl, 'Celular'),
                const SizedBox(height: 10),
                _campo(_telefonoAltCtrl, 'Teléfono alternativo'),
                const SizedBox(height: 10),
                _campo(_emailCtrl, 'E-mail'),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC2185B),
            foregroundColor: Colors.white,
          ),
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(esEdicion ? 'Actualizar' : 'Guardar'),
        ),
      ],
    );
  }

  Widget _campo(TextEditingController ctrl, String label) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label, isDense: true),
    );
  }
}

// ════════════════════════════════════════════════════════════
// DIALOG: PropietarioDialog
// ════════════════════════════════════════════════════════════

class PropietarioDialog extends StatefulWidget {
  const PropietarioDialog({super.key});

  @override
  State<PropietarioDialog> createState() => _PropietarioDialogState();
}

class _PropietarioDialogState extends State<PropietarioDialog> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper();
  bool _guardando = false;

  // Datos del Propietario
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // Datos del Inquilino (opcional)
  final _nombreInquilinoCtrl = TextEditingController();
  final _telefonoInquilinoCtrl = TextEditingController();

  // Domicilio del Alquiler (opcional)
  final _direccionCtrl = TextEditingController();
  final _localidadCtrl = TextEditingController();

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _nombreInquilinoCtrl.dispose();
    _telefonoInquilinoCtrl.dispose();
    _direccionCtrl.dispose();
    _localidadCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      // 1. Insertar propietario
      final propietarioId = await _db.insertarPropietario({
        'nombre': _nombreCtrl.text.trim(),
        'telefono': _telefonoCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
      });

      // 2. Insertar inquilino (si se completó el nombre)
      int? inquilinoId;
      if (_nombreInquilinoCtrl.text.trim().isNotEmpty) {
        inquilinoId = await _db.insertarInquilino({
          'nombre': _nombreInquilinoCtrl.text.trim(),
          'telefono': _telefonoInquilinoCtrl.text.trim(),
          'propietario_id': propietarioId,
        });
      }

      // 3. Insertar domicilio (si se completó la dirección)
      if (_direccionCtrl.text.trim().isNotEmpty) {
        await _db.insertarDomicilio({
          'direccion': _direccionCtrl.text.trim(),
          'localidad': _localidadCtrl.text.trim(),
          'propietario_id': propietarioId,
          'inquilino_id': inquilinoId,
        });
      }

      if (mounted) {
        Navigator.pop(context, {
          'propietario_id': propietarioId,
          'nombre': _nombreCtrl.text.trim(),
          'inquilino_id': inquilinoId,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo Propietario'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Datos del Propietario ────────────────
                _seccionTitulo('Datos del Propietario', Icons.person),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo *',
                    prefixIcon: Icon(Icons.badge_outlined, size: 20),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'El nombre es obligatorio'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _telefonoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    prefixIcon: Icon(Icons.phone_outlined, size: 20),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),

                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 8),

                // ── Datos del Inquilino ─────────────────
                _seccionTitulo('Datos del Inquilino', Icons.people),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nombreInquilinoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del inquilino',
                    prefixIcon: Icon(Icons.person_outline, size: 20),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _telefonoInquilinoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono del inquilino',
                    prefixIcon: Icon(Icons.phone_outlined, size: 20),
                  ),
                  keyboardType: TextInputType.phone,
                ),

                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 8),

                // ── Domicilio del Alquiler ──────────────
                _seccionTitulo('Domicilio del Alquiler', Icons.home),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _direccionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dirección',
                    prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _localidadCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Localidad / Ciudad',
                    prefixIcon: Icon(Icons.location_city_outlined, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC2185B),
            foregroundColor: Colors.white,
          ),
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Registrar Propietario'),
        ),
      ],
    );
  }

  Widget _seccionTitulo(String titulo, IconData icono) {
    return Row(
      children: [
        Icon(icono, size: 16, color: const Color(0xFFC2185B)),
        const SizedBox(width: 6),
        Text(titulo,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFFC2185B))),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
// DIALOG: PeriodosFijosDialog
// ════════════════════════════════════════════════════════════

class PeriodosFijosDialog extends StatefulWidget {
  final List<PeriodoFijoModel> periodosIniciales;

  const PeriodosFijosDialog({
    super.key,
    required this.periodosIniciales,
  });

  @override
  State<PeriodosFijosDialog> createState() =>
      _PeriodosFijosDialogState();
}

class _PeriodosFijosDialogState extends State<PeriodosFijosDialog> {
  late List<_FilaPeriodo> _filas;

  @override
  void initState() {
    super.initState();
    _filas = widget.periodosIniciales
        .map((p) => _FilaPeriodo(
              desdeCtrl: TextEditingController(
                  text: p.cuotaDesde.toString()),
              hastaCtrl: TextEditingController(
                  text: p.cuotaHasta.toString()),
              montoCtrl: TextEditingController(
                  text: p.monto.toString()),
            ))
        .toList();
    if (_filas.isEmpty) _agregarFila();
  }

  @override
  void dispose() {
    for (final f in _filas) {
      f.desdeCtrl.dispose();
      f.hastaCtrl.dispose();
      f.montoCtrl.dispose();
    }
    super.dispose();
  }

  void _agregarFila() {
    setState(() {
      _filas.add(_FilaPeriodo(
        desdeCtrl: TextEditingController(),
        hastaCtrl: TextEditingController(),
        montoCtrl: TextEditingController(),
      ));
    });
  }

  void _eliminarFila(int index) {
    _filas[index].desdeCtrl.dispose();
    _filas[index].hastaCtrl.dispose();
    _filas[index].montoCtrl.dispose();
    setState(() => _filas.removeAt(index));
  }

  void _guardar() {
    final resultado = _filas.map((f) {
      return {
        'desde': int.tryParse(f.desdeCtrl.text) ?? 0,
        'hasta': int.tryParse(f.hastaCtrl.text) ?? 0,
        'monto': double.tryParse(f.montoCtrl.text) ?? 0.0,
      };
    }).toList();
    Navigator.pop(context, resultado);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Períodos fijos de alquiler'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Encabezados
              Row(
                children: const [
                  Expanded(
                      child: Text('Desde cuota',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12))),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text('Hasta cuota',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12))),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text('Monto',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12))),
                  SizedBox(width: 36),
                ],
              ),
              const Divider(),
              // Filas
              ..._filas.asMap().entries.map((entry) {
                final i = entry.key;
                final f = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: f.desdeCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'Ej: 1',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: f.hastaCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'Ej: 12',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: f.montoCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*'))
                          ],
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'Ej: 50000',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Color(0xFFC62828), size: 20),
                        onPressed: () => _eliminarFila(i),
                        tooltip: 'Eliminar',
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _agregarFila,
                  icon: const Icon(Icons.add),
                  label: const Text('+ Agregar período'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC2185B),
            foregroundColor: Colors.white,
          ),
          onPressed: _guardar,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

/// Estructura interna para cada fila del diálogo de períodos
class _FilaPeriodo {
  final TextEditingController desdeCtrl;
  final TextEditingController hastaCtrl;
  final TextEditingController montoCtrl;

  _FilaPeriodo({
    required this.desdeCtrl,
    required this.hastaCtrl,
    required this.montoCtrl,
  });
}
