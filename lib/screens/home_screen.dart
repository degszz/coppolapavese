import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import 'contratos/contratos_list_screen.dart';
import 'recibos/recibo_form_screen.dart';
import 'reportes/excel_export_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _indiceActual = 0;

  final List<Widget> _pantallas = [
    const _InicioTab(),
    const ContratosListScreen(),
    const ReciboFormScreen(),
    const ExcelExportScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _indiceActual,
        children: _pantallas,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceActual,
        onDestinationSelected: (index) =>
            setState(() => _indiceActual = index),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFC2185B).withOpacity(0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: Color(0xFFC2185B)),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description, color: Color(0xFFC2185B)),
            label: 'Contratos',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: Color(0xFFC2185B)),
            label: 'Nuevo Recibo',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart, color: Color(0xFFC2185B)),
            label: 'Reportes',
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB: INICIO
// ════════════════════════════════════════════════════════════════

class _InicioTab extends StatefulWidget {
  const _InicioTab();

  @override
  State<_InicioTab> createState() => _InicioTabState();
}

class _InicioTabState extends State<_InicioTab> {
  final _db = DatabaseHelper();
  Map<String, dynamic> _estadisticas = {};
  List<Map<String, dynamic>> _recibosPendientes = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarEstadisticas();
  }

  Future<void> _cargarEstadisticas() async {
    setState(() => _cargando = true);
    try {
      final stats = await _db.obtenerEstadisticasGenerales();
      final pendientes = await _db.obtenerRecibosPendientes();
      setState(() {
        _estadisticas = stats;
        _recibosPendientes = pendientes;
        _cargando = false;
      });
    } catch (e) {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mes = DateFormat('MMMM yyyy', 'es_AR').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coppola Pavese Inmobiliaria'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarEstadisticas,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargarEstadisticas,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _encabezado(mes),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    sliver: SliverGrid(
                      delegate: SliverChildListDelegate([
                        _tarjetaEstadistica(
                          icono: Icons.people,
                          titulo: 'Propietarios',
                          valor: '${_estadisticas['total_propietarios'] ?? 0}',
                          subtitulo: 'activos',
                          color: const Color(0xFFC2185B),
                        ),
                        _tarjetaEstadistica(
                          icono: Icons.receipt_long,
                          titulo: 'Recibos del Mes',
                          valor: '${_estadisticas['recibos_mes'] ?? 0}',
                          subtitulo: mes,
                          color: const Color(0xFF1565C0),
                        ),
                        _tarjetaEstadistica(
                          icono: Icons.check_circle,
                          titulo: 'Cobrado este Mes',
                          valor: _formatearMonto(
                              (_estadisticas['cobrado_mes'] ?? 0.0) as double),
                          subtitulo: 'total cobrado',
                          color: const Color(0xFF2E7D32),
                        ),
                        _tarjetaEstadistica(
                          icono: Icons.pending_actions,
                          titulo: 'Pendiente Total',
                          valor: _formatearMonto(
                              (_estadisticas['pendiente_total'] ?? 0.0)
                                  as double),
                          subtitulo: 'por cobrar',
                          color: const Color(0xFFE65100),
                        ),
                      ]),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.6,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _seccionRecibosPendientes(),
                  ),
                  SliverToBoxAdapter(
                    child: _seccionAccesosRapidos(context),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _encabezado(String mes) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFC2185B), Color(0xFF880E4F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC2185B).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo circular
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.home_work, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Coppola Pavese',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'INMOBILIARIA',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mes.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaEstadistica({
    required IconData icono,
    required String titulo,
    required String valor,
    required String subtitulo,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icono, color: color, size: 22),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF212121),
                  ),
                ),
                Text(
                  subtitulo,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF757575),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccionAccesosRapidos(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Accesos Rápidos',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF212121),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _botonAcceso(
                  icono: Icons.add_circle_outline,
                  label: 'Nuevo Recibo',
                  color: const Color(0xFFC2185B),
                  onTap: () {
                    final state = context
                        .findAncestorStateOfType<_HomeScreenState>();
                    state?.setState(() => state._indiceActual = 2);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _botonAcceso(
                  icono: Icons.people_outline,
                  label: 'Propietarios',
                  color: const Color(0xFF1565C0),
                  onTap: () {
                    final state = context
                        .findAncestorStateOfType<_HomeScreenState>();
                    state?.setState(() => state._indiceActual = 1);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _botonAcceso(
                  icono: Icons.file_download_outlined,
                  label: 'Exportar',
                  color: const Color(0xFF2E7D32),
                  onTap: () {
                    final state = context
                        .findAncestorStateOfType<_HomeScreenState>();
                    state?.setState(() => state._indiceActual = 3);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _botonAcceso({
    required IconData icono,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icono, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── SECCIÓN RECIBOS PENDIENTES ─────────────────────────────────

  Widget _seccionRecibosPendientes() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.pending_actions,
                  size: 18, color: Color(0xFFE65100)),
              const SizedBox(width: 8),
              const Text(
                'Recibos Pendientes',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF212121)),
              ),
              const SizedBox(width: 8),
              if (_recibosPendientes.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE65100).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_recibosPendientes.length}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE65100)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (_recibosPendientes.isEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF2E7D32).withOpacity(0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle,
                      color: Color(0xFF2E7D32), size: 18),
                  SizedBox(width: 10),
                  Text('Sin recibos pendientes este período',
                      style: TextStyle(
                          color: Color(0xFF2E7D32), fontSize: 13)),
                ],
              ),
            )
          else
            ..._recibosPendientes.map((r) => _filaPendiente(r)),
        ],
      ),
    );
  }

  Widget _filaPendiente(Map<String, dynamic> r) {
    final numero =
        (r['numero_recibo'] as int? ?? 0).toString().padLeft(4, '0');
    final nombre = r['propietario_nombre'] as String? ?? '—';
    final saldo = (r['saldo'] as num?)?.toDouble() ?? 0.0;
    final estado = r['estado'] as String? ?? 'pendiente';
    final reciboId = r['id'] as int;
    final fmt = NumberFormat.currency(
        locale: 'es_AR', symbol: '\$', decimalDigits: 0);

    final colorEstado = estado == 'parcial'
        ? const Color(0xFFF57C00)
        : const Color(0xFFC62828);
    final labelEstado =
        estado == 'parcial' ? 'PARCIAL' : 'PENDIENTE';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colorEstado.withOpacity(0.3)),
      ),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // N° recibo
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFC2185B).withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'N° $numero',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Color(0xFFC2185B)),
              ),
            ),
            const SizedBox(width: 12),

            // Nombre + saldo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                  Text('Saldo: ${fmt.format(saldo)}',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9E9E9E))),
                ],
              ),
            ),

            // Badge estado
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colorEstado,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(labelEstado,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
            const SizedBox(width: 10),

            // Botón Marcar Pagado
            OutlinedButton.icon(
              onPressed: () => _accionEstado(r),
              icon: const Icon(Icons.check_circle_outline, size: 14),
              label: const Text('Pagado',
                  style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2E7D32),
                side: const BorderSide(color: Color(0xFF2E7D32)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),

            // Botón Recordatorio WA
            IconButton(
              onPressed: () => _enviarRecordatorioWA(r),
              icon: const Icon(Icons.message_outlined, size: 18),
              color: const Color(0xFF25D366),
              tooltip: 'Enviar recordatorio por WhatsApp',
              style: IconButton.styleFrom(
                backgroundColor:
                    const Color(0xFF25D366).withOpacity(0.08),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 4),

            // Botón Eliminar
            IconButton(
              onPressed: () => _confirmarEliminar(reciboId, numero),
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

  // ── ACCIONES ──────────────────────────────────────────────────

  Future<void> _confirmarEliminar(int reciboId, String numero) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Recibo'),
        content: Text(
            '¿Querés eliminar el recibo N° $numero?\nEsta acción no se puede deshacer.'),
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
      _cargarEstadisticas();
    }
  }

  Future<void> _accionEstado(Map<String, dynamic> r) async {
    final numero =
        (r['numero_recibo'] as int? ?? 0).toString().padLeft(4, '0');
    final montoTotal = (r['monto_total'] as num?)?.toDouble() ?? 0.0;
    final telefono = r['propietario_telefono'] as String? ?? '';
    final fmt = NumberFormat.currency(
        locale: 'es_AR', symbol: '\$', decimalDigits: 0);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marcar como Pagado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recibo N° $numero',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Total: ${fmt.format(montoTotal)}'),
            const SizedBox(height: 12),
            const Text(
                '¿Confirmás que este recibo fue cobrado en su totalidad?'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancelar'),
              child: const Text('Cancelar')),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(ctx, 'pendiente'),
            icon: const Icon(Icons.hourglass_empty, size: 14),
            label: const Text('Mantener Pendiente'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, 'pagado'),
            icon: const Icon(Icons.check_circle, size: 14),
            label: const Text('Confirmar Pago'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white),
          ),
        ],
      ),
    );

    if (result == 'pagado') {
      await _db.actualizarRecibo(r['id'] as int, {
        'estado': 'pagado',
        'monto_abonado': montoTotal,
        'saldo': 0.0,
      });
      if (telefono.isNotEmpty) _abrirWhatsApp(r, esPago: true);
      _cargarEstadisticas();
    }
  }

  void _enviarRecordatorioWA(Map<String, dynamic> r) =>
      _abrirWhatsApp(r, esPago: false);

  void _abrirWhatsApp(Map<String, dynamic> r, {required bool esPago}) {
    final rawTel =
        (r['propietario_telefono'] as String? ?? '').trim();
    if (rawTel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('El propietario no tiene teléfono registrado.')));
      return;
    }

    String tel = rawTel.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (tel.startsWith('0')) {
      tel = '+54${tel.substring(1)}';
    } else if (!tel.startsWith('+')) {
      tel = '+54$tel';
    }

    final nombre = r['propietario_nombre'] as String? ?? 'cliente';
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

  String _formatearMonto(double monto) {
    final formatter = NumberFormat.currency(
      locale: 'es_AR',
      symbol: '\$',
      decimalDigits: 0,
    );
    return formatter.format(monto);
  }
}
