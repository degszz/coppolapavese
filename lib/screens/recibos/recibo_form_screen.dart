// MODIFICADO v4 — recibo_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/recibo_model.dart';
import '../../models/servicio_item_model.dart';
import '../../models/concepto_regular_model.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/whatsapp_launcher.dart';
import 'recibo_blanco_screen.dart';
import 'recibo_preview_screen.dart';

class ReciboFormScreen extends StatefulWidget {
  final int? contratoIdInicial;
  final int? propietarioIdInicial; // legacy — ignored if contratoIdInicial given
  final DateTime? fechaEmisionInicial;
  final DateTime? fechaVencimientoInicial;

  const ReciboFormScreen({
    super.key,
    this.contratoIdInicial,
    this.propietarioIdInicial,
    this.fechaEmisionInicial,
    this.fechaVencimientoInicial,
  });

  @override
  State<ReciboFormScreen> createState() => _ReciboFormScreenState();
}

class _ReciboFormScreenState extends State<ReciboFormScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper();
  bool _guardando = false;

  // ── Formato moneda para notas ──────────────────────────────────
  static final _fmtPesos = NumberFormat.currency(
      locale: 'es_AR', symbol: '\$', decimalDigits: 0, customPattern: '¤#,##0');

  // ── Contratos desde BD ────────────────────────────────────────
  List<Map<String, dynamic>> _contratos = [];
  Map<String, dynamic>? _contratoSel;

  // ── Datos auto-rellenados desde el contrato ───────────────────
  int? _propietarioId;
  String? _propietarioNombre;
  int? _inquilinoId;
  String? _inquilinoNombre;
  int _numeroCuota = 1;
  int _cuotasTotal = 0;

  // ── Campos de texto ───────────────────────────────────────────
  final _domicilioCtrl = TextEditingController();
  final _localidadCtrl = TextEditingController();
  final _montoAbonadoCtrl = TextEditingController(text: '0');
  final _usuarioCtrl = TextEditingController();

  // ── Fechas ────────────────────────────────────────────────────
  DateTime _fechaEmision = DateTime.now();
  DateTime _fechaVencimiento = DateTime.now().add(const Duration(days: 10));

  // ── Servicios dinámicos ───────────────────────────────────────
  final List<_FilaServicio> _servicios = [];


  // ── Estado del formulario "Concepto Único" (Tab 2 — sección inferior) ─
  DateTime? _uniVence;
  final _uniDescCtrl   = TextEditingController();
  final _uniMontoCtrl  = TextEditingController(text: '0');
  EfectoConcepto _uniEfectoInq   = EfectoConcepto.sinEfecto;
  bool           _uniAplicaPunit = false;
  EfectoConcepto _uniEfectoProp  = EfectoConcepto.sinEfecto;
  bool           _uniAplicaAdmin = false;
  bool           _uniAplicaTodos = true;

  // ── Cálculos ──────────────────────────────────────────────────
  double get _montoTotal => _servicios.fold(0, (sum, s) => sum + s.total);
  double get _montoAbonado =>
      double.tryParse(_montoAbonadoCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _saldo => _montoTotal - _montoAbonado;
  String get _estado {
    if (_saldo <= 0) return 'pagado';
    if (_montoAbonado > 0) return 'parcial';
    return 'pendiente';
  }

  int _numeroRecibo = 0;

  // ── TabController ─────────────────────────────────────────────
  late TabController _tabController;

  // ── Configuración del período ─────────────────────────────────
  final _diasGraciaCtrl = TextEditingController(text: '10');
  final _punitoriosDesdeCtrl = TextEditingController(text: '1');
  DateTime? _fechaAlta;

  // ── Tab 3: Notas y Recordatorios ─────────────────────────────
  final _notasReciboCtrl = TextEditingController();
  final _recordatorioInqCtrl = TextEditingController(
    text: 'Recuerde que el contrato de alquiler está próximo a vencer',
  );
  final _recordatorioPropCtrl = TextEditingController(
    text:
        'Recuerde que el contrato de alquiler de la calle [domicilio] está próximo a vencer',
  );
  bool _alertarInq = true;
  bool _imprimirRecInq = true;
  bool _alertarProp = true;
  bool _imprimirRecProp = true;

  // ── Helper: genera la nota de período para el pie del recibo ───
  /// Devuelve un par (descripcion, notaPeriodo) para la cuota [numeroCuota]
  /// emitida en la fecha [fechaEmision].
  ///
  /// La nota incluye:
  /// - Mes numérico y año (ej. "Alquiler mes 5/2026")
  /// - Posición dentro del período vigente (ej. "Mes 3 de 6")
  /// - Meses restantes hasta cambio de período
  /// - Monto del siguiente período (si existe y la cuota es la última o
  ///   está cerca del cambio)
  ({String descripcion, String notaPeriodo}) _generarNotaPeriodo({
    required int numeroCuota,
    required DateTime fechaEmision,
    required List<Map<String, dynamic>> periodosData,
  }) {
    final mes = fechaEmision.month.toString().padLeft(2, '0');
    final anio = fechaEmision.year;
    final desc = 'Alquiler mes $mes/$anio';
    final nota = StringBuffer('Alquiler mes $mes/$anio.');

    if (periodosData.isNotEmpty) {
      // Buscar el período al que pertenece esta cuota
      Map<String, dynamic>? periodoActual;
      int periodoIndex = -1;
      for (int i = 0; i < periodosData.length; i++) {
        final desde = periodosData[i]['cuota_desde'] as int;
        final hasta = periodosData[i]['cuota_hasta'] as int;
        if (numeroCuota >= desde && numeroCuota <= hasta) {
          periodoActual = periodosData[i];
          periodoIndex = i;
          break;
        }
      }

      if (periodoActual != null) {
        final desde = periodoActual['cuota_desde'] as int;
        final hasta = periodoActual['cuota_hasta'] as int;
        final totalMesesPeriodo = hasta - desde + 1;
        final mesActualEnPeriodo = numeroCuota - desde + 1;
        final restantes = hasta - numeroCuota;

        nota.write(' Mes $mesActualEnPeriodo de $totalMesesPeriodo'
            ' del período vigente (cuotas $desde–$hasta).');

        if (restantes == 0) {
          nota.write(' Última cuota de este período.');
        } else {
          nota.write(
              ' Faltan $restantes mes${restantes == 1 ? '' : 'es'}'
              ' para el cambio de período.');
        }
      }
    }

    return (descripcion: desc, notaPeriodo: nota.toString());
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _inicializar();
  }

  Future<void> _inicializar() async {
    final contratos = await _db.obtenerContratosActivos();
    final numero = await _db.obtenerProximoNumeroRecibo();
    setState(() {
      _contratos = contratos;
      _numeroRecibo = numero;
      _servicios.add(_FilaServicio());
      if (widget.fechaEmisionInicial != null) {
        _fechaEmision = widget.fechaEmisionInicial!;
      }
      if (widget.fechaVencimientoInicial != null) {
        _fechaVencimiento = widget.fechaVencimientoInicial!;
      }
    });
    // Auto-select: priorizar contratoIdInicial matcheando SOLO contra c['id'].
    // IMPORTANTE: nunca mezclar contrato_id con propietario_id en el mismo
    // firstWhere — son IDs de tablas distintas y pueden coincidir
    // numéricamente, lo que derivaría al contrato equivocado.
    if (contratos.isNotEmpty) {
      Map<String, dynamic>? match;
      if (widget.contratoIdInicial != null) {
        // Match EXACTO por id de contrato; si no existe (fue borrado,
        // rescindido, etc.) NO caemos a otro contrato, dejamos sin seleccionar.
        final idBuscar = widget.contratoIdInicial;
        try {
          match = contratos.firstWhere((c) => c['id'] == idBuscar);
        } catch (_) {
          match = null;
        }
      } else if (widget.propietarioIdInicial != null) {
        // Caso legacy: si solo se pasó propietarioIdInicial, buscamos
        // el primer contrato de ese propietario.
        final propId = widget.propietarioIdInicial;
        try {
          match = contratos.firstWhere((c) => c['propietario_id'] == propId);
        } catch (_) {
          match = null;
        }
      }
      if (match != null) {
        await _seleccionarContrato(match);
      }
    }
  }

  Future<void> _seleccionarContrato(Map<String, dynamic> c) async {
    final contratoId = c['id'] as int;
    final numeroCuota = await _db.obtenerNumCuotaParaContrato(contratoId);
    final monto = await _db.obtenerMontoPeriodo(contratoId, numeroCuota);
    final cuotasTotal = (c['cuotas_total'] as int?) ?? 0;

    // Cargar servicios del último recibo (para pre-cargar conceptos únicos)
    final serviciosPrev = await _db.obtenerServiciosUltimoRecibo(contratoId);

    // Cargar períodos fijos para generar nota de caducidad
    final periodosData = await _db.obtenerPeriodosPorContrato(contratoId);

    // Build inquilino name
    final inqNombre = c['inquilino_nombre'] as String? ?? '';
    final inqApellido = c['inquilino_apellido'] as String? ?? '';
    final inqCompleto =
        inqApellido.isNotEmpty ? '$inqNombre $inqApellido' : inqNombre;

    final direccion = c['propiedad_direccion'] as String? ?? '';
    final localidad = c['propiedad_localidad'] as String? ?? '';

    // Descripción y nota de período con mes numérico
    final now = DateTime.now();
    final (:descripcion, :notaPeriodo) = _generarNotaPeriodo(
      numeroCuota: numeroCuota,
      fechaEmision: now,
      periodosData: periodosData,
    );
    final desc = descripcion;

    setState(() {
      _contratoSel = c;
      _propietarioId = c['propietario_id'] as int?;
      _propietarioNombre = c['propietario_nombre'] as String?;
      _inquilinoId = c['inquilino_id'] as int?;
      _inquilinoNombre = inqCompleto.isNotEmpty ? inqCompleto : null;
      _numeroCuota = numeroCuota;
      _cuotasTotal = cuotasTotal;
      _domicilioCtrl.text = direccion;
      _localidadCtrl.text = localidad;
      _notasReciboCtrl.text = notaPeriodo;

      // Limpiar servicios previos
      for (final s in _servicios) { s.dispose(); }
      _servicios.clear();

      // Fila principal con monto del período
      final filaAlquiler = _FilaServicio();
      if (monto > 0) {
        filaAlquiler.descripcion = desc;
        filaAlquiler.descripcionCtrl.text = desc;
        filaAlquiler.monto = monto;
        filaAlquiler.montoCtrl.text = monto.toStringAsFixed(0);
      }
      _servicios.add(filaAlquiler);

      // Pre-cargar servicios del último recibo (excepto el alquiler principal)
      for (final sp in serviciosPrev) {
        final spDesc = sp['descripcion'] as String? ?? '';
        // Saltar si es el concepto de alquiler principal (ya agregado arriba)
        if (spDesc.startsWith('Alquiler ')) continue;
        final fila = _FilaServicio();
        fila.descripcion = spDesc;
        fila.descripcionCtrl.text = spDesc;
        fila.monto = (sp['monto'] as num?)?.toDouble() ?? 0;
        fila.montoCtrl.text = fila.monto.toStringAsFixed(0);
        fila.fechaVence = sp['fecha_vence'] as String?;
        _servicios.add(fila);
      }

      // Update recordatorio propietario
      final txt = _recordatorioPropCtrl.text;
      if (txt.contains('[domicilio]') && direccion.isNotEmpty) {
        _recordatorioPropCtrl.text = txt.replaceAll('[domicilio]', direccion);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _domicilioCtrl.dispose();
    _localidadCtrl.dispose();
    _montoAbonadoCtrl.dispose();
    _usuarioCtrl.dispose();
    _diasGraciaCtrl.dispose();
    _punitoriosDesdeCtrl.dispose();
    _notasReciboCtrl.dispose();
    _recordatorioInqCtrl.dispose();
    _recordatorioPropCtrl.dispose();
    _uniDescCtrl.dispose();
    _uniMontoCtrl.dispose();
    for (final s in _servicios) { s.dispose(); }
    super.dispose();
  }

  // ── Construir ReciboModel desde el estado actual ──────────────
  ReciboModel _buildReciboModel({int? reciboId, bool sinPunitorios = false}) {
    final servicios = _servicios
        .where((s) => s.descripcion.isNotEmpty)
        .map((s) => ServicioItemModel(
              reciboId: reciboId,
              descripcion: s.descripcion,
              monto: s.monto,
              punitorios: sinPunitorios ? 0 : s.punitorios,
              total: sinPunitorios ? s.monto : s.total,
              fechaVence: s.fechaVence,
            ))
        .toList();
    final montoTotalSP =
        _servicios.fold<double>(0, (sum, s) => sum + s.monto);
    return ReciboModel(
      id: reciboId,
      numeroRecibo: _numeroRecibo,
      propietarioId: _propietarioId ?? 0,
      inquilinoId: _inquilinoId,
      fechaEmision: DateFormat('yyyy-MM-dd').format(_fechaEmision),
      fechaVencimiento: DateFormat('yyyy-MM-dd').format(_fechaVencimiento),
      montoTotal: sinPunitorios ? montoTotalSP : _montoTotal,
      montoAbonado: _montoAbonado,
      saldo: sinPunitorios ? montoTotalSP - _montoAbonado : _saldo,
      estado: _estado,
      usuario: _usuarioCtrl.text.trim(),
      notas: _notasReciboCtrl.text.trim().isNotEmpty
          ? _notasReciboCtrl.text.trim()
          : null,
      createdAt: DateTime.now().toIso8601String(),
      propietarioNombre: _propietarioNombre,
      inquilinoNombre: _inquilinoNombre,
      direccion: _domicilioCtrl.text.trim(),
      localidad: _localidadCtrl.text.trim(),
      servicios: servicios,
      contratoId: _contratoSel?['id'] as int?,
      numeroCuota: _numeroCuota,
    );
  }

  // ── Confirmar e Imprimir ──────────────────────────────────────
  Future<void> _confirmarEImprimir() async {
    if (_contratoSel == null) {
      _mostrarError('Seleccioná un contrato antes de continuar.');
      return;
    }
    if (_servicios.isEmpty || _servicios.every((s) => s.descripcion.isEmpty)) {
      _mostrarError(
          'Agregá al menos un servicio con descripción antes de confirmar.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);
    ReciboModel? recibo;
    try {
      final now = DateTime.now().toIso8601String();
      final reciboId = await _db.insertarRecibo({
        'numero_recibo': _numeroRecibo,
        'propietario_id': _propietarioId ?? 0,
        'inquilino_id': _inquilinoId,
        'fecha_emision': DateFormat('yyyy-MM-dd').format(_fechaEmision),
        'fecha_vencimiento': DateFormat('yyyy-MM-dd').format(_fechaVencimiento),
        'monto_total': _montoTotal,
        'monto_abonado': _montoAbonado,
        'saldo': _saldo,
        'estado': _estado,
        'usuario': _usuarioCtrl.text.trim(),
        'notas': _notasReciboCtrl.text.trim(),
        'created_at': now,
        'contrato_id': _contratoSel?['id'],
        'numero_cuota': _numeroCuota,
      });
      for (final s in _servicios) {
        if (s.descripcion.isNotEmpty) {
          await _db.insertarServicio({
            'recibo_id': reciboId,
            'descripcion': s.descripcion,
            'monto': s.monto,
            'punitorios': s.punitorios,
            'total': s.total,
            'fecha_vence': s.fechaVence,
          });
        }
      }
      recibo = _buildReciboModel(reciboId: reciboId);
    } catch (e) {
      _mostrarError('Error al guardar: $e');
      if (mounted) setState(() => _guardando = false);
      return;
    }

    if (!mounted) return;
    setState(() => _guardando = false);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReciboPreviewScreen(recibo: recibo!, esNuevo: true),
      ),
    );
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context, true);
    }
  }

  // ── Solo Imprimir (sin guardar) ───────────────────────────────
  Future<void> _soloImprimir() async {
    if (_contratoSel == null) {
      _mostrarError('Seleccioná un contrato');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ReciboPreviewScreen(recibo: _buildReciboModel(), esNuevo: false),
      ),
    );
  }

  // ── Comprobante Sin Punitorios ────────────────────────────────
  Future<void> _comprobanteSinPunitorios() async {
    if (_contratoSel == null) {
      _mostrarError('Seleccioná un contrato');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReciboPreviewScreen(
          recibo: _buildReciboModel(sinPunitorios: true),
          esNuevo: false,
        ),
      ),
    );
  }

  // ── Recibo en Blanco (editable) ──────────────────────────────
  void _imprimirReciboNeutro() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReciboBlancoScreen(
          numeroRecibo: _numeroRecibo,
          usuario: _usuarioCtrl.text.trim(),
        ),
      ),
    );
  }

  // ── Pagar Próximo Período ─────────────────────────────────────
  Future<void> _pagarProximoPeriodo() async {
    if (_contratoSel == null) {
      _mostrarError('Seleccioná un contrato');
      return;
    }

    final contratoId = _contratoSel!['id'] as int;

    // Avanzar fechas un mes
    final nuevaEmision = DateTime(
      _fechaEmision.year,
      _fechaEmision.month + 1,
      _fechaEmision.day,
    );
    final nuevaVenc = DateTime(
      _fechaVencimiento.year,
      _fechaVencimiento.month + 1,
      _fechaVencimiento.day,
    );

    // Próxima cuota
    final nuevaCuota = _numeroCuota + 1;

    // Obtener monto del nuevo período
    final nuevoMonto = await _db.obtenerMontoPeriodo(contratoId, nuevaCuota);

    // Nuevo número de recibo
    final nuevoNumRecibo = await _db.obtenerProximoNumeroRecibo();

    // Nota automática con períodos
    final periodosData = await _db.obtenerPeriodosPorContrato(contratoId);
    final (:descripcion, :notaPeriodo) = _generarNotaPeriodo(
      numeroCuota: nuevaCuota,
      fechaEmision: nuevaEmision,
      periodosData: periodosData,
    );
    final desc = descripcion;

    setState(() {
      _fechaEmision = nuevaEmision;
      _fechaVencimiento = nuevaVenc;
      _numeroCuota = nuevaCuota;
      _numeroRecibo = nuevoNumRecibo;
      _montoAbonadoCtrl.text = '0';
      _notasReciboCtrl.text = notaPeriodo;

      // Actualizar primer servicio con el nuevo monto y descripción
      if (_servicios.isNotEmpty) {
        _servicios.first.descripcion = desc;
        _servicios.first.descripcionCtrl.text = desc;
        if (nuevoMonto > 0) {
          _servicios.first.monto = nuevoMonto;
          _servicios.first.montoCtrl.text = nuevoMonto.toStringAsFixed(0);
        }
      }
    });

    if (mounted) {
      mostrarNotificacion(context,
          texto: 'Avanzado a cuota $nuevaCuota — $desc',
          color: const Color(0xFF2E7D32));
    }
  }

  // ── Enviar Aviso ──────────────────────────────────────────────
  Future<void> _enviarAviso() async {
    if (_contratoSel == null) {
      _mostrarError('Seleccioná un contrato');
      return;
    }

    // Obtener teléfono del inquilino
    final celular = (_contratoSel!['inquilino_celular'] as String? ?? '').trim();
    final telefono =
        (_contratoSel!['inquilino_telefono'] as String? ?? '').trim();
    final rawTel = celular.isNotEmpty ? celular : telefono;

    // Texto del recordatorio (el que el usuario editó en la pestaña de notas)
    final recordatorio = _recordatorioInqCtrl.text.trim();
    final direccion = _domicilioCtrl.text.trim();

    if (rawTel.isEmpty) {
      _mostrarError(
          'El inquilino no tiene teléfono ni celular cargado. Actualizá los datos del inquilino para poder enviar el aviso por WhatsApp.');
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar Aviso por WhatsApp'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_inquilinoNombre != null)
              Text('Inquilino: $_inquilinoNombre'),
            Text('Teléfono: $rawTel'),
            const SizedBox(height: 10),
            const Text('Mensaje:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                recordatorio.isEmpty
                    ? '(recordatorio vacío)'
                    : recordatorio,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '¿Abrir WhatsApp con el aviso precargado?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.chat_outlined, size: 18),
            label: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    // Armar mensaje con encabezado de la inmobiliaria
    final mensaje = StringBuffer();
    mensaje.writeln('*COPPOLA PAVESE Inmobiliaria*');
    mensaje.writeln('Blandengues 188 - San Miguel del Monte');
    mensaje.writeln('Tel: 02226 546317 / 02271 412950');
    mensaje.writeln('');
    if (_inquilinoNombre != null && _inquilinoNombre!.isNotEmpty) {
      mensaje.writeln('Estimado/a $_inquilinoNombre,');
      mensaje.writeln('');
    }
    if (recordatorio.isNotEmpty) {
      mensaje.writeln(recordatorio);
    } else {
      mensaje.writeln('Le recordamos que tiene un aviso pendiente.');
    }
    if (direccion.isNotEmpty) {
      mensaje.writeln('');
      mensaje.writeln('Domicilio: $direccion');
    }

    try {
      final tel = normalizarTelefonoAR(rawTel);
      await abrirWhatsApp(telefono: tel, mensaje: mensaje.toString());
      if (mounted) {
        await mostrarConfirmacionWhatsApp(
          context: context,
          nombreCompleto: _inquilinoNombre ?? '',
          telefono: tel,
        );
      }
    } catch (e) {
      if (mounted) {
        mostrarNotificacion(context,
            texto: 'Error al abrir WhatsApp: $e',
            color: const Color(0xFFC62828));
      }
    }
  }

  void _mostrarError(String msg) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Color(0xFFC62828)),
            SizedBox(width: 8),
            Text('Atención',
                style: TextStyle(
                    color: Color(0xFFC62828), fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(msg, style: const TextStyle(fontSize: 14)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3A5C)),
            child: const Text('Aceptar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _seleccionarFecha({required bool esEmision}) async {
    final inicial = esEmision ? _fechaEmision : _fechaVencimiento;
    final sel = await showDatePicker(
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
    if (sel == null) return;
    setState(() {
      if (esEmision) {
        _fechaEmision = sel;
      } else {
        _fechaVencimiento = sel;
      }
    });
  }

  Future<void> _seleccionarFechaAlta() async {
    final sel = await showDatePicker(
      context: context,
      initialDate: _fechaAlta ?? DateTime.now(),
      firstDate: DateTime(2010),
      lastDate: DateTime(2035),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFFC2185B)),
        ),
        child: child!,
      ),
    );
    if (sel != null) setState(() => _fechaAlta = sel);
  }

  // ── BUILD ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text('Recibo N° ${_numeroRecibo.toString().padLeft(4, '0')}'),
      ),
      bottomNavigationBar: _barraAcciones(),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ════════════════════════════════════════════════
          // COLUMNA IZQUIERDA — Datos del recibo
          // ════════════════════════════════════════════════
          SizedBox(
            width: 480,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Contrato ───────────────────────────────────
                  _seccion(
                    titulo: 'Contrato',
                    icono: Icons.description_outlined,
                    children: [
                      _labelCampo('Contrato *'),
                      DropdownButtonFormField<int>(
                        value: _contratoSel?['id'] as int?,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.home_work_outlined, size: 18),
                          hintText: 'Seleccionar contrato',
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 12),
                        ),
                        items: _contratos.map((c) {
                          final id = c['id'] as int;
                          final dir = c['propiedad_direccion'] as String? ?? 'Sin dirección';
                          final inqN = c['inquilino_nombre'] as String? ?? '';
                          final inqA = c['inquilino_apellido'] as String? ?? '';
                          final inq = inqA.isNotEmpty ? '$inqN $inqA' : inqN;
                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text(
                              inq.isNotEmpty ? '$dir — $inq' : dir,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (id) {
                          if (id != null) {
                            final c = _contratos.firstWhere((c) => c['id'] == id);
                            _seleccionarContrato(c);
                          }
                        },
                        validator: (v) =>
                            v == null ? 'Seleccioná un contrato' : null,
                      ),
                      if (_contratoSel != null) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: [
                            Chip(
                              avatar: const Icon(Icons.receipt_long_outlined,
                                  size: 14, color: Color(0xFF1A3A5C)),
                              label: Text(
                                'Cuota N° $_numeroCuota'
                                '${_cuotasTotal > 0 ? ' de $_cuotasTotal' : ''}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A3A5C)),
                              ),
                              backgroundColor:
                                  const Color(0xFF1A3A5C).withAlpha(18),
                              side: const BorderSide(
                                  color: Color(0xFF1A3A5C), width: 0.8),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                            if (_propietarioNombre != null)
                              Chip(
                                label: Text(
                                  'LOCADOR: $_propietarioNombre',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF2E7D32)),
                                ),
                                backgroundColor:
                                    const Color(0xFF2E7D32).withAlpha(18),
                                side: const BorderSide(
                                    color: Color(0xFF2E7D32), width: 0.8),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            if (_inquilinoNombre != null)
                              Chip(
                                label: Text(
                                  'LOCATARIO: $_inquilinoNombre',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF1565C0)),
                                ),
                                backgroundColor:
                                    const Color(0xFF1565C0).withAlpha(18),
                                side: const BorderSide(
                                    color: Color(0xFF1565C0), width: 0.8),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Domicilio ──────────────────────────────────
                  _seccion(
                    titulo: 'Domicilio del Alquiler',
                    icono: Icons.home_outlined,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _domicilioCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Dirección',
                                prefixIcon: Icon(Icons.location_on_outlined,
                                    size: 18),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _localidadCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Localidad',
                                prefixIcon: Icon(Icons.location_city_outlined,
                                    size: 18),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Fechas ─────────────────────────────────────
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
                              onTap: () => _seleccionarFecha(esEmision: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _selectorFecha(
                              label: 'Vencimiento',
                              fecha: fmt.format(_fechaVencimiento),
                              onTap: () => _seleccionarFecha(esEmision: false),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Datos de Pago ──────────────────────────────
                  _seccion(
                    titulo: 'Datos de Pago',
                    icono: Icons.payments_outlined,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _usuarioCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Responsable',
                                prefixIcon:
                                    Icon(Icons.badge_outlined, size: 18),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 160,
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
                                labelText: 'Monto Abonado',
                                prefixText: '\$ ',
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Configuración del Período ───────────────────
                  _seccion(
                    titulo: 'Configuración del Período',
                    icono: Icons.settings_outlined,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _campoNumerico(
                                controller: _diasGraciaCtrl,
                                label: 'Días de gracia',
                                icono: Icons.timer_outlined),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _campoNumerico(
                                controller: _punitoriosDesdeCtrl,
                                label: 'Punitorios desde día',
                                icono: Icons.warning_amber_outlined),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _seleccionarFechaAlta,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                              border:
                                  Border.all(color: const Color(0xFFBDBDBD)),
                              borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              const Icon(Icons.event_outlined,
                                  size: 16, color: Color(0xFFC2185B)),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Fecha de alta',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF9E9E9E))),
                                  Text(
                                    _fechaAlta != null
                                        ? DateFormat('dd/MM/yyyy')
                                            .format(_fechaAlta!)
                                        : 'Seleccionar',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // ── Divisor vertical ──────────────────────────────────
          Container(width: 1, color: const Color(0xFFE0E0E0)),

          // ════════════════════════════════════════════════
          // COLUMNA DERECHA — Tabs
          // ════════════════════════════════════════════════
          Expanded(
            child: Column(
              children: [
                Container(
                  color: const Color(0xFF1A3A5C),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFFC2185B),
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    labelStyle: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold),
                    tabs: const [
                      Tab(
                          icon: Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 16),
                          text: 'Estado de Cuenta'),
                      Tab(
                          icon: Icon(Icons.add_box_outlined, size: 16),
                          text: 'Conceptos Extras'),
                      Tab(
                          icon: Icon(Icons.sticky_note_2_outlined, size: 16),
                          text: 'Notas y Recordatorios'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _tabEstadoCuenta(),
                      _tabConceptosExtras(),
                      _tabNotasRecordatorios(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Barra de 5 acciones inferior ─────────────────────────────
  Widget _barraAcciones() {
    return Container(
      height: 72,
      color: const Color(0xFF1A3A5C),
      child: Row(
        children: [
          _botonAccion(
            icono: Icons.article_outlined,
            label: 'Recibo\nen Blanco',
            onTap: _guardando ? null : _imprimirReciboNeutro,
          ),
          _separadorV(),
          _botonAccion(
            icono: Icons.send_outlined,
            label: 'Enviar\naviso',
            onTap: _guardando ? null : _enviarAviso,
          ),
          _separadorV(),
          _botonAccion(
            icono: Icons.navigate_next,
            label: 'Próximo\nPeríodo',
            onTap: _guardando ? null : _pagarProximoPeriodo,
          ),
          _separadorV(),
          _botonAccion(
            icono: Icons.print_outlined,
            label: 'Solo\nImprimir',
            onTap: _guardando ? null : _soloImprimir,
          ),
          _separadorV(),
          _botonAccion(
            icono: Icons.receipt_long_outlined,
            label: 'Comprobante\nS/P',
            onTap: _guardando ? null : _comprobanteSinPunitorios,
          ),
          _separadorV(),
          _botonAccion(
            icono: _guardando
                ? Icons.hourglass_bottom
                : Icons.check_circle_outline,
            label: _guardando ? 'Guardando...' : 'Confirmar e\nImprimir',
            onTap: _guardando ? null : _confirmarEImprimir,
            esDestacado: true,
          ),
        ],
      ),
    );
  }

  Widget _botonAccion({
    required IconData icono,
    required String label,
    required VoidCallback? onTap,
    bool esDestacado = false,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: esDestacado
              ? const Color(0xFFC2185B).withAlpha(80)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, color: Colors.white, size: 20),
              const SizedBox(height: 3),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 10, height: 1.2)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _separadorV() =>
      Container(width: 1, height: 40, color: Colors.white24);

  // ── Tab 1: Estado de Cuenta ───────────────────────────────────
  Widget _tabEstadoCuenta() {
    final fmt = DateFormat('dd/MM/yyyy');
    final fmtM = NumberFormat.currency(
        locale: 'es_AR', symbol: '\$', decimalDigits: 0, customPattern: '\u00A4#,##0');

    final serviciosConDesc =
        _servicios.where((s) => s.descripcion.isNotEmpty).toList();
    final sinDatos = _contratoSel == null && serviciosConDesc.isEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: sinDatos
          ? Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 48,
                        color: const Color(0xFFC2185B).withOpacity(0.4)),
                    const SizedBox(height: 12),
                    const Text(
                      'Seleccioná un contrato\npara ver el resumen aquí.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Encabezado del recibo ──────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A3A5C),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'RECIBO N° ${_numeroRecibo.toString().padLeft(4, '0')}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                            if (_propietarioNombre != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'LOCADOR: $_propietarioNombre',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                            if (_inquilinoNombre != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'LOCATARIO: $_inquilinoNombre',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                            if (_domicilioCtrl.text.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Domicilio: ${_domicilioCtrl.text.trim()}'
                                '${_localidadCtrl.text.isNotEmpty ? ', ${_localidadCtrl.text.trim()}' : ''}',
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 11),
                              ),
                            ],
                            if (_contratoSel != null) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(30),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Cuota N° $_numeroCuota'
                                  '${_cuotasTotal > 0 ? ' de $_cuotasTotal' : ''}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            fmt.format(_fechaEmision),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Vence: ${fmt.format(_fechaVencimiento)}',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 11),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _colorEstado.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _labelEstado.toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Conceptos ─────────────────────────────────
                if (serviciosConDesc.isNotEmpty) ...[
                  const Text('CONCEPTOS',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFC2185B),
                          letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                        borderRadius: BorderRadius.circular(6)),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1A3A5C),
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(6)),
                          ),
                          child: const Row(children: [
                            Expanded(
                                flex: 4,
                                child: Text('Descripción',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold))),
                            Expanded(
                                flex: 2,
                                child: Text('Monto',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.right)),
                            Expanded(
                                flex: 2,
                                child: Text('Punitorios',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.right)),
                            Expanded(
                                flex: 2,
                                child: Text('Total',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.right)),
                          ]),
                        ),
                        ...serviciosConDesc.asMap().entries.map((e) {
                          final s = e.value;
                          final isEven = e.key.isEven;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isEven
                                  ? Colors.white
                                  : const Color(0xFFF5F5F5),
                              border: const Border(
                                  top: BorderSide(
                                      color: Color(0xFFEEEEEE))),
                            ),
                            child: Row(children: [
                              Expanded(
                                  flex: 4,
                                  child: Text(s.descripcion,
                                      style:
                                          const TextStyle(fontSize: 12))),
                              Expanded(
                                  flex: 2,
                                  child: Text(fmtM.format(s.monto),
                                      style:
                                          const TextStyle(fontSize: 12),
                                      textAlign: TextAlign.right)),
                              Expanded(
                                  flex: 2,
                                  child: Text(
                                      s.punitorios > 0
                                          ? fmtM.format(s.punitorios)
                                          : '—',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: s.punitorios > 0
                                              ? const Color(0xFFC62828)
                                              : const Color(0xFF9E9E9E)),
                                      textAlign: TextAlign.right)),
                              Expanded(
                                  flex: 2,
                                  child: Text(fmtM.format(s.total),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.right)),
                            ]),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Resumen de Pago ────────────────────────────
                Container(
                  decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                      borderRadius: BorderRadius.circular(6)),
                  child: Column(
                    children: [
                      _filaResumenTab('Monto Total a Cobrar:',
                          fmtM.format(_montoTotal),
                          const Color(0xFF1565C0)),
                      const Divider(height: 1),
                      _filaResumenTab('Total Abonado:',
                          fmtM.format(_montoAbonado),
                          const Color(0xFF2E7D32)),
                      const Divider(height: 1),
                      _filaResumenTab(
                        'Saldo:',
                        fmtM.format(_saldo),
                        _saldo > 0
                            ? const Color(0xFFC62828)
                            : const Color(0xFF2E7D32),
                        negrita: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _filaResumenTab(String label, String valor, Color color,
          {bool negrita = false}) =>
      Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: negrita
                        ? FontWeight.bold
                        : FontWeight.w500)),
            Text(valor,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      );

  // ── Tab 2: Conceptos Extras ───────────────────────────────────
  Widget _tabConceptosExtras() {
    final fmtM = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0, customPattern: '\u00A4#,##0');
    final fmtVence = DateFormat('dd/MM/yy');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ════════════════════════════════════════════════
          // SECCIÓN 2: CONCEPTO ÚNICO (agregar al recibo)
          // ════════════════════════════════════════════════
          Container(
            color: const Color(0xFF37474F),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: const Row(children: [
              Icon(Icons.add_circle_outline, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Concepto único',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ]),
          ),
          // Items ya agregados al recibo
          if (_servicios.isNotEmpty) ...[
            Container(
              color: const Color(0xFFF5F5F5),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: const Row(children: [
                SizedBox(
                    width: 70,
                    child: Text('Vence',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF757575)))),
                Expanded(
                    child: Text('Descripción',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF757575)))),
                SizedBox(
                    width: 90,
                    child: Text('Monto',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF757575)))),
                SizedBox(width: 32),
              ]),
            ),
            ..._servicios.asMap().entries.map((e) {
              final idx = e.key;
              final s   = e.value;
              String vStr = '—';
              if (s.fechaVence != null) {
                try {
                  vStr = fmtVence.format(DateTime.parse(s.fechaVence!));
                } catch (_) {}
              }
              return Container(
                color: idx.isEven ? Colors.white : const Color(0xFFF9F9F9),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Row(children: [
                  SizedBox(
                    width: 70,
                    child: Text(vStr,
                        style: TextStyle(
                            fontSize: 11,
                            color: s.fechaVence != null
                                ? const Color(0xFFC62828)
                                : const Color(0xFF9E9E9E))),
                  ),
                  Expanded(
                    child: Text(
                      s.descripcion.isNotEmpty ? s.descripcion : '—',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: s.montoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
                      ],
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        prefixText: '\$ ',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        s.monto = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                        setState(() {});
                      },
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    child: IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Color(0xFFC62828), size: 16),
                      onPressed: () => setState(() {
                        s.dispose();
                        _servicios.removeAt(idx);
                      }),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ]),
              );
            }),
          ],

          // ── Formulario de entrada ──────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila: Vence | Descripción | Monto | Claro
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Vence
                    SizedBox(
                      width: 100,
                      child: GestureDetector(
                        onTap: _pickUniVence,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 9),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: _uniVence != null
                                    ? const Color(0xFFC2185B)
                                    : const Color(0xFFBDBDBD)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Vence',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: Color(0xFF9E9E9E))),
                              Row(children: [
                                Icon(Icons.event_outlined,
                                    size: 12,
                                    color: _uniVence != null
                                        ? const Color(0xFFC2185B)
                                        : const Color(0xFF9E9E9E)),
                                const SizedBox(width: 3),
                                Text(
                                  _uniVence != null
                                      ? DateFormat('dd/MM/yy')
                                          .format(_uniVence!)
                                      : '—',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: _uniVence != null
                                          ? const Color(0xFFC2185B)
                                          : const Color(0xFF9E9E9E)),
                                ),
                              ]),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Descripción
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Descripción',
                              style: TextStyle(
                                  fontSize: 10, color: Color(0xFF616161))),
                          const SizedBox(height: 3),
                          TextField(
                            controller: _uniDescCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Concepto o descripción...',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Monto
                    SizedBox(
                      width: 110,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Monto',
                              style: TextStyle(
                                  fontSize: 10, color: Color(0xFF616161))),
                          const SizedBox(height: 3),
                          TextField(
                            controller: _uniMontoCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d,.]')),
                            ],
                            textAlign: TextAlign.right,
                            decoration: const InputDecoration(
                              prefixText: '\$ ',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 10),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Claro (limpiar)
                    OutlinedButton(
                      onPressed: _limpiarUniForm,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        side: const BorderSide(color: Color(0xFFBDBDBD)),
                      ),
                      child: const Text('Claro',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF757575))),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Inquilino / Propietario
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Inquilino
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Inquilino',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1565C0))),
                          const SizedBox(height: 4),
                          _radioUniInq(EfectoConcepto.sinEfecto, 'Sin efecto'),
                          _radioUniInq(EfectoConcepto.sumar, 'Sumar al pago'),
                          _radioUniInq(EfectoConcepto.descontar, 'Descontar al pago'),
                          const SizedBox(height: 4),
                          Row(children: [
                            Checkbox(
                              value: _uniAplicaPunit,
                              onChanged: (v) =>
                                  setState(() => _uniAplicaPunit = v ?? false),
                              activeColor: const Color(0xFF1A3A5C),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            const Text('Aplica Punitorios',
                                style: TextStyle(fontSize: 11)),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Propietario
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Propietario',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E7D32))),
                          const SizedBox(height: 4),
                          _radioUniProp(EfectoConcepto.sinEfecto, 'Sin efecto'),
                          _radioUniProp(EfectoConcepto.sumar, 'Sumar a lo que Cobra'),
                          _radioUniProp(EfectoConcepto.descontar, 'Descontar de lo que Cobra'),
                          const SizedBox(height: 4),
                          Row(children: [
                            Checkbox(
                              value: _uniAplicaAdmin,
                              onChanged: (v) =>
                                  setState(() => _uniAplicaAdmin = v ?? false),
                              activeColor: const Color(0xFF1A3A5C),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            const Text('Aplica Administración',
                                style: TextStyle(fontSize: 11)),
                            const SizedBox(width: 10),
                            Checkbox(
                              value: _uniAplicaTodos,
                              onChanged: (v) =>
                                  setState(() => _uniAplicaTodos = v ?? true),
                              activeColor: const Color(0xFF1A3A5C),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            const Text('Todos',
                                style: TextStyle(fontSize: 11)),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Botón Continuar y Agregar
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _agregarConceptoUnico,
                    icon: const Icon(Icons.add, size: 16, color: Colors.white),
                    label: const Text('Continuar y Agregar',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A3A5C),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── Agregar concepto único al recibo ──────────────────────────
  void _agregarConceptoUnico() {
    final desc = _uniDescCtrl.text.trim();
    if (desc.isEmpty) return;
    final monto =
        double.tryParse(_uniMontoCtrl.text.replaceAll(',', '.')) ?? 0;
    final fila = _FilaServicio();
    fila.descripcion = desc;
    fila.descripcionCtrl.text = desc;
    fila.monto = monto;
    fila.montoCtrl.text = _uniMontoCtrl.text;
    fila.fechaVence = _uniVence != null
        ? DateFormat('yyyy-MM-dd').format(_uniVence!)
        : null;
    fila.efectoInq = _uniEfectoInq;
    fila.efectoProp = _uniEfectoProp;
    setState(() {
      _servicios.add(fila);
      _limpiarUniForm();
    });
  }

  void _limpiarUniForm() {
    setState(() {
      _uniVence = null;
      _uniDescCtrl.clear();
      _uniMontoCtrl.text = '0';
      _uniEfectoInq = EfectoConcepto.sinEfecto;
      _uniAplicaPunit = false;
      _uniEfectoProp = EfectoConcepto.sinEfecto;
      _uniAplicaAdmin = false;
      _uniAplicaTodos = true;
    });
  }

  Future<void> _pickUniVence() async {
    final sel = await showDatePicker(
      context: context,
      initialDate: _uniVence ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFFC2185B)),
        ),
        child: child!,
      ),
    );
    if (sel != null) setState(() => _uniVence = sel);
  }

  Widget _radioUniInq(EfectoConcepto val, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<EfectoConcepto>(
            value: val,
            groupValue: _uniEfectoInq,
            onChanged: (v) => setState(() => _uniEfectoInq = v!),
            activeColor: const Color(0xFF1A3A5C),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      );

  Widget _radioUniProp(EfectoConcepto val, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<EfectoConcepto>(
            value: val,
            groupValue: _uniEfectoProp,
            onChanged: (v) => setState(() => _uniEfectoProp = v!),
            activeColor: const Color(0xFF1A3A5C),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      );

  // ── Tab 3: Notas y Recordatorios ─────────────────────────────
  Widget _tabNotasRecordatorios() {
    final restantes = 140 - _notasReciboCtrl.text.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subtitulo('Notas al pie para el recibo'),
          TextFormField(
            controller: _notasReciboCtrl,
            maxLines: 3,
            maxLength: 140,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Se imprimirá al pie del recibo...',
              alignLabelWithHint: true,
              counterText: '',
              suffixText: '$restantes restantes',
              suffixStyle: TextStyle(
                fontSize: 11,
                color: restantes < 20
                    ? const Color(0xFFC62828)
                    : const Color(0xFF9E9E9E),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _subtitulo('Recordatorio para el Inquilino'),
          TextFormField(
            controller: _recordatorioInqCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
                hintText: 'Texto del recordatorio...',
                alignLabelWithHint: true),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Alertar',
                    style: TextStyle(fontSize: 12)),
                value: _alertarInq,
                onChanged: (v) =>
                    setState(() => _alertarInq = v ?? true),
                activeColor: const Color(0xFFC2185B),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
            Expanded(
              child: CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Imprimir',
                    style: TextStyle(fontSize: 12)),
                value: _imprimirRecInq,
                onChanged: (v) =>
                    setState(() => _imprimirRecInq = v ?? true),
                activeColor: const Color(0xFFC2185B),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
          ]),
          const SizedBox(height: 20),
          _subtitulo('Recordatorio para el Propietario'),
          TextFormField(
            controller: _recordatorioPropCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
                hintText: 'Texto del recordatorio...',
                alignLabelWithHint: true),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Alertar',
                    style: TextStyle(fontSize: 12)),
                value: _alertarProp,
                onChanged: (v) =>
                    setState(() => _alertarProp = v ?? true),
                activeColor: const Color(0xFFC2185B),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
            Expanded(
              child: CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Imprimir',
                    style: TextStyle(fontSize: 12)),
                value: _imprimirRecProp,
                onChanged: (v) =>
                    setState(() => _imprimirRecProp = v ?? true),
                activeColor: const Color(0xFFC2185B),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Widgets auxiliares ────────────────────────────────────────
  Widget _subtitulo(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(texto,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A3A5C))),
      );

  Widget _campoNumerico({
    required TextEditingController controller,
    required String label,
    required IconData icono,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
            labelText: label, prefixIcon: Icon(icono, size: 18), isDense: true),
        onChanged: (_) => setState(() {}),
      );

  Widget _seccion({
    required String titulo,
    required IconData icono,
    required List<Widget> children,
  }) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icono, size: 17, color: const Color(0xFFC2185B)),
                const SizedBox(width: 8),
                Text(titulo,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC2185B))),
              ]),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      );

  Widget _labelCampo(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(texto,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF616161))),
      );

  Widget _selectorFecha({
    required String label,
    required String fecha,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFBDBDBD)),
              borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            const Icon(Icons.calendar_today,
                size: 16, color: Color(0xFFC2185B)),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF9E9E9E))),
              Text(fecha,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
      );

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

// ── Modelo interno de fila de servicio ────────────────────────────────
class _FilaServicio {
  String descripcion = '';
  double monto = 0;
  double punitorios = 0;
  String? fechaVence;
  double get total => monto + punitorios;

  EfectoConcepto efectoInq = EfectoConcepto.sinEfecto;
  EfectoConcepto efectoProp = EfectoConcepto.sinEfecto;

  final descripcionCtrl = TextEditingController();
  final montoCtrl = TextEditingController();
  final punitioriosCtrl = TextEditingController();

  void dispose() {
    descripcionCtrl.dispose();
    montoCtrl.dispose();
    punitioriosCtrl.dispose();
  }
}
