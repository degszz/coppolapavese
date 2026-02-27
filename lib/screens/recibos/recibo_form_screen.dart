import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/propietario_model.dart';
import '../../models/inquilino_model.dart';
import '../../models/domicilio_model.dart';
import '../../models/recibo_model.dart';
import '../../models/servicio_item_model.dart';
import 'recibo_preview_screen.dart';

class ReciboFormScreen extends StatefulWidget {
  final int? propietarioIdInicial;

  const ReciboFormScreen({super.key, this.propietarioIdInicial});

  @override
  State<ReciboFormScreen> createState() => _ReciboFormScreenState();
}

class _ReciboFormScreenState extends State<ReciboFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper();
  bool _guardando = false;

  // ── Listas desde BD ───────────────────────────────────────────
  List<PropietarioModel> _propietarios = [];
  List<InquilinoModel> _inquilinos = [];

  // ── Selecciones ───────────────────────────────────────────────
  PropietarioModel? _propietarioSel;
  InquilinoModel? _inquilinoSel;
  DomicilioModel? _domicilioSel;

  // ── Campos de texto ───────────────────────────────────────────
  final _domicilioCtrl = TextEditingController();
  final _localidadCtrl = TextEditingController();
  final _montoAbonadoCtrl = TextEditingController(text: '0');
  final _usuarioCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();

  // ── Fechas ────────────────────────────────────────────────────
  DateTime _fechaEmision = DateTime.now();
  DateTime _fechaVencimiento =
      DateTime.now().add(const Duration(days: 10));

  // ── Servicios (filas dinámicas) ───────────────────────────────
  final List<_FilaServicio> _servicios = [];

  // ── Cálculos ──────────────────────────────────────────────────
  double get _montoTotal =>
      _servicios.fold(0, (sum, s) => sum + s.total);
  double get _montoAbonado =>
      double.tryParse(_montoAbonadoCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _saldo => _montoTotal - _montoAbonado;
  String get _estado {
    if (_saldo <= 0) return 'pagado';
    if (_montoAbonado > 0) return 'parcial';
    return 'pendiente';
  }

  int _numeroRecibo = 0;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    final props = await _db.obtenerPropietarios();
    final numero = await _db.obtenerProximoNumeroRecibo();

    setState(() {
      _propietarios =
          props.map((p) => PropietarioModel.fromMap(p)).toList();
      _numeroRecibo = numero;
      // Agregar una fila de servicio vacía por defecto
      _servicios.add(_FilaServicio());
    });

    // Si viene de detalle de propietario, pre-seleccionar
    if (widget.propietarioIdInicial != null) {
      final prop = _propietarios.firstWhere(
        (p) => p.id == widget.propietarioIdInicial,
        orElse: () => _propietarios.first,
      );
      await _seleccionarPropietario(prop);
    }
  }

  Future<void> _seleccionarPropietario(PropietarioModel prop) async {
    final inqs = await _db
        .obtenerInquilinosPorPropietario(prop.id!);
    final doms = await _db
        .obtenerDomiciliosPorPropietario(prop.id!);

    final inquilinos =
        inqs.map((i) => InquilinoModel.fromMap(i)).toList();
    final domicilios =
        doms.map((d) => DomicilioModel.fromMap(d)).toList();

    setState(() {
      _propietarioSel = prop;
      _inquilinos = inquilinos;
      _inquilinoSel = inquilinos.isNotEmpty ? inquilinos.first : null;
      _domicilioSel = domicilios.isNotEmpty ? domicilios.first : null;
      if (_domicilioSel != null) {
        _domicilioCtrl.text = _domicilioSel!.direccion;
        _localidadCtrl.text = _domicilioSel!.localidad ?? '';
      } else {
        _domicilioCtrl.clear();
        _localidadCtrl.clear();
      }
    });
  }

  @override
  void dispose() {
    _domicilioCtrl.dispose();
    _localidadCtrl.dispose();
    _montoAbonadoCtrl.dispose();
    _usuarioCtrl.dispose();
    _notasCtrl.dispose();
    for (final s in _servicios) s.dispose();
    super.dispose();
  }

  // ── Guardar ───────────────────────────────────────────────────
  Future<void> _guardarYGenerar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_propietarioSel == null) {
      _mostrarError('Seleccioná un propietario');
      return;
    }
    if (_servicios.isEmpty || _servicios.every((s) => s.descripcion.isEmpty)) {
      _mostrarError('Agregá al menos un servicio');
      return;
    }

    setState(() => _guardando = true);

    try {
      // Guardar o actualizar domicilio si fue editado
      int? domicilioId = _domicilioSel?.id;
      if (_domicilioCtrl.text.trim().isNotEmpty &&
          _domicilioCtrl.text.trim() != (_domicilioSel?.direccion ?? '')) {
        domicilioId = await _db.insertarDomicilio({
          'direccion': _domicilioCtrl.text.trim(),
          'localidad': _localidadCtrl.text.trim(),
          'propietario_id': _propietarioSel!.id,
          'inquilino_id': _inquilinoSel?.id,
        });
      }

      final now = DateTime.now().toIso8601String();
      final reciboId = await _db.insertarRecibo({
        'numero_recibo': _numeroRecibo,
        'propietario_id': _propietarioSel!.id,
        'inquilino_id': _inquilinoSel?.id,
        'domicilio_id': domicilioId,
        'fecha_emision':
            DateFormat('yyyy-MM-dd').format(_fechaEmision),
        'fecha_vencimiento':
            DateFormat('yyyy-MM-dd').format(_fechaVencimiento),
        'monto_total': _montoTotal,
        'monto_abonado': _montoAbonado,
        'saldo': _saldo,
        'estado': _estado,
        'usuario': _usuarioCtrl.text.trim(),
        'notas': _notasCtrl.text.trim(),
        'created_at': now,
      });

      // Guardar servicios
      for (final s in _servicios) {
        if (s.descripcion.isNotEmpty) {
          await _db.insertarServicio({
            'recibo_id': reciboId,
            'descripcion': s.descripcion,
            'monto': s.monto,
            'punitorios': s.punitorios,
            'total': s.total,
          });
        }
      }

      // Construir ReciboModel para preview
      final recibo = ReciboModel(
        id: reciboId,
        numeroRecibo: _numeroRecibo,
        propietarioId: _propietarioSel!.id!,
        inquilinoId: _inquilinoSel?.id,
        domicilioId: domicilioId,
        fechaEmision: DateFormat('yyyy-MM-dd').format(_fechaEmision),
        fechaVencimiento:
            DateFormat('yyyy-MM-dd').format(_fechaVencimiento),
        montoTotal: _montoTotal,
        montoAbonado: _montoAbonado,
        saldo: _saldo,
        estado: _estado,
        usuario: _usuarioCtrl.text.trim(),
        notas: _notasCtrl.text.trim(),
        createdAt: now,
        propietarioNombre: _propietarioSel!.nombre,
        inquilinoNombre: _inquilinoSel?.nombre,
        direccion: _domicilioCtrl.text.trim(),
        localidad: _localidadCtrl.text.trim(),
        servicios: _servicios
            .where((s) => s.descripcion.isNotEmpty)
            .map((s) => ServicioItemModel(
                  reciboId: reciboId,
                  descripcion: s.descripcion,
                  monto: s.monto,
                  punitorios: s.punitorios,
                  total: s.total,
                ))
            .toList(),
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ReciboPreviewScreen(
              recibo: recibo,
              esNuevo: true,
            ),
          ),
        );
      }
    } catch (e) {
      _mostrarError('Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _vistaPrevia() async {
    if (_propietarioSel == null) {
      _mostrarError('Seleccioná un propietario');
      return;
    }
    final recibo = ReciboModel(
      numeroRecibo: _numeroRecibo,
      propietarioId: _propietarioSel!.id!,
      inquilinoId: _inquilinoSel?.id,
      fechaEmision: DateFormat('yyyy-MM-dd').format(_fechaEmision),
      fechaVencimiento:
          DateFormat('yyyy-MM-dd').format(_fechaVencimiento),
      montoTotal: _montoTotal,
      montoAbonado: _montoAbonado,
      saldo: _saldo,
      estado: _estado,
      usuario: _usuarioCtrl.text.trim(),
      notas: _notasCtrl.text.trim(),
      createdAt: DateTime.now().toIso8601String(),
      propietarioNombre: _propietarioSel!.nombre,
      inquilinoNombre: _inquilinoSel?.nombre,
      direccion: _domicilioCtrl.text.trim(),
      localidad: _localidadCtrl.text.trim(),
      servicios: _servicios
          .where((s) => s.descripcion.isNotEmpty)
          .map((s) => ServicioItemModel(
                descripcion: s.descripcion,
                monto: s.monto,
                punitorios: s.punitorios,
                total: s.total,
              ))
          .toList(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ReciboPreviewScreen(recibo: recibo, esNuevo: false),
      ),
    );
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFC62828),
      ),
    );
  }

  // ── Selección de fecha ────────────────────────────────────────
  Future<void> _seleccionarFecha({required bool esEmision}) async {
    final inicial = esEmision ? _fechaEmision : _fechaVencimiento;
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFC2185B),
            onSurface: Color(0xFF212121),
          ),
        ),
        child: child!,
      ),
    );
    if (seleccionada == null) return;
    setState(() {
      if (esEmision) {
        _fechaEmision = seleccionada;
      } else {
        _fechaVencimiento = seleccionada;
      }
    });
  }

  // ── UI ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final fmtMonto = NumberFormat.currency(
        locale: 'es_AR', symbol: '\$', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: Text('Recibo N° ${_numeroRecibo.toString().padLeft(4, '0')}'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── PROPIETARIO ──────────────────────────────────────
            _seccion(
              titulo: 'Partes del Contrato',
              icono: Icons.handshake_outlined,
              children: [
                _labelCampo('Propietario *'),
                DropdownButtonFormField<PropietarioModel>(
                  value: _propietarioSel,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person),
                    hintText: 'Seleccionar propietario',
                  ),
                  items: _propietarios
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(p.nombre),
                          ))
                      .toList(),
                  onChanged: (p) {
                    if (p != null) _seleccionarPropietario(p);
                  },
                  validator: (v) =>
                      v == null ? 'Seleccioná un propietario' : null,
                ),
                const SizedBox(height: 12),
                _labelCampo('Inquilino'),
                DropdownButtonFormField<InquilinoModel>(
                  value: _inquilinoSel,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.people_outline),
                    hintText: 'Se carga automáticamente',
                  ),
                  items: _inquilinos
                      .map((i) => DropdownMenuItem(
                            value: i,
                            child: Text(i.nombre),
                          ))
                      .toList(),
                  onChanged: (i) =>
                      setState(() => _inquilinoSel = i),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── DOMICILIO ────────────────────────────────────────
            _seccion(
              titulo: 'Domicilio del Alquiler',
              icono: Icons.home_outlined,
              children: [
                TextFormField(
                  controller: _domicilioCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dirección',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _localidadCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Localidad',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── FECHAS ───────────────────────────────────────────
            _seccion(
              titulo: 'Fechas',
              icono: Icons.calendar_today_outlined,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _selectorFecha(
                        label: 'Emisión',
                        fecha: fmt.format(_fechaEmision),
                        onTap: () =>
                            _seleccionarFecha(esEmision: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _selectorFecha(
                        label: 'Vencimiento',
                        fecha: fmt.format(_fechaVencimiento),
                        onTap: () =>
                            _seleccionarFecha(esEmision: false),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── SERVICIOS ────────────────────────────────────────
            _seccion(
              titulo: 'Servicios / Conceptos',
              icono: Icons.list_alt_outlined,
              children: [
                // Encabezado tabla
                const Row(
                  children: [
                    Expanded(
                        flex: 4,
                        child: Text('Descripción',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF757575)))),
                    Expanded(
                        flex: 2,
                        child: Text('Monto',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF757575)),
                            textAlign: TextAlign.center)),
                    Expanded(
                        flex: 2,
                        child: Text('Punitorios',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF757575)),
                            textAlign: TextAlign.center)),
                    Expanded(
                        flex: 2,
                        child: Text('Total',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF757575)),
                            textAlign: TextAlign.center)),
                    SizedBox(width: 32),
                  ],
                ),
                const Divider(),
                // Filas de servicios
                ..._servicios.asMap().entries.map((entry) {
                  final i = entry.key;
                  final s = entry.value;
                  return _filaServicio(s, i);
                }),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () =>
                      setState(() => _servicios.add(_FilaServicio())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar concepto'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC2185B),
                    side: const BorderSide(color: Color(0xFFC2185B)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── MONTOS RESUMEN ───────────────────────────────────
            _seccion(
              titulo: 'Resumen de Pago',
              icono: Icons.payments_outlined,
              children: [
                _filaResumen(
                    'Monto Total a Abonar:',
                    fmtMonto.format(_montoTotal),
                    const Color(0xFF1565C0)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Monto Abonado:',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: TextFormField(
                        controller: _montoAbonadoCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[\d,.]')),
                        ],
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(
                          prefixText: '\$ ',
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _filaResumen(
                  'Saldo:',
                  fmtMonto.format(_saldo),
                  _saldo > 0
                      ? const Color(0xFFC62828)
                      : const Color(0xFF2E7D32),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _colorEstado.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _colorEstado.withOpacity(0.4)),
                  ),
                  child: Text(
                    'Estado: ${_labelEstado}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _colorEstado,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── USUARIO / NOTAS ──────────────────────────────────
            _seccion(
              titulo: 'Datos Adicionales',
              icono: Icons.info_outline,
              children: [
                TextFormField(
                  controller: _usuarioCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Usuario / Responsable',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notasCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                    prefixIcon: Icon(Icons.notes_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── BOTONES ──────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _guardando ? null : _vistaPrevia,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Vista Previa'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC2185B),
                      side: const BorderSide(
                          color: Color(0xFFC2185B)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed:
                        _guardando ? null : _guardarYGenerar,
                    icon: _guardando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _guardando
                          ? 'Guardando...'
                          : 'Guardar y Generar',
                      style: const TextStyle(fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ── Fila de servicio dinámica ─────────────────────────────────
  Widget _filaServicio(_FilaServicio s, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: TextFormField(
              controller: s.descripcionCtrl,
              decoration: const InputDecoration(
                hintText: 'Concepto...',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onChanged: (v) {
                s.descripcion = v;
                setState(() {});
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: s.montoCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'[\d,.]')),
              ],
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                hintText: '0',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onChanged: (v) {
                s.monto =
                    double.tryParse(v.replaceAll(',', '.')) ?? 0;
                setState(() {});
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: s.punitioriosCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'[\d,.]')),
              ],
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                hintText: '0',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onChanged: (v) {
                s.punitorios =
                    double.tryParse(v.replaceAll(',', '.')) ?? 0;
                setState(() {});
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                NumberFormat.currency(
                        locale: 'es_AR',
                        symbol: '\$',
                        decimalDigits: 0)
                    .format(s.total),
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold),
                textAlign: TextAlign.right,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline,
                color: Color(0xFFC62828), size: 20),
            onPressed: _servicios.length > 1
                ? () => setState(() {
                      s.dispose();
                      _servicios.removeAt(index);
                    })
                : null,
            padding: EdgeInsets.zero,
            constraints:
                const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  // ── Widgets auxiliares ────────────────────────────────────────

  Widget _seccion({
    required String titulo,
    required IconData icono,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, size: 17, color: const Color(0xFFC2185B)),
                const SizedBox(width: 8),
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC2185B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _labelCampo(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF616161),
        ),
      ),
    );
  }

  Widget _selectorFecha({
    required String label,
    required String fecha,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFBDBDBD)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                size: 16, color: Color(0xFFC2185B)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF9E9E9E))),
                Text(fecha,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _filaResumen(String label, String valor, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
        Text(valor,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color)),
      ],
    );
  }

  Color get _colorEstado {
    switch (_estado) {
      case 'pagado':
        return const Color(0xFF2E7D32);
      case 'parcial':
        return const Color(0xFFF57C00);
      default:
        return const Color(0xFFC62828);
    }
  }

  String get _labelEstado {
    switch (_estado) {
      case 'pagado':
        return 'Pagado';
      case 'parcial':
        return 'Parcial';
      default:
        return 'Pendiente';
    }
  }
}

// ── Modelo interno para cada fila de servicio ─────────────────
class _FilaServicio {
  String descripcion = '';
  double monto = 0;
  double punitorios = 0;
  double get total => monto + punitorios;

  final descripcionCtrl = TextEditingController();
  final montoCtrl = TextEditingController();
  final punitioriosCtrl = TextEditingController();

  void dispose() {
    descripcionCtrl.dispose();
    montoCtrl.dispose();
    punitioriosCtrl.dispose();
  }
}
