import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import 'propietarios/propietarios_list_screen.dart';
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
    const PropietariosListScreen(),
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
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people, color: Color(0xFFC2185B)),
            label: 'Propietarios',
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
      setState(() {
        _estadisticas = stats;
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
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.1,
                      ),
                    ),
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

  String _formatearMonto(double monto) {
    final formatter = NumberFormat.currency(
      locale: 'es_AR',
      symbol: '\$',
      decimalDigits: 0,
    );
    return formatter.format(monto);
  }
}
