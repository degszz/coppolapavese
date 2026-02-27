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

  // Resumen financiero
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
          await _db.obtenerRecibosPorPropietario(widget.propietarioId);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nombrePropietario),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _panelResumen()),
                  SliverToBoxAdapter(child: _panelFinanciero()),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long,
                              size: 18, color: Color(0xFFC2185B)),
                          const SizedBox(width: 8),
                          Text(
                            'Historial de Recibos (${_recibos.length})',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF212121),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _recibos.isEmpty
                      ? SliverToBoxAdapter(child: _sinRecibos())
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => _tarjetaRecibo(_recibos[i]),
                            childCount: _recibos.length,
                          ),
                        ),
                  const SliverToBoxAdapter(
                      child: SizedBox(height: 100)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevoRecibo,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Recibo'),
      ),
    );
  }

  // ── Panel de datos del propietario / inquilino ─────────────────
  Widget _panelResumen() {
    final inquilinos = _recibos.isNotEmpty
        ? _recibos.first['inquilino_nombre'] as String? ?? 'Sin inquilino'
        : 'Sin inquilino';
    final direccion = _recibos.isNotEmpty
        ? _recibos.first['direccion'] as String? ?? ''
        : '';
    final localidad = _recibos.isNotEmpty
        ? _recibos.first['localidad'] as String? ?? ''
        : '';
    final telefono =
        _propietario?['telefono'] as String? ?? '';
    final email = _propietario?['email'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFC2185B), Color(0xFF880E4F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Text(
                  widget.nombrePropietario.isNotEmpty
                      ? widget.nombrePropietario[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.nombrePropietario,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
          const SizedBox(height: 14),
          const Divider(color: Colors.white24),
          const SizedBox(height: 10),
          if (telefono.isNotEmpty)
            _filaInfo(Icons.phone, telefono),
          if (email.isNotEmpty)
            _filaInfo(Icons.email_outlined, email),
          _filaInfo(Icons.person_outline, 'Inquilino: $inquilinos'),
          if (direccion.isNotEmpty)
            _filaInfo(
              Icons.location_on_outlined,
              localidad.isNotEmpty ? '$direccion, $localidad' : direccion,
            ),
        ],
      ),
    );
  }

  Widget _filaInfo(IconData icono, String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icono, size: 14, color: Colors.white70),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style:
                  const TextStyle(color: Colors.white, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Panel financiero ───────────────────────────────────────────
  Widget _panelFinanciero() {
    final fmt = NumberFormat.currency(
        locale: 'es_AR', symbol: '\$', decimalDigits: 0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: _celda(
                  label: 'Total Facturado',
                  valor: fmt.format(_totalMonto),
                  color: const Color(0xFF1565C0),
                ),
              ),
              _divisor(),
              Expanded(
                child: _celda(
                  label: 'Total Cobrado',
                  valor: fmt.format(_totalCobrado),
                  color: const Color(0xFF2E7D32),
                ),
              ),
              _divisor(),
              Expanded(
                child: _celda(
                  label: 'Saldo Pendiente',
                  valor: fmt.format(_totalPendiente),
                  color: _totalPendiente > 0
                      ? const Color(0xFFC62828)
                      : const Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _celda(
      {required String label,
      required String valor,
      required Color color}) {
    return Column(
      children: [
        Text(
          valor,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _divisor() => Container(
        width: 1,
        height: 36,
        color: const Color(0xFFE0E0E0),
      );

  // ── Tarjeta de recibo en el historial ─────────────────────────
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

    final colorEstado = _colorEstado(estado);
    final labelEstado = _labelEstado(estado);

    final fmt = NumberFormat.currency(
        locale: 'es_AR', symbol: '\$', decimalDigits: 0);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado fila
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC2185B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'N° ${numeroRecibo.toString().padLeft(4, '0')}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFFC2185B),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Emisión: $fechaEmision',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF757575)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colorEstado.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: colorEstado.withOpacity(0.4)),
                  ),
                  child: Text(
                    labelEstado,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colorEstado,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Fechas y montos
            Row(
              children: [
                const Icon(Icons.event, size: 13,
                    color: Color(0xFF9E9E9E)),
                const SizedBox(width: 4),
                Text(
                  'Vence: $fechaVencimiento',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF9E9E9E)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _montoFila(
                      'Total', fmt.format(montoTotal),
                      const Color(0xFF1565C0)),
                ),
                Expanded(
                  child: _montoFila(
                      'Abonado', fmt.format(montoAbonado),
                      const Color(0xFF2E7D32)),
                ),
                Expanded(
                  child: _montoFila(
                      'Saldo', fmt.format(saldo),
                      saldo > 0
                          ? const Color(0xFFC62828)
                          : const Color(0xFF2E7D32)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Botón Ver Recibo
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _verRecibo(reciboId),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Ver Recibo'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _montoFila(String label, String valor, Color color) {
    return Column(
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
        Text(
          label,
          style:
              const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _sinRecibos() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 60, color: Colors.grey.withOpacity(0.4)),
          const SizedBox(height: 12),
          const Text(
            'Sin recibos registrados',
            style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 15),
          ),
          const SizedBox(height: 6),
          const Text(
            'Toca "+ Nuevo Recibo" para crear uno',
            style: TextStyle(color: Color(0xFFBDBDBD), fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ── Navegación ─────────────────────────────────────────────────

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
    // Cargar recibo completo con servicios
    final datos = await _db.obtenerReciboPorId(reciboId);
    if (datos == null) return;

    final serviciosMap =
        await _db.obtenerServiciosPorRecibo(reciboId);
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

  // ── Helpers ────────────────────────────────────────────────────

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
