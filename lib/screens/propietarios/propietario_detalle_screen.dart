import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/recibo_model.dart';
import '../../models/servicio_item_model.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/whatsapp_launcher.dart';
import '../recibos/recibo_form_screen.dart';
import '../recibos/recibo_preview_screen.dart';

class PropietarioDetalleScreen extends StatefulWidget {
  final int propietarioId;
  final String nombrePropietario;

  const PropietarioDetalleScreen({
    super.key,
    required this.propietarioId,
    required this.nombrePropietario,
  });

  @override
  State<PropietarioDetalleScreen> createState() =>
      _PropietarioDetalleScreenState();
}

class _PropietarioDetalleScreenState extends State<PropietarioDetalleScreen> {
  final _db = DatabaseHelper();
  Map<String, dynamic>? _propietario;
  List<Map<String, dynamic>> _contratos = [];
  List<Map<String, dynamic>> _recibos = [];
  bool _cargando = true;
  int? _contratoSeleccionadoId;

  List<Map<String, dynamic>> _periodosContrato = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final propietario =
          await _db.obtenerPropietarioPorId(widget.propietarioId);
      final contratos =
          await _db.obtenerContratosPorPropietario(widget.propietarioId);

      // Si hay contratos y no hay selección, seleccionar el primero
      int? contratoSel = _contratoSeleccionadoId;
      if (contratos.isNotEmpty) {
        final ids = contratos.map((c) => c['id'] as int).toSet();
        if (contratoSel == null || !ids.contains(contratoSel)) {
          contratoSel = contratos.first['id'] as int;
        }
      } else {
        contratoSel = null;
      }

      // Cargar periodos del contrato seleccionado
      List<Map<String, dynamic>> periodos = [];
      if (contratoSel != null) {
        periodos = await _db.obtenerPeriodosPorContrato(contratoSel);
      }

      // Cargar recibos del contrato seleccionado (o todos si no hay contrato)
      List<Map<String, dynamic>> recibos;
      if (contratoSel != null) {
        recibos = await _db.obtenerRecibosPorContrato(contratoSel);
      } else {
        recibos = await _db.obtenerRecibosConExtras(widget.propietarioId);
      }

      setState(() {
        _propietario = propietario;
        _contratos = contratos;
        _contratoSeleccionadoId = contratoSel;
        _periodosContrato = periodos;
        _recibos = recibos;
        _cargando = false;
      });
    } catch (e) {
      setState(() => _cargando = false);
      if (mounted) {
        mostrarNotificacion(context,
            texto: 'Error al cargar datos: $e',
            color: const Color(0xFFC62828));
      }
    }
  }

  Future<void> _seleccionarContrato(int contratoId) async {
    setState(() => _contratoSeleccionadoId = contratoId);
    final recibos = await _db.obtenerRecibosPorContrato(contratoId);
    final periodos = await _db.obtenerPeriodosPorContrato(contratoId);
    setState(() {
      _recibos = recibos;
      _periodosContrato = periodos;
    });
  }

  Map<String, dynamic>? get _contratoActual {
    if (_contratoSeleccionadoId == null) return null;
    try {
      return _contratos
          .firstWhere((c) => c['id'] == _contratoSeleccionadoId);
    } catch (_) {
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════════
  // BUILD PRINCIPAL
  // ════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.person, size: 20),
            const SizedBox(width: 8),
            Text(widget.nombrePropietario),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _cargarDatos,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 340,
                  child: _columnaIzquierda(),
                ),
                Container(width: 1, color: const Color(0xFFE0E0E0)),
                Expanded(child: _columnaDerecha()),
              ],
            ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // COLUMNA IZQUIERDA
  // ════════════════════════════════════════════════════════════════

  Widget _columnaIzquierda() {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _tarjetaPropietario(),
            const SizedBox(height: 16),
            // ── Selector de contratos por propiedad ──
            if (_contratos.isNotEmpty) ...[
              _selectorContratos(),
              const SizedBox(height: 16),
              _infoContratoSeleccionado(),
            ],
          ],
        ),
      ),
    );
  }

  // ── Tarjeta de propietario ─────────────────────────────────────
  Widget _tarjetaPropietario() {
    final telefono = _propietario?['telefono'] as String? ?? '';
    final email = _propietario?['email'] as String? ?? '';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFC2185B), Color(0xFF880E4F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Text(
                  widget.nombrePropietario.isNotEmpty
                      ? widget.nombrePropietario[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.nombrePropietario,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${_contratos.length} contrato${_contratos.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (telefono.isNotEmpty || email.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 12),
            if (telefono.isNotEmpty) _filaInfoTarjeta(Icons.phone, telefono),
            if (email.isNotEmpty)
              _filaInfoTarjeta(Icons.email_outlined, email),
          ],
        ],
      ),
    );
  }

  Widget _filaInfoTarjeta(IconData icono, String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icono, size: 13, color: Colors.white70),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Selector de contratos (chips por propiedad) ────────────────
  Widget _selectorContratos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.home_outlined, size: 16, color: Color(0xFFC2185B)),
            SizedBox(width: 6),
            Text(
              'Propiedades / Contratos',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF424242),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...List.generate(_contratos.length, (i) {
          final c = _contratos[i];
          final id = c['id'] as int;
          final dir = c['propiedad_direccion'] as String? ?? 'Sin propiedad';
          final loc = c['propiedad_localidad'] as String? ?? '';
          final inqNombre = c['inquilino_nombre'] as String? ?? '';
          final inqApellido = c['inquilino_apellido'] as String? ?? '';
          final inquilino = inqApellido.isNotEmpty
              ? '$inqNombre $inqApellido'
              : inqNombre.isNotEmpty
                  ? inqNombre
                  : 'Sin inquilino';
          final label = loc.isNotEmpty ? '$dir, $loc' : dir;
          final selected = _contratoSeleccionadoId == id;
          final rescindido = (c['rescindido'] as int? ?? 0) == 1;

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              onTap: () => _seleccionarContrato(id),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFC2185B).withOpacity(0.1)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFC2185B)
                        : const Color(0xFFE0E0E0),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.home,
                      size: 16,
                      color: selected
                          ? const Color(0xFFC2185B)
                          : const Color(0xFF9E9E9E),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: selected
                                  ? const Color(0xFFC2185B)
                                  : const Color(0xFF424242),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Inq: $inquilino',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF757575),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (rescindido)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC62828).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'RESCINDIDO',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFC62828),
                          ),
                        ),
                      ),
                    if (selected)
                      const Icon(Icons.check_circle,
                          size: 16, color: Color(0xFFC2185B)),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Info del contrato seleccionado ─────────────────────────────
  Widget _infoContratoSeleccionado() {
    final c = _contratoActual;
    if (c == null) return const SizedBox.shrink();

    final fechaInicio = c['fecha_inicio'] as String? ?? '';
    final fechaFin = c['fecha_fin'] as String? ?? '';
    final cuotas = c['cuotas_total'] as int? ?? 0;
    final fmt = NumberFormat.currency(
        locale: 'es_AR', symbol: '\$', decimalDigits: 0, customPattern: '\u00A4#,##0');

    // Mostrar último periodo asignado (o primer periodo si no hay periodos)
    double alquiler;
    String alquilerLabel;
    if (_periodosContrato.isNotEmpty) {
      final ultimo = _periodosContrato.last;
      alquiler = (ultimo['monto'] as num?)?.toDouble() ?? 0.0;
      final desde = ultimo['cuota_desde'] as int? ?? 0;
      final hasta = ultimo['cuota_hasta'] as int? ?? 0;
      alquilerLabel = 'Alquiler (cuota #$desde-#$hasta)';
    } else {
      alquiler = (c['alquiler_primer_periodo'] as num?)?.toDouble() ?? 0.0;
      alquilerLabel = 'Alquiler 1° per.';
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.description_outlined,
                  size: 14, color: Color(0xFF1565C0)),
              SizedBox(width: 6),
              Text(
                'Datos del Contrato',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1565C0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (fechaInicio.isNotEmpty)
            _filaInfoContrato('Inicio', _formatearFecha(fechaInicio)),
          if (fechaFin.isNotEmpty)
            _filaInfoContrato('Fin', _formatearFecha(fechaFin)),
          if (cuotas > 0) _filaInfoContrato('Cuotas', '$cuotas'),
          if (alquiler > 0)
            _filaInfoContrato(alquilerLabel, fmt.format(alquiler)),
          _filaInfoContrato('Recibos', '${_recibos.length}'),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _nuevoRecibo,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Nuevo Recibo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC2185B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaInfoContrato(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF757575)),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF424242),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Botones de acción ──────────────────────────────────────────
  Widget _botonNuevoRecibo() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _nuevoRecibo,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Nuevo Recibo'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC2185B),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _botonVerTodos() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _cargarDatos,
        icon: const Icon(Icons.refresh, size: 16),
        label: const Text('Actualizar'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          textStyle: const TextStyle(fontSize: 13),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // COLUMNA DERECHA — Historial de recibos
  // ════════════════════════════════════════════════════════════════

  Widget _columnaDerecha() {
    final c = _contratoActual;
    final dir = c != null
        ? (c['propiedad_direccion'] as String? ?? '')
        : '';
    final tituloExtra = dir.isNotEmpty ? ' — $dir' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          color: Colors.white,
          child: Row(
            children: [
              const Icon(Icons.receipt_long,
                  size: 20, color: Color(0xFFC2185B)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Historial de Recibos$tituloExtra',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF212121),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFC2185B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_recibos.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC2185B),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _recibos.isEmpty
              ? _sinRecibos()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _recibos.length,
                  itemBuilder: (context, i) => _tarjetaRecibo(_recibos[i]),
                ),
        ),
      ],
    );
  }

  // ── Tarjeta individual de recibo ─────────────────────────────
  Widget _tarjetaRecibo(Map<String, dynamic> r) {
    final numeroRecibo = r['numero_recibo'] as int? ?? 0;
    final fechaEmision = _formatearFecha(r['fecha_emision'] as String? ?? '');
    final fechaVencimiento =
        _formatearFecha(r['fecha_vencimiento'] as String? ?? '');
    final montoTotal = (r['monto_total'] as num?)?.toDouble() ?? 0.0;
    final montoAbonado = (r['monto_abonado'] as num?)?.toDouble() ?? 0.0;
    final saldo = (r['saldo'] as num?)?.toDouble() ?? 0.0;
    final estado = r['estado'] as String? ?? 'pendiente';
    final reciboId = r['id'] as int;

    final notasRecibo = r['notas_recibo'] as String?;
    final tieneNotas = notasRecibo != null && notasRecibo.trim().isNotEmpty;
    final alertarInquilino = (r['alertar_inquilino'] as int? ?? 0) == 1;
    final alertarPropietario = (r['alertar_propietario'] as int? ?? 0) == 1;
    final tieneAlertas = alertarInquilino || alertarPropietario;

    final colorEstado = _colorEstado(estado);
    final labelEstado = _labelEstado(estado);

    final fmt = NumberFormat.currency(
        locale: 'es_AR', symbol: '\$', decimalDigits: 0, customPattern: '\u00A4#,##0');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _verRecibo(reciboId),
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            // ── Número de recibo ──
            Column(
              children: [
                Container(
                  width: 68,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC2185B).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'N°',
                        style: TextStyle(
                            fontSize: 10, color: Color(0xFFC2185B)),
                      ),
                      Text(
                        numeroRecibo.toString().padLeft(4, '0'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFFC2185B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: estado == 'pagado'
                        ? const Color(0xFFC2185B)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: estado == 'pagado'
                          ? const Color(0xFFC2185B)
                          : const Color(0xFFBDBDBD),
                    ),
                  ),
                  child: Text(
                    estado == 'pagado' ? 'PAGÓ' : 'NO PAGÓ',
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                      color: estado == 'pagado'
                          ? Colors.white
                          : const Color(0xFF424242),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),

            // ── Fechas ──
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fechaFila(Icons.send, 'Emisión', fechaEmision),
                  const SizedBox(height: 4),
                  _fechaFila(Icons.event, 'Vence', fechaVencimiento),
                  if (tieneNotas || tieneAlertas) ...[
                    const SizedBox(height: 8),
                    _badgesExtras(
                      tieneNotas: tieneNotas,
                      tieneAlertas: tieneAlertas,
                      alertarInquilino: alertarInquilino,
                      alertarPropietario: alertarPropietario,
                      notasRecibo: notasRecibo,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),

            // ── Montos ──
            _celdaMonto('Total', fmt.format(montoTotal),
                const Color(0xFF1565C0)),
            const SizedBox(width: 12),
            _celdaMonto('Abonado', fmt.format(montoAbonado),
                const Color(0xFF2E7D32)),
            const SizedBox(width: 12),
            _celdaMonto(
              'Saldo',
              fmt.format(saldo),
              saldo > 0
                  ? const Color(0xFFC62828)
                  : const Color(0xFF2E7D32),
            ),
            const SizedBox(width: 20),

            // ── Botones ──
            ElevatedButton.icon(
              onPressed: () => _verRecibo(reciboId),
              icon: const Icon(Icons.visibility_outlined, size: 15),
              label: const Text('Ver'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 10),
            // Estado: texto clickeable
            GestureDetector(
              onTap: () => _cambiarEstadoRecibo(r),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: estado == 'pagado'
                      ? const Color(0xFFC2185B)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: estado == 'pagado'
                        ? const Color(0xFFC2185B)
                        : const Color(0xFFBDBDBD),
                  ),
                ),
                child: Text(
                  estado == 'pagado' ? 'PAGÓ' : 'NO PAGÓ',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: estado == 'pagado'
                        ? Colors.white
                        : const Color(0xFF424242),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: () => _enviarMensajeWA(r),
              icon: const Icon(Icons.message_outlined, size: 18),
              color: const Color(0xFF25D366),
              tooltip: 'Enviar mensaje por WhatsApp',
              style: IconButton.styleFrom(
                backgroundColor:
                    const Color(0xFF25D366).withOpacity(0.08),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 2),
            IconButton(
              onPressed: () =>
                  _confirmarEliminarRecibo(reciboId, numeroRecibo),
              icon: const Icon(Icons.delete_outline, size: 18),
              color: const Color(0xFFC62828),
              tooltip: 'Eliminar recibo',
              style: IconButton.styleFrom(
                backgroundColor:
                    const Color(0xFFC62828).withOpacity(0.08),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _fechaFila(IconData icono, String label, String valor) {
    return Row(
      children: [
        Icon(icono, size: 12, color: const Color(0xFF9E9E9E)),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: const TextStyle(
              fontSize: 11, color: Color(0xFF9E9E9E)),
        ),
        Text(
          valor,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF424242)),
        ),
      ],
    );
  }

  Widget _celdaMonto(String label, String valor, Color color) {
    return SizedBox(
      width: 88,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            valor,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
                fontSize: 10, color: Color(0xFF9E9E9E)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _badgesExtras({
    required bool tieneNotas,
    required bool tieneAlertas,
    required bool alertarInquilino,
    required bool alertarPropietario,
    required String? notasRecibo,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (tieneNotas)
          Tooltip(
            message: notasRecibo ?? '',
            child: _chip(
              icono: Icons.sticky_note_2_outlined,
              label: 'Nota',
              color: const Color(0xFFF57F17),
              fondo: const Color(0xFFFFF9C4),
            ),
          ),
        if (tieneAlertas)
          Tooltip(
            message: [
              if (alertarInquilino) 'Alerta inquilino',
              if (alertarPropietario) 'Alerta propietario',
            ].join(' · '),
            child: _chip(
              icono: Icons.notifications_active_outlined,
              label: _labelAlertas(alertarInquilino, alertarPropietario),
              color: const Color(0xFF1565C0),
              fondo: const Color(0xFFE3F2FD),
            ),
          ),
      ],
    );
  }

  Widget _chip({
    required IconData icono,
    required String label,
    required Color color,
    required Color fondo,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  String _labelAlertas(bool inquilino, bool propietario) {
    if (inquilino && propietario) return 'Inq + Prop';
    if (inquilino) return 'Inquilino';
    return 'Propietario';
  }

  Widget _sinRecibos() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 64, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text(
            'Sin recibos para este contrato',
            style: TextStyle(
                fontSize: 16, color: Color(0xFF9E9E9E)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Usá "Nuevo Recibo" para crear el primero',
            style: TextStyle(
                fontSize: 13, color: Color(0xFFBDBDBD)),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // NAVEGACIÓN
  // ════════════════════════════════════════════════════════════════

  Future<void> _nuevoRecibo() async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReciboFormScreen(
          propietarioIdInicial: widget.propietarioId,
          contratoIdInicial: _contratoSeleccionadoId,
        ),
      ),
    );
    if (resultado == true) _cargarDatos();
  }

  Future<void> _verRecibo(int reciboId) async {
    final datos = await _db.obtenerReciboPorId(reciboId);
    if (datos == null) return;

    final serviciosMap = await _db.obtenerServiciosPorRecibo(reciboId);
    final recibo = ReciboModel.fromMap(
      datos,
      servicios: serviciosMap
          .map((s) => ServicioItemModel.fromMap(s))
          .toList(),
    );

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReciboPreviewScreen(recibo: recibo),
        ),
      );
    }
  }

  // ════════════════════════════════════════════════════════════════
  // ACCIONES DE RECIBO
  // ════════════════════════════════════════════════════════════════

  Future<void> _confirmarEliminarRecibo(
      int reciboId, int numero) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Recibo'),
        content: Text(
            '¿Querés eliminar el recibo N° ${numero.toString().padLeft(4, '0')}?\nEsta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC62828),
                foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _db.eliminarRecibo(reciboId);
      _cargarDatos();
    }
  }

  Future<void> _cambiarEstadoRecibo(Map<String, dynamic> r) async {
    final reciboId = r['id'] as int;
    final estadoActual = r['estado'] as String? ?? 'pendiente';
    final numero =
        (r['numero_recibo'] as int? ?? 0).toString().padLeft(4, '0');
    final montoTotal = (r['monto_total'] as num?)?.toDouble() ?? 0.0;
    final fmt = NumberFormat.currency(
        locale: 'es_AR', symbol: '\$', decimalDigits: 0, customPattern: '\u00A4#,##0');

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar Estado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recibo N° $numero',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Total: ${fmt.format(montoTotal)}'),
            const SizedBox(height: 4),
            Text(
                'Estado actual: ${_labelEstado(estadoActual)}'),
            const SizedBox(height: 12),
            const Text('¿Qué acción querés realizar?'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancelar')),
          if (estadoActual != 'pagado')
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, 'pagado'),
              icon: const Icon(Icons.check_circle, size: 14),
              label: const Text('Marcar Pagado'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white),
            ),
          if (estadoActual == 'pagado')
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(ctx, 'pendiente'),
              icon: const Icon(Icons.hourglass_empty, size: 14),
              label: const Text('Marcar Pendiente'),
            ),
        ],
      ),
    );

    if (result == null) return;

    if (result == 'pagado') {
      await _db.actualizarRecibo(reciboId, {
        'estado': 'pagado',
        'monto_abonado': montoTotal,
        'saldo': 0.0,
      });
      final tel = _propietario?['telefono'] as String? ?? '';
      if (tel.isNotEmpty) _abrirWhatsApp(r, esPago: true);
    } else {
      await _db.actualizarRecibo(reciboId, {
        'estado': 'pendiente',
        'monto_abonado': 0.0,
        'saldo': montoTotal,
      });
    }
    _cargarDatos();
  }

  void _enviarMensajeWA(Map<String, dynamic> r) =>
      _abrirWhatsApp(r, esPago: false);

  Future<void> _abrirWhatsApp(Map<String, dynamic> r, {required bool esPago}) async {
    // Usar teléfono del inquilino (celular o telefono)
    final celular = (r['inquilino_celular'] as String? ?? '').trim();
    final telefono = (r['inquilino_telefono'] as String? ?? '').trim();
    final rawTel = celular.isNotEmpty ? celular : telefono;

    if (rawTel.isEmpty) {
      if (mounted) {
        mostrarNotificacion(context,
            texto: 'El inquilino no tiene teléfono registrado.',
            color: const Color(0xFFF57C00));
      }
      return;
    }

    final tel = normalizarTelefonoAR(rawTel);

    final inquilino = r['inquilino_nombre'] as String? ?? 'Inquilino';
    final numero =
        (r['numero_recibo'] as int? ?? 0).toString().padLeft(4, '0');
    final monto = (r['monto_total'] as num?)?.toDouble() ?? 0.0;
    final dir = r['direccion'] as String? ?? '';
    final fmt = NumberFormat.currency(
        locale: 'es_AR', symbol: '\$', decimalDigits: 0, customPattern: '\u00A4#,##0');
    final dirPart =
        dir.isNotEmpty ? 'correspondiente a *$dir* ' : '';

    final String mensaje = esPago
        ? 'Hola $inquilino!\n'
            'Le informamos que el recibo N° $numero por *${fmt.format(monto)}* '
            '${dirPart}ha sido registrado como *PAGADO*.\n'
            '¡Muchas gracias por su pago!\n'
            '_Coppola Pavese Inmobiliaria_'
        : 'Hola $inquilino!\n'
            'Le recordamos que el recibo N° $numero por *${fmt.format(monto)}* '
            '${dirPart}se encuentra *pendiente de pago*.\n'
            'Por favor, realice el pago a la brevedad.\n'
            '_Coppola Pavese Inmobiliaria_';

    await abrirWhatsApp(telefono: tel, mensaje: mensaje);
    if (!mounted) return;
    await mostrarConfirmacionWhatsApp(
      context: context,
      nombreCompleto: inquilino,
      telefono: tel,
    );
  }

  // ════════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════════

  String _formatearFecha(String fecha) {
    if (fecha.isEmpty) return '—';
    try {
      final dt = DateTime.parse(fecha);
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return fecha;
    }
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'pagado':
        return const Color(0xFF2E7D32);
      case 'parcial':
        return const Color(0xFFF57C00);
      default:
        return const Color(0xFFC62828);
    }
  }

  String _labelEstado(String estado) {
    switch (estado) {
      case 'pagado':
        return 'Pagado';
      case 'parcial':
        return 'Parcial';
      default:
        return 'Pendiente';
    }
  }
}
