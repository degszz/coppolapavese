// lib/screens/recibos/concepto_regular_dialog.dart
// Ventana flotante para crear / editar un Concepto Regular (imagen 2)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/concepto_regular_model.dart';
import '../../utils/snackbar_helper.dart';

// Sugerencias de conceptos comunes en alquileres
const _kConceptosSugeridos = [
  'Alquiler',
  'Expensas ordinarias',
  'Expensas extraordinarias',
  'Agua',
  'Gas',
  'Electricidad',
  'Teléfono',
  'Internet',
  'Seguro del inmueble',
  'Impuesto inmobiliario',
  'ABL',
  'Reparaciones',
  'Mantenimiento',
  'Honorarios administración',
  'Otros',
];

class ConceptoRegularDialog extends StatefulWidget {
  final int contratoId;
  final ConceptoRegularModel? existente; // null = nuevo

  const ConceptoRegularDialog({
    super.key,
    required this.contratoId,
    this.existente,
  });

  @override
  State<ConceptoRegularDialog> createState() => _ConceptoRegularDialogState();
}

class _ConceptoRegularDialogState extends State<ConceptoRegularDialog> {
  final _db = DatabaseHelper();
  final _formKey = GlobalKey<FormState>();

  // ── Campos ────────────────────────────────────────────────────
  final _conceptoCtrl = TextEditingController();
  bool _claro = true;
  bool _recordarPago = false;

  final _montoCtrl = TextEditingController(text: '0');
  bool _soloComprobante = false;
  final _porcentualCtrl = TextEditingController(text: '0,00');

  // Inquilino
  EfectoConcepto _efInq = EfectoConcepto.sinEfecto;
  bool _aplicaPunitorios = false;

  // Propietario
  EfectoConcepto _efProp = EfectoConcepto.sinEfecto;
  bool _aplicaAdmin = false;
  bool _aplicaTodos = true;
  String? _propEspecifico;
  bool _entregarComprobanteProp = false;

  // Período
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  PeriodoTipo _periodoTipo = PeriodoTipo.todos;
  final List<bool> _meses = List.filled(12, false); // índice 0=Ene … 11=Dic

  bool _guardando = false;

  static const _navy    = Color(0xFF1A3A5C);
  static const _magenta = Color(0xFFC2185B);
  static const _green   = Color(0xFF2E7D32);
  static const _blue    = Color(0xFF1565C0);

  static const _mesesNombres = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existente;
    if (e != null) {
      _conceptoCtrl.text = e.descripcion ?? '';
      _claro = e.claro;
      _recordarPago = e.recordarPago;
      _montoCtrl.text = e.monto.toStringAsFixed(2).replaceAll('.', ',');
      _soloComprobante = e.tieneComprobante;
      _porcentualCtrl.text = e.porcentual.toStringAsFixed(2).replaceAll('.', ',');
      _efInq = e.efectoInquilino;
      _aplicaPunitorios = e.aplicaPunitoriosInquilino;
      _efProp = e.efectoPropietario;
      _aplicaAdmin = e.aplicaAdministracion;
      _aplicaTodos = e.aplicaTodos;
      _propEspecifico = e.propietarioEspecifico;
      _entregarComprobanteProp = e.entregarComprobanteProp;
      if (e.fechaInicio != null) {
        try { _fechaInicio = DateTime.parse(e.fechaInicio!); } catch (_) {}
      }
      if (e.fechaFin != null) {
        try { _fechaFin = DateTime.parse(e.fechaFin!); } catch (_) {}
      }
      _periodoTipo = e.periodoTipo;
      for (final m in e.mesesLista) {
        if (m >= 1 && m <= 12) _meses[m - 1] = true;
      }
    }
  }

  @override
  void dispose() {
    _conceptoCtrl.dispose();
    _montoCtrl.dispose();
    _porcentualCtrl.dispose();
    super.dispose();
  }

  double get _monto =>
      double.tryParse(_montoCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _porcentual =>
      double.tryParse(_porcentualCtrl.text.replaceAll(',', '.')) ?? 0;

  String get _mesesStr {
    final lista = <String>[];
    for (int i = 0; i < 12; i++) {
      if (_meses[i]) lista.add('${i + 1}');
    }
    return lista.join(',');
  }

  ConceptoRegularModel _buildModelo() => ConceptoRegularModel(
        id: widget.existente?.id,
        contratoId: widget.contratoId,
        descripcion: _conceptoCtrl.text.trim(),
        monto: _monto,
        porcentual: _porcentual,
        tieneComprobante: _soloComprobante,
        tipo: TipoConcepto.regular,
        efectoInquilino: _efInq,
        aplicaPunitoriosInquilino: _aplicaPunitorios,
        efectoPropietario: _efProp,
        aplicaAdministracion: _aplicaAdmin,
        entregarComprobanteProp: _entregarComprobanteProp,
        aplicaTodos: _aplicaTodos,
        propietarioEspecifico: _aplicaTodos ? null : _propEspecifico,
        claro: _claro,
        recordarPago: _recordarPago,
        fechaInicio:
            _fechaInicio != null ? DateFormat('yyyy-MM-dd').format(_fechaInicio!) : null,
        fechaFin:
            _fechaFin != null ? DateFormat('yyyy-MM-dd').format(_fechaFin!) : null,
        periodoTipo: _periodoTipo,
        meses: _periodoTipo == PeriodoTipo.especifico ? _mesesStr : null,
      );

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final modelo = _buildModelo();
      if (widget.existente?.id != null) {
        await _db.actualizarConcepto(widget.existente!.id!, modelo.toMap());
      } else {
        await _db.insertarConcepto(modelo.toMap());
      }
      if (mounted) Navigator.pop(context, modelo);
    } catch (e) {
      if (mounted) {
        mostrarNotificacion(context,
            texto: 'Error al guardar: $e',
            color: const Color(0xFFC62828));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _eliminar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar concepto'),
        content: const Text('¿Eliminar este concepto regular?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true && widget.existente?.id != null) {
      await _db.eliminarConcepto(widget.existente!.id!);
      if (mounted) Navigator.pop(context, null); // null = eliminado
    }
  }

  Future<void> _pickFecha({required bool esInicio}) async {
    final ini = esInicio
        ? (_fechaInicio ?? DateTime.now())
        : (_fechaFin ?? DateTime.now().add(const Duration(days: 365)));
    final sel = await showDatePicker(
      context: context,
      initialDate: ini,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              const ColorScheme.light(primary: _magenta, onSurface: Colors.black87),
        ),
        child: child!,
      ),
    );
    if (sel != null) {
      setState(() {
        if (esInicio) { _fechaInicio = sel; } else { _fechaFin = sel; }
      });
    }
  }

  // ────────────────────────────────────────────────────────────────
  // BUILD
  // ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.existente != null;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Título ────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: _navy,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_outlined,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(esEdicion ? 'Editar Concepto Regular' : 'Concepto regular',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // ── Contenido ─────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Concepto + Claro + Recordar ──────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: _campo(
                              label: 'Concepto',
                              child: Autocomplete<String>(
                                initialValue:
                                    TextEditingValue(text: _conceptoCtrl.text),
                                optionsBuilder: (v) => v.text.isEmpty
                                    ? _kConceptosSugeridos
                                    : _kConceptosSugeridos.where((s) => s
                                        .toLowerCase()
                                        .contains(v.text.toLowerCase())),
                                onSelected: (s) =>
                                    setState(() => _conceptoCtrl.text = s),
                                fieldViewBuilder:
                                    (ctx, ctrl, focus, onSubmit) =>
                                        TextFormField(
                                  controller: ctrl,
                                  focusNode: focus,
                                  decoration: const InputDecoration(
                                    hintText: 'Nombre del concepto',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 10),
                                  ),
                                  onChanged: (v) => _conceptoCtrl.text = v,
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Requerido'
                                          : null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _checkboxLabel('Claro', _claro,
                              (v) => setState(() => _claro = v ?? true)),
                          const SizedBox(width: 12),
                          _checkboxLabel('Recordar pago', _recordarPago,
                              (v) => setState(() => _recordarPago = v ?? false)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── Monto + Solo Comprobante + Porcentual ─
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: 130,
                            child: _campo(
                              label: 'Monto',
                              child: TextFormField(
                                controller: _montoCtrl,
                                keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[\d,.]')),
                                ],
                                decoration: const InputDecoration(
                                  prefixText: '\$ ',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 10),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _checkboxLabel(
                              'Solo Entregar Comprobante',
                              _soloComprobante,
                              (v) =>
                                  setState(() => _soloComprobante = v ?? false)),
                          const Spacer(),
                          SizedBox(
                            width: 110,
                            child: _campo(
                              label: '% del alquiler',
                              child: TextFormField(
                                controller: _porcentualCtrl,
                                keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[\d,.]')),
                                ],
                                decoration: const InputDecoration(
                                  suffixText: '%',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── Inquilino / Propietarios (2 columnas) ─
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Inquilino
                          Expanded(
                            child: _seccionCard(
                              titulo: 'Inquilino',
                              color: _blue,
                              children: [
                                _radioEfecto(
                                  value: EfectoConcepto.sinEfecto,
                                  label: 'Sin efecto',
                                  groupValue: _efInq,
                                  onChanged: (v) =>
                                      setState(() => _efInq = v!),
                                ),
                                _radioEfecto(
                                  value: EfectoConcepto.sumar,
                                  label: 'Sumar al pago',
                                  groupValue: _efInq,
                                  onChanged: (v) =>
                                      setState(() => _efInq = v!),
                                ),
                                _radioEfecto(
                                  value: EfectoConcepto.descontar,
                                  label: 'Descontar al pago',
                                  groupValue: _efInq,
                                  onChanged: (v) =>
                                      setState(() => _efInq = v!),
                                ),
                                const SizedBox(height: 4),
                                _checkboxLabel(
                                    'Aplica Punitorios',
                                    _aplicaPunitorios,
                                    (v) => setState(
                                        () => _aplicaPunitorios = v ?? false)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Propietarios
                          Expanded(
                            child: _seccionCard(
                              titulo: 'Propietarios',
                              color: _green,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _radioEfecto(
                                            value: EfectoConcepto.sinEfecto,
                                            label: 'Sin efecto',
                                            groupValue: _efProp,
                                            onChanged: (v) =>
                                                setState(() => _efProp = v!),
                                          ),
                                          _radioEfecto(
                                            value: EfectoConcepto.sumar,
                                            label: 'Sumar a lo que cobra',
                                            groupValue: _efProp,
                                            onChanged: (v) =>
                                                setState(() => _efProp = v!),
                                          ),
                                          _radioEfecto(
                                            value: EfectoConcepto.descontar,
                                            label: 'Descontar de lo que cobra',
                                            groupValue: _efProp,
                                            onChanged: (v) =>
                                                setState(() => _efProp = v!),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _checkboxLabel(
                                            'Aplica Adm.',
                                            _aplicaAdmin,
                                            (v) => setState(() =>
                                                _aplicaAdmin = v ?? false)),
                                        _checkboxLabel(
                                            'Entregar comprobante',
                                            _entregarComprobanteProp,
                                            (v) => setState(() =>
                                                _entregarComprobanteProp =
                                                    v ?? false)),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _checkboxLabel(
                                        'Todos',
                                        _aplicaTodos,
                                        (v) => setState(
                                            () => _aplicaTodos = v ?? true)),
                                    const SizedBox(width: 8),
                                    if (!_aplicaTodos)
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: _propEspecifico,
                                          decoration: const InputDecoration(
                                            labelText: 'Propietario',
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 8),
                                          ),
                                          onChanged: (v) => setState(
                                              () => _propEspecifico = v),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── Período de Aplicación ─────────────────
                      _seccionCard(
                        titulo: 'Período de Aplicación',
                        color: _navy,
                        children: [
                          // Fechas
                          Row(
                            children: [
                              _fechaBtn(
                                  label: 'Fecha Inicio',
                                  fecha: _fechaInicio,
                                  onTap: () => _pickFecha(esInicio: true)),
                              const SizedBox(width: 16),
                              _fechaBtn(
                                  label: 'Fecha Fin',
                                  fecha: _fechaFin,
                                  onTap: () => _pickFecha(esInicio: false)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Radio tipos período
                          Row(
                            children: [
                              _radioPeriodo(PeriodoTipo.todos, 'Todos'),
                              const SizedBox(width: 12),
                              _radioPeriodo(PeriodoTipo.pares, 'Meses Pares'),
                              const SizedBox(width: 12),
                              _radioPeriodo(
                                  PeriodoTipo.impares, 'Meses Impares'),
                              const SizedBox(width: 12),
                              _radioPeriodo(
                                  PeriodoTipo.especifico, 'Específico'),
                            ],
                          ),
                          // Checkboxes de meses (solo si tipo=especifico)
                          if (_periodoTipo == PeriodoTipo.especifico) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 4,
                              runSpacing: 0,
                              children: List.generate(12, (i) {
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Checkbox(
                                      value: _meses[i],
                                      onChanged: (v) =>
                                          setState(() => _meses[i] = v ?? false),
                                      activeColor: _navy,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    Text(_mesesNombres[i],
                                        style: const TextStyle(fontSize: 11)),
                                    const SizedBox(width: 4),
                                  ],
                                );
                              }),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),

            // ── Botones ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
              ),
              child: Row(
                children: [
                  if (esEdicion)
                    OutlinedButton.icon(
                      onPressed: _guardando ? null : _eliminar,
                      icon: const Icon(Icons.delete_outline,
                          size: 16, color: Colors.red),
                      label: const Text('Eliminar',
                          style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _guardando ? null : _guardar,
                    icon: _guardando
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined,
                            size: 16, color: Colors.white),
                    label: const Text('Guardar y Salir',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: _navy),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widget helpers ────────────────────────────────────────────
  Widget _campo({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF616161))),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  Widget _seccionCard({
    required String titulo,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withAlpha(80)),
        borderRadius: BorderRadius.circular(6),
        color: color.withAlpha(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _checkboxLabel(
      String label, bool value, void Function(bool?) onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: _navy,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _radioEfecto({
    required EfectoConcepto value,
    required String label,
    required EfectoConcepto groupValue,
    required void Function(EfectoConcepto?) onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<EfectoConcepto>(
          value: value,
          groupValue: groupValue,
          onChanged: onChanged,
          activeColor: _navy,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _radioPeriodo(PeriodoTipo value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<PeriodoTipo>(
          value: value,
          groupValue: _periodoTipo,
          onChanged: (v) => setState(() => _periodoTipo = v!),
          activeColor: _navy,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _fechaBtn({
    required String label,
    required DateTime? fecha,
    required VoidCallback onTap,
  }) {
    final fmt = DateFormat('dd/MM/yyyy');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFBDBDBD)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 14, color: _magenta),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 9, color: Color(0xFF9E9E9E))),
                Text(
                  fecha != null ? fmt.format(fecha) : 'Seleccionar',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
