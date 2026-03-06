import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/recibo_model.dart';
import '../../models/servicio_item_model.dart';
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
  List<Map<String, dynamic>> _recibos = [];
  bool _cargando = true;

  double _totalMonto = 0;
  double _totalCobrado = 0;
  double _totalPendiente = 0;

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
      final recibos =
          await _db.obtenerRecibosConExtras(widget.propietarioId);

      double totalMonto = 0;
      double totalCobrado = 0;
      double totalPendiente = 0;

      for (final r in recibos) {
        totalMonto += (r['monto_total'] as num?)?.toDouble() ?? 0;
        totalCobrado += (r['monto_abonado'] as num?)?.toDouble() ?? 0;
        totalPendiente += (r['saldo'] as num?)?.toDouble() ?? 0;
      }

      setState(() {
        _propietario = propietario;
        _recibos = recibos;
        _totalMonto = totalMonto;
        _totalCobrado = totalCobrado;
        _totalPendiente = totalPendiente;
        _cargando = false;
      });
    } catch (e) {
      setState(() => _cargando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
      }
    }
  }

  // ════════════════════════════════════════════════════════════════
  // BUILD PRINCIPAL — layout de escritorio en dos columnas
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
                // ─── COLUMNA IZQUIERDA: info + financiero + acciones ──
                SizedBox(
                  width: 320,
                  child: _columnaIzquierda(),
                ),

                // ─── DIVISOR VERTICAL ─────────────────────────────────
                Container(
                  width: 1,
                  color: const Color(0xFFE0E0E0),
                ),

                // ─── COLUMNA DERECHA: historial de recibos ────────────
                Expanded(
                  child: _columnaDerecha(),
                ),
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
            _panelFinanciero(),
            const SizedBox(height: 20),
            _botonNuevoRecibo(),
            const SizedBox(height: 12),
            _botonVerTodos(),
          ],
        ),
      ),
    );
  }

  // ── Tarjeta de propietario con gradiente ───────────────────────
  Widget _tarjetaPropietario() {
    final inquilino = _recibos.isNotEmpty
        ? _recibos.first['inquilino_nombre'] as String? ?? 'Sin inquilino'
        : 'Sin inquilino';
    final direccion = _recibos.isNotEmpty
        ? _recibos.first['direccion'] as String? ?? ''
        : '';
    final localidad = _recibos.isNotEmpty
        ? _recibos.first['localidad'] as String? ?? ''
        : '';
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
          // Avatar + nombre
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
                    const Text(
                      'PROPIETARIO',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 14),
          if (telefono.isNotEmpty) _filaInfoTarjeta(Icons.phone, telefono),
          if (email.isNotEmpty) _filaInfoTarjeta(Icons.email_outlined, email),
          _filaInfoTarjeta(Icons.person_outline, 'Inq: $inquilino'),
          if (direccion.isNotEmpty)
            _filaInfoTarjeta(
              Icons.location_on_outlined,
              localidad.isNotEmpty ? '$direccion, $localidad' : direccion,
            ),
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

  // ── Panel financiero (3 celdas verticales) ─────────────────────
  Widget _panelFinanciero() {
    final fmt = NumberFormat.currency(
        locale: 'es_AR', symbol: '\$', decimalDigits: 0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        children: [
          _celdaFinanciero(
            label: 'Total Facturado',
            valor: fmt.format(_totalMonto),
            icono: Icons.receipt_long,
            color: const Color(0xFF1565C0),
            primero: true,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _celdaFinanciero(
            label: 'Total Cobrado',
            valor: fmt.format(_totalCobrado),
            icono: Icons.check_circle_outline,
            color: const Color(0xFF2E7D32),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _celdaFinanciero(
            label: 'Saldo Pendiente',
            valor: fmt.format(_totalPendiente),
            icono: Icons.pending_outlined,
            color: _totalPendiente > 0
                ? const Color(0xFFC62828)
                : const Color(0xFF2E7D32),
            ultimo: true,
          ),
        ],
      ),
    );
  }

  Widget _celdaFinanciero({
    required String label,
    required String valor,
    required IconData icono,
    required Color color,
    bool primero = false,
    bool ultimo = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(
          top: primero ? const Radius.circular(12) : Radius.zero,
          bottom: ultimo ? const Radius.circular(12) : Radius.zero,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icono, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF9E9E9E)),
                ),
                const SizedBox(height: 2),
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Encabezado de la columna derecha ──────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          color: Colors.white,
          child: Row(
            children: [
              const Icon(Icons.receipt_long,
                  size: 20, color: Color(0xFFC2185B)),
              const SizedBox(width: 10),
              Text(
                'Historial de Recibos',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF212121),
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

        // ── Lista de recibos ───────────────────────────────────────
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

  // ── Tarjeta individual de recibo (layout horizontal) ──────────
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

    // Extras del contrato
    final notasRecibo = r['notas_recibo'] as String?;
    final tieneNotas = notasRecibo != null && notasRecibo.trim().isNotEmpty;
    final alertarInquilino = (r['alertar_inquilino'] as int? ?? 0) == 1;
    final alertarPropietario = (r['alertar_propietario'] as int? ?? 0) == 1;
    final tieneAlertas = alertarInquilino || alertarPropietario;
    final cantidadConceptos = r['cantidad_conceptos'] as int? ?? 0;

    final colorEstado = _colorEstado(estado);
    final labelEstado = _labelEstado(estado);

    final fmt = NumberFormat.currency(
        locale: 'es_AR', symbol: '\$', decimalDigits: 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            // ── Número de recibo (columna izquierda) ──────────────
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
                const SizedBox(height: 6),
                // Badge estado
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: colorEstado.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: colorEstado.withOpacity(0.4)),
                  ),
                  child: Text(
                    labelEstado,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: colorEstado,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),

            // ── Fechas ────────────────────────────────────────────
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fechaFila(Icons.send, 'Emisión', fechaEmision),
                  const SizedBox(height: 4),
                  _fechaFila(Icons.event, 'Vence', fechaVencimiento),
                  if (tieneNotas || tieneAlertas || cantidadConceptos > 0) ...[
                    const SizedBox(height: 8),
                    _badgesExtras(
                      tieneNotas: tieneNotas,
                      tieneAlertas: tieneAlertas,
                      alertarInquilino: alertarInquilino,
                      alertarPropietario: alertarPropietario,
                      cantidadConceptos: cantidadConceptos,
                      notasRecibo: notasRecibo,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),

            // ── Montos (3 columnas) ───────────────────────────────
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

            // ── Botón Ver Recibo ──────────────────────────────────
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
            const SizedBox(width: 8),

            // ── Botón Estado ──────────────────────────────────────
            OutlinedButton.icon(
              onPressed: () => _cambiarEstadoRecibo(r),
              icon: Icon(
                estado == 'pagado'
                    ? Icons.hourglass_empty
                    : Icons.check_circle_outline,
                size: 14,
              ),
              label: Text(
                estado == 'pagado' ? 'Pendiente' : 'Pagado',
                style: const TextStyle(fontSize: 11),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: estado == 'pagado'
                    ? const Color(0xFFE65100)
                    : const Color(0xFF2E7D32),
                side: BorderSide(
                    color: estado == 'pagado'
                        ? const Color(0xFFE65100)
                        : const Color(0xFF2E7D32)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 6),

            // ── Botón WhatsApp ────────────────────────────────────
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

            // ── Botón Eliminar ────────────────────────────────────
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

  // ── Badges de extras (notas / alertas / conceptos) ────────────
  Widget _badgesExtras({
    required bool tieneNotas,
    required bool tieneAlertas,
    required bool alertarInquilino,
    required bool alertarPropietario,
    required int cantidadConceptos,
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
        if (cantidadConceptos > 0)
          Tooltip(
            message: '$cantidadConceptos concepto${cantidadConceptos == 1 ? '' : 's'} extra${cantidadConceptos == 1 ? '' : 's'}',
            child: _chip(
              icono: Icons.playlist_add_check,
              label:
                  '$cantidadConceptos extra${cantidadConceptos == 1 ? '' : 's'}',
              color: const Color(0xFF2E7D32),
              fondo: const Color(0xFFE8F5E9),
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

  // ── Sin recibos ───────────────────────────────────────────────
  Widget _sinRecibos() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 64, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text(
            'Sin recibos registrados',
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
        locale: 'es_AR', symbol: '\$', decimalDigits: 0);

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

  void _abrirWhatsApp(Map<String, dynamic> r, {required bool esPago}) {
    final rawTel =
        (_propietario?['telefono'] as String? ?? '').trim();
    if (rawTel.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('El propietario no tiene teléfono registrado.')));
      }
      return;
    }

    String tel = rawTel.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (tel.startsWith('0')) {
      tel = '+54${tel.substring(1)}';
    } else if (!tel.startsWith('+')) {
      tel = '+54$tel';
    }

    final nombre = _propietario?['nombre'] as String? ??
        widget.nombrePropietario;
    final numero =
        (r['numero_recibo'] as int? ?? 0).toString().padLeft(4, '0');
    final monto = (r['monto_total'] as num?)?.toDouble() ?? 0.0;
    final dir = r['direccion'] as String? ?? '';
    final fmt = NumberFormat.currency(
        locale: 'es_AR', symbol: '\$', decimalDigits: 0);
    final dirPart =
        dir.isNotEmpty ? 'correspondiente a *$dir* ' : '';

    final String mensaje = esPago
        ? 'Hola $nombre! 🏠\n'
            'Le informamos que el recibo N° $numero por *${fmt.format(monto)}* '
            '${dirPart}ha sido registrado como *PAGADO*. ✅\n'
            '¡Muchas gracias por su pago!\n'
            '_Coppola Pavese Inmobiliaria_'
        : 'Hola $nombre! 🏠\n'
            'Le recordamos que el recibo N° $numero por *${fmt.format(monto)}* '
            '${dirPart}se encuentra *pendiente de pago*. ⏳\n'
            'Por favor, realice el pago a la brevedad.\n'
            '_Coppola Pavese Inmobiliaria_';

    final url =
        'https://wa.me/$tel?text=${Uri.encodeComponent(mensaje)}';
    Process.run('cmd', ['/c', 'start', '', url]);
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
