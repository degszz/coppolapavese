import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../utils/snackbar_helper.dart';
import 'propietario_form_screen.dart';
import 'propietario_detalle_screen.dart';

class PropietariosListScreen extends StatefulWidget {
  const PropietariosListScreen({super.key});

  @override
  State<PropietariosListScreen> createState() => _PropietariosListScreenState();
}

class _PropietariosListScreenState extends State<PropietariosListScreen> {
  final _db = DatabaseHelper();
  List<Map<String, dynamic>> _propietarios = [];
  List<Map<String, dynamic>> _propietariosFiltrados = [];
  bool _cargando = true;
  final _busquedaController = TextEditingController();
  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    _cargarPropietarios();
    _busquedaController.addListener(_filtrar);
    _autoRefresh = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refrescoSilencioso(),
    );
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _refrescoSilencioso() async {
    try {
      final data = await _db.obtenerResumenPorPropietario();
      if (mounted) {
        setState(() {
          _propietarios = data;
          _filtrar();
        });
      }
    } catch (_) {}
  }

  Future<void> _cargarPropietarios() async {
    setState(() => _cargando = true);
    try {
      final data = await _db.obtenerResumenPorPropietario();
      setState(() {
        _propietarios = data;
        _propietariosFiltrados = data;
        _cargando = false;
      });
    } catch (e) {
      setState(() => _cargando = false);
      if (mounted) {
        mostrarNotificacion(context,
            texto: 'Error al cargar propietarios: $e',
            color: const Color(0xFFC62828));
      }
    }
  }

  void _filtrar() {
    final q = _busquedaController.text.toLowerCase();
    setState(() {
      _propietariosFiltrados = _propietarios.where((p) {
        final nombre = (p['propietario_nombre'] as String? ?? '').toLowerCase();
        final inquilino =
            (p['inquilino_nombre'] as String? ?? '').toLowerCase();
        final direccion = (p['direccion'] as String? ?? '').toLowerCase();
        return nombre.contains(q) ||
            inquilino.contains(q) ||
            direccion.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Propietarios',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFC2185B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarPropietarios,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          _barBusqueda(),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _propietariosFiltrados.isEmpty
                    ? _estadoVacio()
                    : RefreshIndicator(
                        onRefresh: _cargarPropietarios,
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 0,
                            childAspectRatio: 5.5 / (MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.3)),
                          ),
                          itemCount: _propietariosFiltrados.length,
                          itemBuilder: (context, i) =>
                              _tarjetaPropietario(_propietariosFiltrados[i]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _irAFormulario,
        backgroundColor: const Color(0xFFC2185B),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo Propietario'),
      ),
    );
  }

  Widget _barBusqueda() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: _busquedaController,
        decoration: InputDecoration(
          hintText: 'Buscar propietario, inquilino o dirección...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _busquedaController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _busquedaController.clear();
                    _filtrar();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
    );
  }

  Widget _tarjetaPropietario(Map<String, dynamic> datos) {
    final nombre = datos['propietario_nombre'] as String? ?? 'Sin nombre';
    final inquilino = datos['inquilino_nombre'] as String? ?? 'Sin inquilino';
    final direccion = datos['direccion'] as String? ?? 'Sin dirección';
    final localidad = datos['localidad'] as String? ?? '';
    final totalPendiente =
        (datos['total_pendiente'] as num?)?.toDouble() ?? 0.0;
    final totalCobrado = (datos['total_cobrado'] as num?)?.toDouble() ?? 0.0;
    final totalRecibos = (datos['total_recibos'] as num?)?.toInt() ?? 0;
    final propietarioId = datos['id'] as int;

    // Estado visual
    Color estadoColor;
    String estadoLabel;
    IconData estadoIcono;

    if (totalPendiente <= 0) {
      estadoColor = const Color(0xFF2E7D32);
      estadoLabel = 'Al día';
      estadoIcono = Icons.check_circle;
    } else if (totalCobrado > 0) {
      estadoColor = const Color(0xFFF57C00);
      estadoLabel = 'Parcial';
      estadoIcono = Icons.warning_amber_rounded;
    } else {
      estadoColor = const Color(0xFFC62828);
      estadoLabel = 'Deudor';
      estadoIcono = Icons.cancel;
    }

    final fmt = NumberFormat.currency(
      locale: 'es_AR',
      symbol: '\$',
      decimalDigits: 0,
      customPattern: '\u00A4#,##0',
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _verDetalle(propietarioId, nombre),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Encabezado ─────────────────────────────
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        const Color(0xFFC2185B).withOpacity(0.12),
                    child: Text(
                      nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Color(0xFFC2185B),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombre,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF212121),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Inquilino: $inquilino',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF757575),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Badge estado
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: estadoColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: estadoColor.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(estadoIcono, size: 11, color: estadoColor),
                        const SizedBox(width: 3),
                        Text(
                          estadoLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: estadoColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // ── Dirección ──────────────────────────────
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 13, color: Color(0xFF9E9E9E)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      localidad.isNotEmpty
                          ? '$direccion, $localidad'
                          : direccion,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF757575)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // ── Montos + Botones en una fila ───────────
              Row(
                children: [
                  _infoMontoCompacto(fmt.format(totalCobrado), 'Cobrado', const Color(0xFF2E7D32)),
                  const SizedBox(width: 6),
                  _infoMontoCompacto(fmt.format(totalPendiente), 'Pendiente',
                      totalPendiente > 0 ? const Color(0xFFC62828) : const Color(0xFF2E7D32)),
                  const SizedBox(width: 6),
                  _infoMontoCompacto('$totalRecibos', 'Recibos', const Color(0xFF1565C0)),
                  const Spacer(),
                  InkWell(
                    onTap: () => _irAFormularioEditar(datos),
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.edit_outlined, size: 18, color: Color(0xFF1565C0)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _verDetalle(propietarioId, nombre),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC2185B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.visibility_outlined, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Detalle', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
                        ],
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

  Widget _infoMontoCompacto(String monto, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(monto, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF9E9E9E))),
      ],
    );
  }

  Widget _infoMonto({
    required String label,
    required String monto,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          monto,
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
          style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _estadoVacio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline,
              size: 72, color: Colors.grey.withOpacity(0.4)),
          const SizedBox(height: 16),
          const Text(
            'No hay propietarios registrados',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF9E9E9E),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Toca el botón + para agregar uno',
            style: TextStyle(fontSize: 13, color: Color(0xFFBDBDBD)),
          ),
        ],
      ),
    );
  }

  Future<void> _irAFormulario() async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => const PropietarioFormScreen()),
    );
    if (resultado == true) _cargarPropietarios();
  }

  Future<void> _irAFormularioEditar(Map<String, dynamic> datos) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PropietarioFormScreen(datosExistentes: datos),
      ),
    );
    if (resultado == true) _cargarPropietarios();
  }

  void _verDetalle(int propietarioId, String nombre) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PropietarioDetalleScreen(
          propietarioId: propietarioId,
          nombrePropietario: nombre,
        ),
      ),
    ).then((_) => _cargarPropietarios());
  }
}
