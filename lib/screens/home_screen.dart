import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../database/db_config.dart';
import '../main.dart' show zoomNotifier;
import '../models/inquilino_model.dart';
import '../utils/snackbar_helper.dart';
import '../utils/whatsapp_launcher.dart';
import '../widgets/calendario_recibos.dart';
import '../widgets/print_queue_dialog.dart';
import '../models/recibo_model.dart';
import '../models/servicio_item_model.dart';
import 'configuracion/config_red_screen.dart';
import 'contratos/contrato_form_screen.dart';
import 'contratos/contratos_list_screen.dart';
import 'garantes/garantes_list_screen.dart';
import 'inquilinos/inquilinos_list_screen.dart';
import 'propiedades/propiedad_detalle_screen.dart';
import 'propiedades/propiedades_list_screen.dart';
import 'propietarios/propietario_detalle_screen.dart';
import 'propietarios/propietario_form_screen.dart';
import 'propietarios/propietarios_list_screen.dart';
import 'recibos/recibo_form_screen.dart';
import 'recibos/recibo_preview_screen.dart';
import 'reportes/excel_export_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _magenta = Color(0xFFC2185B);
  int _indiceActual = 0;

  // Claves que cambian al navegar al tab para forzar recarga de datos
  int _reciboKey = 0;
  int _reportesKey = 0;
  int _inquilinosKey = 0;
  int _garantesKey = 0;

  // Búsquedas iniciales para prefiltrar tabs al abrir desde el buscador global
  String? _busquedaInquilinos;
  String? _busquedaGarantes;

  // Orden: 0-Inicio, 1-Contratos, 2-NuevoRecibo, 3-Reportes,
  //        4-Propiedades, 5-Propietarios, 6-Inquilinos, 7-Garantes
  List<Widget> get _pantallas => [
    const _InicioTab(),
    const ContratosListScreen(),
    ReciboFormScreen(key: ValueKey(_reciboKey)),
    ExcelExportScreen(key: ValueKey(_reportesKey)),
    const PropiedadesListScreen(),
    const PropietariosListScreen(),
    InquilinosListScreen(
      key: ValueKey('inq_$_inquilinosKey'),
      busquedaInicial: _busquedaInquilinos,
    ),
    GarantesListScreen(
      key: ValueKey('gar_$_garantesKey'),
      busquedaInicial: _busquedaGarantes,
    ),
  ];

  void _irANuevoContrato() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ContratoFormScreen()),
    );
  }

  void _irANuevoRecibo() {
    setState(() {
      _reciboKey++;
      _indiceActual = 2;
    });
  }

  Widget _botonNuevoCentral() {
    final btnKey = GlobalKey();
    return GestureDetector(
      onTap: () {
        final RenderBox box = btnKey.currentContext!.findRenderObject() as RenderBox;
        final Offset offset = box.localToGlobal(Offset.zero);
        showMenu<String>(
          context: context,
          position: RelativeRect.fromLTRB(
            offset.dx,
            offset.dy - 110, // arriba del botón
            offset.dx + box.size.width,
            offset.dy,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 8,
          items: [
            PopupMenuItem<String>(
              value: 'contrato',
              child: Row(
                children: [
                  Icon(Icons.description, color: _magenta, size: 20),
                  const SizedBox(width: 10),
                  const Text('Nuevo Contrato', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'recibo',
              child: Row(
                children: [
                  Icon(Icons.receipt_long, color: _magenta, size: 20),
                  const SizedBox(width: 10),
                  const Text('Nuevo Recibo', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ).then((value) {
          if (value == 'contrato') _irANuevoContrato();
          if (value == 'recibo') _irANuevoRecibo();
        });
      },
      child: Column(
        key: btnKey,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _magenta,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _magenta.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 2),
          const Text('Nuevo', style: TextStyle(fontSize: 9, color: _magenta, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _indiceActual,
        children: _pantallas,
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              // Izquierda: Inicio, Contratos, Nuevo Recibo, Reportes
              _navItem(0, Icons.home_outlined, Icons.home, 'Inicio'),
              _navItem(1, Icons.description_outlined, Icons.description, 'Contratos'),
              _navItem(2, Icons.receipt_long_outlined, Icons.receipt_long, 'Recibo'),
              _navItem(3, Icons.bar_chart_outlined, Icons.bar_chart, 'Reportes'),

              // Botón rosa central — Nuevo (popup)
              Expanded(
                child: _botonNuevoCentral(),
              ),

              // Derecha: Propiedades, Propietarios, Inquilinos, Garantes
              _navItem(4, Icons.apartment_outlined, Icons.apartment, 'Propiedades'),
              _navItem(5, Icons.people_outline, Icons.people, 'Propietarios'),
              _navItem(6, Icons.person_search_outlined, Icons.person_search, 'Inquilinos'),
              _navItem(7, Icons.verified_user_outlined, Icons.verified_user, 'Garantes'),

              // Zoom controls (vertical)
              Container(
                margin: const EdgeInsets.only(left: 2),
                padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ValueListenableBuilder<double>(
                  valueListenable: zoomNotifier,
                  builder: (_, zoom, __) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: zoom < 1.2
                            ? () {
                                final nz = (zoom + 0.05).clamp(0.8, 1.2);
                                zoomNotifier.value = nz;
                                DbConfig.instance.guardarZoom(nz);
                              }
                            : null,
                        child: Icon(Icons.add,
                            size: 14,
                            color: zoom < 1.2
                                ? _magenta
                                : const Color(0xFFBDBDBD)),
                      ),
                      Text(
                        '${(zoom * 100).round()}%',
                        style: const TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF757575)),
                      ),
                      InkWell(
                        onTap: zoom > 0.8
                            ? () {
                                final nz = (zoom - 0.05).clamp(0.8, 1.2);
                                zoomNotifier.value = nz;
                                DbConfig.instance.guardarZoom(nz);
                              }
                            : null,
                        child: Icon(Icons.remove,
                            size: 14,
                            color: zoom > 0.8
                                ? _magenta
                                : const Color(0xFFBDBDBD)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, IconData selectedIcon, String label) {
    final selected = _indiceActual == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() {
          if (index == 2) _reciboKey++;
          if (index == 3) _reportesKey++;
          _indiceActual = index;
        }),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? selectedIcon : icon,
              size: 22,
              color: selected ? _magenta : const Color(0xFF757575),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? _magenta : const Color(0xFF757575),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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
  final _calendarioKey = GlobalKey<CalendarioRecibosState>();
  List<Map<String, dynamic>> _recibosPendientes = [];
  bool _cargando = true;
  Timer? _autoRefresh;

  // ── Buscador global ──
  final _busquedaCtrl = TextEditingController();
  List<_ResultadoBusqueda> _resultados = [];
  bool _buscando = false;

  @override
  void initState() {
    super.initState();
    _cargarEstadisticas();
    // Auto-refresco cada 15 segundos para sincronización en red
    _autoRefresh = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _cargarEstadisticasSilencioso(),
    );
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarEstadisticas() async {
    setState(() => _cargando = true);
    try {
      final pendientes = await _db.obtenerRecibosPendientes();
      setState(() {
        _recibosPendientes = pendientes;
        _cargando = false;
      });
    } catch (e) {
      setState(() => _cargando = false);
    }
  }

  /// Refresco silencioso (sin spinner) para cambios de otro equipo
  Future<void> _cargarEstadisticasSilencioso() async {
    try {
      final pendientes = await _db.obtenerRecibosPendientes();
      if (mounted) {
        setState(() => _recibosPendientes = pendientes);
      }
    } catch (_) {}
  }

  Future<void> _buscar(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _resultados = [];
        _buscando = false;
      });
      return;
    }
    final datos = await _db.busquedaGlobal(query.trim());
    if (mounted) {
      setState(() {
        _buscando = true;
        _resultados = datos.map((d) => _ResultadoBusqueda(
          id: d['id'] as int,
          nombre: (d['nombre'] as String? ?? '').trim(),
          tipo: d['tipo'] as String? ?? '',
        )).toList();
      });
    }
  }

  Future<void> _abrirResultado(
      BuildContext context, _ResultadoBusqueda r) async {
    _busquedaCtrl.clear();
    setState(() {
      _resultados = [];
      _buscando = false;
    });
    switch (r.tipo) {
      case 'propietario':
        // Abrir detalle del propietario (historial de recibos) directamente
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PropietarioDetalleScreen(
              propietarioId: r.id,
              nombrePropietario: r.nombre,
            ),
          ),
        );
        break;
      case 'inquilino':
        // Buscar el contrato del inquilino y abrir el formulario de NUEVO RECIBO
        final contrato = await _db.obtenerContratoActivoPorInquilino(r.id);
        if (!context.mounted) return;
        if (contrato == null) {
          mostrarNotificacion(context,
              texto: '${r.nombre} no tiene contratos asociados',
              color: const Color(0xFFC62828));
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReciboFormScreen(
              contratoIdInicial: contrato['id'] as int,
            ),
          ),
        );
        break;
      case 'propiedad':
        // Abrir ficha de la propiedad directamente (carga/edición de ficha)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PropiedadDetalleScreen(propiedadId: r.id),
          ),
        );
        break;
      case 'garante':
        // Abrir directamente el diálogo de edición del garante
        await GarantesListScreen.mostrarDialogEditarGarante(context, r.id);
        break;
      case 'contrato':
        // Cargar el contrato y abrir el formulario en modo edición
        final contratoEditar = await _db.obtenerContratoPorId(r.id);
        if (!context.mounted) return;
        if (contratoEditar == null) {
          mostrarNotificacion(context,
              texto: 'No se encontró el contrato',
              color: const Color(0xFFC62828));
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ContratoFormScreen(
              datosExistentes: contratoEditar,
            ),
          ),
        );
        break;
    }
  }

  IconData _iconoTipo(String tipo) {
    switch (tipo) {
      case 'propietario': return Icons.person;
      case 'inquilino': return Icons.people;
      case 'propiedad': return Icons.home;
      case 'contrato': return Icons.description;
      case 'garante': return Icons.verified_user;
      default: return Icons.search;
    }
  }

  Color _colorTipo(String tipo) {
    switch (tipo) {
      case 'propietario': return const Color(0xFFC2185B);
      case 'inquilino': return const Color(0xFF00695C);
      case 'propiedad': return const Color(0xFFE65100);
      case 'contrato': return const Color(0xFF6A1B9A);
      case 'garante': return const Color(0xFF1565C0);
      default: return const Color(0xFF757575);
    }
  }

  String _labelTipo(String tipo) {
    switch (tipo) {
      case 'propietario': return 'Propietario';
      case 'inquilino': return 'Inquilino';
      case 'propiedad': return 'Propiedad';
      case 'contrato': return 'Contrato';
      case 'garante': return 'Garante';
      default: return tipo;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    final fechaHoy = DateFormat("d 'de' MMMM yyyy", 'es_AR').format(ahora);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFC2185B),
        foregroundColor: Colors.white,
        toolbarHeight: 52,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/cp.png',
                  width: 34,
                  height: 34,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Coppola Pavese',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  Text(fechaHoy,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.75))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined, size: 20),
            onPressed: () => showPrintQueueDialog(context),
            tooltip: 'Cola de impresi\u00f3n',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ConfigRedScreen()),
            ),
            tooltip: 'Configuraci\u00f3n de red',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
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
                  // ── Buscador global ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: _busquedaCtrl,
                            onChanged: _buscar,
                            decoration: InputDecoration(
                              hintText: 'Buscar propietario, inquilino, propiedad, contrato...',
                              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
                              prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFFC2185B)),
                              suffixIcon: _busquedaCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _busquedaCtrl.clear();
                                        _buscar('');
                                      },
                                    )
                                  : null,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFFC2185B), width: 1.5),
                              ),
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                          if (_buscando && _resultados.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              constraints: const BoxConstraints(maxHeight: 220),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE0E0E0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: _resultados.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (ctx, i) {
                                  final r = _resultados[i];
                                  return ListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    leading: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: _colorTipo(r.tipo).withOpacity(0.1),
                                      child: Icon(_iconoTipo(r.tipo), size: 14, color: _colorTipo(r.tipo)),
                                    ),
                                    title: Text(r.nombre,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _colorTipo(r.tipo).withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(_labelTipo(r.tipo),
                                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _colorTipo(r.tipo))),
                                    ),
                                    onTap: () => _abrirResultado(context, r),
                                  );
                                },
                              ),
                            ),
                          if (_buscando && _resultados.isEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE0E0E0)),
                              ),
                              child: const Text('Sin resultados',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                                  textAlign: TextAlign.center),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // 1) Accesos rápidos
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: _seccionAccesosRapidos(context),
                    ),
                  ),
                  // 2) Próximos 7 días
                  SliverToBoxAdapter(
                    child: CalendarioRecibos(
                      key: _calendarioKey,
                      onContratoTap: _irAFormConContrato,
                    ),
                  ),
                  // 3) Recibos pendientes
                  SliverToBoxAdapter(
                    child: _seccionRecibosPendientes(),
                  ),
                ],
              ),
      ),
    );
  }

  void _irATab(BuildContext context, int indice) {
    final state = context.findAncestorStateOfType<_HomeScreenState>();
    if (state != null) {
      if (indice == 2) state._reciboKey++;
      if (indice == 3) state._reportesKey++;
      state.setState(() => state._indiceActual = indice);
    }
  }

  Widget _seccionAccesosRapidos(BuildContext context) {
    void irATab(int indice) {
      final state = context.findAncestorStateOfType<_HomeScreenState>();
      if (state != null) {
        if (indice == 2) state._reciboKey++;
        if (indice == 3) state._reportesKey++;
        state.setState(() => state._indiceActual = indice);
      }
    }

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
                  icono: Icons.description_outlined,
                  label: 'Contrato',
                  prefijo: 'Nuevo',
                  color: const Color(0xFFE65100),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ContratoFormScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _botonAcceso(
                  icono: Icons.receipt_long_outlined,
                  label: 'Recibo',
                  prefijo: 'Nuevo',
                  color: const Color(0xFFC2185B),
                  onTap: () => irATab(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _botonAcceso(
                  icono: Icons.people_outline,
                  label: 'Propietario',
                  prefijo: 'Nuevo',
                  color: const Color(0xFF1565C0),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PropietarioFormScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _botonAcceso(
                  icono: Icons.person_add_outlined,
                  label: 'Inquilino',
                  prefijo: 'Nuevo',
                  color: const Color(0xFF6A1B9A),
                  onTap: () async {
                    await showDialog<InquilinoModel>(
                      context: context,
                      builder: (_) => const InquilinoDialog(),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _botonAcceso(
                  icono: Icons.apartment_outlined,
                  label: 'Propiedad',
                  prefijo: 'Nueva',
                  color: const Color(0xFF00695C),
                  onTap: () async {
                    await PropiedadesListScreen.mostrarDialogNuevaPropiedad(context);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _botonAcceso(
                  icono: Icons.verified_user_outlined,
                  label: 'Garante',
                  prefijo: 'Nuevo',
                  color: const Color(0xFF4E342E),
                  onTap: () async {
                    await GarantesListScreen.mostrarDialogNuevoGarante(context);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _botonAcceso(
                  icono: Icons.bar_chart_outlined,
                  label: 'Reportes',
                  color: const Color(0xFF2E7D32),
                  onTap: () => irATab(3),
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
    String? prefijo,
    required Color color,
    required VoidCallback onTap,
  }) {
    return _AccesoRapidoInteractivo(
      icono: icono,
      label: label,
      prefijo: prefijo,
      color: color,
      onTap: onTap,
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
            _gridPendientes(),
        ],
      ),
    );
  }

  /// Muestra los recibos pendientes en 2 columnas.
  Widget _gridPendientes() {
    final items = _recibosPendientes;
    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += 2) {
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _filaPendiente(items[i])),
          const SizedBox(width: 8),
          if (i + 1 < items.length)
            Expanded(child: _filaPendiente(items[i + 1]))
          else
            const Expanded(child: SizedBox()),
        ],
      ));
      if (i + 2 < items.length) rows.add(const SizedBox(height: 8));
    }
    return Column(children: rows);
  }

  Widget _filaPendiente(Map<String, dynamic> r) {
    final numero =
        (r['numero_recibo'] as int? ?? 0).toString().padLeft(4, '0');
    final inqNombre = r['inquilino_nombre'] as String? ?? '';
    final inqApellido = r['inquilino_apellido'] as String? ?? '';
    final nombre = inqApellido.isNotEmpty
        ? '$inqNombre $inqApellido'
        : inqNombre.isNotEmpty
            ? inqNombre
            : '—';
    final saldo = (r['saldo'] as num?)?.toDouble() ?? 0.0;
    final estado = r['estado'] as String? ?? 'pendiente';
    final reciboId = r['id'] as int;
    final fmt = NumberFormat.currency(
        locale: 'es_AR', symbol: '\$', decimalDigits: 0, customPattern: '\u00A4#,##0');

    final colorEstado = estado == 'parcial'
        ? const Color(0xFFF57C00)
        : const Color(0xFFC62828);
    final labelEstado =
        estado == 'parcial' ? 'PARCIAL' : 'PENDIENTE';

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colorEstado.withOpacity(0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _verRecibo(reciboId),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Fila superior: N° + badge estado ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC2185B).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'N° $numero',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Color(0xFFC2185B)),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: colorEstado.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      labelEstado,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: colorEstado),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // ── Nombre inquilino ──
              Text(
                nombre,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 12),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 2),

              // ── Saldo ──
              Text(
                fmt.format(saldo),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF212121)),
              ),
              const SizedBox(height: 8),

              // ── Botones: toggle + WA + eliminar ──
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _accionEstado(r),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 5),
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
                          textAlign: TextAlign.center,
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
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => _enviarRecordatorioWA(r),
                      icon: const Icon(Icons.message_outlined, size: 16),
                      color: const Color(0xFF25D366),
                      tooltip: 'Enviar recordatorio por WhatsApp',
                      style: IconButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF25D366).withOpacity(0.08),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => _confirmarEliminar(reciboId, numero),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      color: const Color(0xFFC62828),
                      tooltip: 'Eliminar recibo',
                      style: IconButton.styleFrom(
                        backgroundColor:
                            const Color(0xFFC62828).withOpacity(0.08),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── ACCIONES ──────────────────────────────────────────────────

  /// Abre el formulario de Nuevo Recibo con el contrato precargado.
  /// Usado desde el calendario al clickear un contrato de un día.
  Future<void> _irAFormConContrato(int contratoId) async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReciboFormScreen(contratoIdInicial: contratoId),
      ),
    );
    // Al volver, refrescar el calendario (puede haberse emitido un recibo)
    if (!mounted) return;
    _calendarioKey.currentState?.refrescar();
    _cargarEstadisticas();
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

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReciboPreviewScreen(recibo: recibo),
      ),
    );
    // Al volver, recargar pendientes por si cambió el estado
    _cargarEstadisticas();
  }

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
    final celInq = (r['inquilino_celular'] as String? ?? '').trim();
    final telInq = (r['inquilino_telefono'] as String? ?? '').trim();
    final telefonoInquilino = celInq.isNotEmpty ? celInq : telInq;
    final fmt = NumberFormat.currency(
        locale: 'es_AR', symbol: '\$', decimalDigits: 0, customPattern: '\u00A4#,##0');

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
      if (telefonoInquilino.isNotEmpty) _abrirWhatsApp(r, esPago: true);
      _cargarEstadisticas();
    }
  }

  void _enviarRecordatorioWA(Map<String, dynamic> r) =>
      _abrirWhatsApp(r, esPago: false);

  Future<void> _abrirWhatsApp(Map<String, dynamic> r, {required bool esPago}) async {
    // Usar teléfono del inquilino (celular o telefono)
    final celular = (r['inquilino_celular'] as String? ?? '').trim();
    final telefono = (r['inquilino_telefono'] as String? ?? '').trim();
    final rawTel = celular.isNotEmpty ? celular : telefono;

    if (rawTel.isEmpty) {
      mostrarNotificacion(context,
          texto: 'El inquilino no tiene teléfono registrado.',
          color: const Color(0xFFF57C00));
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
}

class _ResultadoBusqueda {
  final int id;
  final String nombre;
  final String tipo;
  const _ResultadoBusqueda({required this.id, required this.nombre, required this.tipo});
}

// ════════════════════════════════════════════════════════════════════
// Botón de Acceso Rápido con hover interactivo
// ════════════════════════════════════════════════════════════════════

class _AccesoRapidoInteractivo extends StatefulWidget {
  final IconData icono;
  final String label;
  final String? prefijo;
  final Color color;
  final VoidCallback onTap;

  const _AccesoRapidoInteractivo({
    required this.icono,
    required this.label,
    this.prefijo,
    required this.color,
    required this.onTap,
  });

  @override
  State<_AccesoRapidoInteractivo> createState() =>
      _AccesoRapidoInteractivoState();
}

class _AccesoRapidoInteractivoState
    extends State<_AccesoRapidoInteractivo>
    with SingleTickerProviderStateMixin {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    // Escala suave (visual, no afecta layout) y un ligero lift.
    // Importante: transform NO empuja a los widgets vecinos.
    final scale = _pressed ? 0.97 : (_hover ? 1.035 : 1.0);
    final bgAlpha = _hover ? 0.18 : 0.08;
    final borderAlpha = _hover ? 0.6 : 0.22;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        // Contenedor externo: altura FIJA → no shift del layout.
        child: SizedBox(
          height: 76,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOut,
            // Solo escala (visual, no modifica layout).
            transform: Matrix4.identity()..scale(scale),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.withValues(alpha: bgAlpha),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: c.withValues(alpha: borderAlpha),
                width: _hover ? 1.5 : 1.0,
              ),
              boxShadow: _hover
                  ? [
                      BoxShadow(
                        color: c.withValues(alpha: 0.28),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Barra inferior animada (0 → full width) como acento
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: _hover ? 0 : -80,
                  right: _hover ? 0 : -80,
                  bottom: 0,
                  height: 3,
                  child: Container(color: c),
                ),
                // Flecha en esquina superior derecha (fade+slide)
                Positioned(
                  top: 6,
                  right: 6,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 160),
                    opacity: _hover ? 1.0 : 0.0,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      offset: _hover ? Offset.zero : const Offset(-0.3, 0),
                      child: Icon(
                        Icons.arrow_outward,
                        size: 13,
                        color: c,
                      ),
                    ),
                  ),
                ),
                // Contenido principal
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ícono en círculo que se rellena al hover
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 170),
                        curve: Curves.easeOut,
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _hover ? c : c.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                          boxShadow: _hover
                              ? [
                                  BoxShadow(
                                    color: c.withValues(alpha: 0.45),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          widget.icono,
                          color: _hover ? Colors.white : c,
                          size: 18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Label con "Nuevo/Nueva" al lado del nombre principal.
                      // Usamos FittedBox para que siempre entre en una línea
                      // sin importar el ancho disponible.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: TextStyle(
                              color: c,
                              height: 1.1,
                            ),
                            children: [
                              if (widget.prefijo != null) ...[
                                TextSpan(
                                  text: widget.prefijo!.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.6,
                                    color: c.withValues(
                                        alpha: _hover ? 0.85 : 0.6),
                                  ),
                                ),
                                const TextSpan(text: '  '),
                              ],
                              TextSpan(
                                text: widget.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: _hover
                                      ? FontWeight.bold
                                      : FontWeight.w700,
                                  color: c,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
