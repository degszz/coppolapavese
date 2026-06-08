import 'dart:async';
import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/inquilino_model.dart';
import '../../utils/snackbar_helper.dart';
import '../contratos/contrato_form_screen.dart'; // InquilinoDialog
import '../recibos/recibo_form_screen.dart';

class InquilinosListScreen extends StatefulWidget {
  final String? busquedaInicial;
  const InquilinosListScreen({super.key, this.busquedaInicial});

  @override
  State<InquilinosListScreen> createState() => _InquilinosListScreenState();
}

class _InquilinosListScreenState extends State<InquilinosListScreen> {
  static const _magenta = Color(0xFFC2185B);
  static const _dark = Color(0xFF212121);
  static const _gray = Color(0xFF757575);

  final _db = DatabaseHelper();
  List<Map<String, dynamic>> _inquilinos = [];
  List<Map<String, dynamic>> _filtrados = [];
  bool _cargando = true;
  final _busquedaCtrl = TextEditingController();
  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    if (widget.busquedaInicial != null && widget.busquedaInicial!.isNotEmpty) {
      _busquedaCtrl.text = widget.busquedaInicial!;
    }
    _cargar();
    _busquedaCtrl.addListener(_filtrar);
    _autoRefresh = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refrescoSilencioso(),
    );
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _refrescoSilencioso() async {
    try {
      final data = await _db.obtenerInquilinosConDetalle();
      if (mounted) {
        setState(() {
          _inquilinos = data;
          _filtrar();
        });
      }
    } catch (_) {}
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final data = await _db.obtenerInquilinosConDetalle();
      setState(() {
        _inquilinos = data;
        _filtrados = data;
        _cargando = false;
      });
    } catch (e) {
      setState(() => _cargando = false);
      if (mounted) {
        mostrarNotificacion(context,
            texto: 'Error al cargar inquilinos: $e',
            color: const Color(0xFFC62828));
      }
    }
  }

  void _filtrar() {
    final q = _busquedaCtrl.text.toLowerCase();
    setState(() {
      _filtrados = _inquilinos.where((i) {
        final nombre = (i['nombre'] as String? ?? '').toLowerCase();
        final apellido = (i['apellido'] as String? ?? '').toLowerCase();
        final propietario =
            (i['propietario_nombre'] as String? ?? '').toLowerCase();
        final direccion =
            (i['propiedad_direccion'] as String? ?? '').toLowerCase();
        return nombre.contains(q) ||
            apellido.contains(q) ||
            propietario.contains(q) ||
            direccion.contains(q);
      }).toList();
    });
  }

  Future<void> _nuevo() async {
    final creado = await showDialog<InquilinoModel>(
      context: context,
      builder: (_) => const InquilinoDialog(),
    );
    if (creado != null) _cargar();
  }

  Future<void> _editar(Map<String, dynamic> datos) async {
    final model = InquilinoModel.fromMap(datos);
    final editado = await showDialog<InquilinoModel>(
      context: context,
      builder: (_) => InquilinoDialog(inquilinoExistente: model),
    );
    if (editado != null) _cargar();
  }

  Future<void> _eliminar(int id, String nombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar inquilino'),
        content:
            Text('Se eliminará a "$nombre". Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await _db.eliminarInquilino(id);
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inquilinos',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _magenta,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargar,
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
                : _filtrados.isEmpty
                    ? _estadoVacio()
                    : RefreshIndicator(
                        onRefresh: _cargar,
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 0,
                            childAspectRatio: 5.5 / (MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.3)),
                          ),
                          itemCount: _filtrados.length,
                          itemBuilder: (_, i) =>
                              _tarjetaInquilino(_filtrados[i]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevo,
        backgroundColor: _magenta,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo Inquilino'),
      ),
    );
  }

  // ── Barra de búsqueda ──────────────────────────────────
  Widget _barBusqueda() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: _busquedaCtrl,
        decoration: InputDecoration(
          hintText: 'Buscar inquilino, propietario o dirección...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _busquedaCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _busquedaCtrl.clear();
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

  // ── Tarjeta de inquilino ───────────────────────────────
  Widget _tarjetaInquilino(Map<String, dynamic> datos) {
    final nombre = datos['nombre'] as String? ?? '';
    final apellido = datos['apellido'] as String? ?? '';
    final nombreCompleto =
        apellido.isNotEmpty ? '$nombre $apellido' : nombre;
    final propietario =
        datos['propietario_nombre'] as String? ?? 'Sin propietario';
    final direccion =
        datos['propiedad_direccion'] as String? ?? 'Sin propiedad';
    final localidad =
        datos['propiedad_localidad'] as String? ?? '';
    final telefono = datos['telefono'] as String? ?? '';
    final celular = datos['celular'] as String? ?? '';
    final email = datos['email'] as String? ?? '';
    final id = datos['id'] as int;
    final tieneContrato = datos['contrato_id'] != null;

    final contacto = celular.isNotEmpty
        ? celular
        : telefono.isNotEmpty
            ? telefono
            : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _editar(datos),
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
                    backgroundColor: _magenta.withOpacity(0.12),
                    child: Text(
                      nombreCompleto.isNotEmpty
                          ? nombreCompleto[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: _magenta,
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
                          nombreCompleto.isEmpty ? 'Sin nombre' : nombreCompleto,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _dark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Propietario: $propietario',
                          style: const TextStyle(fontSize: 11, color: _gray),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Badge contrato
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: tieneContrato
                          ? const Color(0xFF2E7D32).withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: tieneContrato
                            ? const Color(0xFF2E7D32).withOpacity(0.4)
                            : Colors.orange.withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tieneContrato ? Icons.check_circle : Icons.info_outline,
                          size: 11,
                          color: tieneContrato
                              ? const Color(0xFF2E7D32)
                              : Colors.orange,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          tieneContrato ? 'Contrato' : 'Sin contrato',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: tieneContrato
                                ? const Color(0xFF2E7D32)
                                : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // ── Propiedad + contacto ───────────────────
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
                      style: const TextStyle(fontSize: 11, color: _gray),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (contacto.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.phone_outlined,
                        size: 13, color: Color(0xFF9E9E9E)),
                    const SizedBox(width: 3),
                    Text(contacto,
                        style: const TextStyle(fontSize: 11, color: _gray)),
                  ],
                ],
              ),
              const SizedBox(height: 6),

              // ── Botones ────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (email.isNotEmpty)
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.email_outlined,
                              size: 13, color: Color(0xFF9E9E9E)),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(email,
                                style: const TextStyle(fontSize: 11, color: _gray),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  InkWell(
                    onTap: () => _eliminar(id, nombreCompleto),
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline, size: 18, color: Color(0xFFC62828)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (tieneContrato) ...[
                    InkWell(
                      onTap: () {
                        final contratoId = datos['contrato_id'] as int;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReciboFormScreen(
                              contratoIdInicial: contratoId,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A3A5C),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Recibo', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  InkWell(
                    onTap: () => _editar(datos),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _magenta,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_outlined, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Editar', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
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

  Widget _estadoVacio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_outlined,
              size: 72, color: Colors.grey.withOpacity(0.4)),
          const SizedBox(height: 16),
          const Text(
            'No hay inquilinos registrados',
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
}
