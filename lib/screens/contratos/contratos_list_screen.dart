// lib/screens/contratos/contratos_list_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import 'contrato_form_screen.dart';
import '../recibos/recibo_form_screen.dart';

class ContratosListScreen extends StatefulWidget {
  const ContratosListScreen({super.key});

  @override
  State<ContratosListScreen> createState() => _ContratosListScreenState();
}

class _ContratosListScreenState extends State<ContratosListScreen> {
  final _db = DatabaseHelper();
  List<Map<String, dynamic>> _contratos = [];
  List<Map<String, dynamic>> _contratosFiltrados = [];
  bool _cargando = true;
  final _busquedaCtrl = TextEditingController();
  Timer? _autoRefresh;

  static const _magenta = Color(0xFFC2185B);
  static const _navy = Color(0xFF1A3A5C);

  @override
  void initState() {
    super.initState();
    _busquedaCtrl.addListener(_buscar);
    _cargar();
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
      final data = await _db.obtenerContratosActivos();
      if (mounted) {
        setState(() => _contratos = data);
        _buscar();
      }
    } catch (_) {}
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final raw = await _db.obtenerContratosActivos();
      // Convertir a mapas mutables y cargar garantes
      final data = raw.map((c) => Map<String, dynamic>.from(c)).toList();
      for (final c in data) {
        final cId = c['id'] as int?;
        if (cId != null) {
          final garantes = await _db.obtenerGarantesPorContrato(cId);
          c['_garantes'] = garantes;
        }
      }
      if (mounted) {
        setState(() {
          _contratos = data;
          _cargando = false;
        });
        _buscar();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar contratos: $e')),
        );
      }
    }
  }

  void _buscar() {
    final q = _busquedaCtrl.text.toLowerCase().trim();
    if (q.isEmpty) {
      setState(() => _contratosFiltrados = List.from(_contratos));
      return;
    }
    setState(() {
      _contratosFiltrados = _contratos.where((c) {
        final dir =
            (c['propiedad_direccion'] as String? ?? '').toLowerCase();
        final inq = (c['inquilino_nombre'] as String? ?? '').toLowerCase();
        final prop = (c['propietario_nombre'] as String? ?? '').toLowerCase();
        return dir.contains(q) || inq.contains(q) || prop.contains(q);
      }).toList();
    });
  }

  Future<void> _eliminar(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar contrato'),
        content: const Text(
          '¿Estás seguro de eliminar este contrato?\n\n'
          'Se eliminarán también todos sus períodos fijos asociados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC62828)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      try {
        await _db.eliminarContrato(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contrato eliminado'),
              backgroundColor: Color(0xFF2E7D32),
            ),
          );
          _cargar();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: const Color(0xFFC62828),
            ),
          );
        }
      }
    }
  }

  Future<void> _irAFormulario([Map<String, dynamic>? datos]) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ContratoFormScreen(datosExistentes: datos),
      ),
    );
    if (resultado == true) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contratos'),
        backgroundColor: _magenta,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _cargar,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            color: _magenta,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _busquedaCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText:
                    'Buscar por propiedad, inquilino o propietario...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.white70),
                suffixIcon: _busquedaCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            color: Colors.white70),
                        onPressed: () {
                          _busquedaCtrl.clear();
                          _buscar();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
            ),
          ),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _contratosFiltrados.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_outlined,
                          size: 72,
                          color: Colors.grey.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      const Text(
                        'No hay contratos registrados',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF9E9E9E),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Toca el botón + para agregar uno',
                        style: TextStyle(
                            fontSize: 13, color: Color(0xFFBDBDBD)),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.fromLTRB(0, 8, 0, 100),
                    itemCount: _contratosFiltrados.length,
                    itemBuilder: (context, i) =>
                        _tarjetaContrato(_contratosFiltrados[i]),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _magenta,
        foregroundColor: Colors.white,
        onPressed: () => _irAFormulario(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _tarjetaContrato(Map<String, dynamic> c) {
    final id = c['id'] as int;
    final direccion =
        c['propiedad_direccion'] as String? ?? 'Sin propiedad asignada';
    final inquilino = c['inquilino_nombre'] as String? ?? '';
    final inquilinoApellido = c['inquilino_apellido'] as String? ?? '';
    final inquilinoNombreCompleto = inquilinoApellido.isNotEmpty
        ? '$inquilino $inquilinoApellido'
        : inquilino.isNotEmpty
            ? inquilino
            : 'Sin inquilino';
    final propietario =
        c['propietario_nombre'] as String? ?? 'Sin propietario';
    final cuotasTotal = c['cuotas_total'] as int? ?? 0;
    final fechaInicio = c['fecha_inicio'] as String? ?? '';
    final fechaFin = c['fecha_fin'] as String? ?? '';
    final rescindido = (c['rescindido'] as int? ?? 0) == 1;
    final garantes = (c['_garantes'] as List<Map<String, dynamic>>?) ?? [];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _irAFormulario(c),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Leading icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _navy,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.description,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      direccion,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Subtitle rows
                    Text(
                      'LOCATARIO: $inquilinoNombreCompleto',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF757575)),
                    ),
                    Text(
                      'LOCADOR: $propietario',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF757575)),
                    ),
                    if (garantes.isNotEmpty)
                      Text(
                        'GARANTE${garantes.length > 1 ? 'S' : ''}: ${garantes.map((g) => g['nombre'] as String? ?? '').join(', ')}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF4E342E)),
                      ),
                    const SizedBox(height: 6),
                    // Chips row
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _chip(
                          '$cuotasTotal cuotas',
                          const Color(0xFF1565C0),
                        ),
                        if (fechaInicio.isNotEmpty || fechaFin.isNotEmpty)
                          _chip(
                            '${_fmtFecha(fechaInicio)} → ${_fmtFecha(fechaFin)}',
                            _navy,
                          ),
                        rescindido
                            ? _chip('RESCINDIDO', const Color(0xFFC62828))
                            : _chip('ACTIVO', const Color(0xFF2E7D32)),
                      ],
                    ),
                  ],
                ),
              ),
              // Trailing popup menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert,
                    color: Color(0xFF757575)),
                onSelected: (value) async {
                  if (value == 'editar') {
                    _irAFormulario(c);
                  } else if (value == 'recibo') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReciboFormScreen(
                          contratoIdInicial: id,
                        ),
                      ),
                    );
                  } else if (value == 'eliminar') {
                    _eliminar(id);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'editar',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined,
                            size: 18, color: Color(0xFF1565C0)),
                        SizedBox(width: 8),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'recibo',
                    child: Row(
                      children: [
                        Icon(Icons.receipt_outlined,
                            size: 18, color: Color(0xFF2E7D32)),
                        SizedBox(width: 8),
                        Text('Nuevo Recibo'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'eliminar',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline,
                            size: 18, color: Color(0xFFC62828)),
                        SizedBox(width: 8),
                        Text('Eliminar',
                            style: TextStyle(color: Color(0xFFC62828))),
                      ],
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

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  String _fmtFecha(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return iso;
    }
  }
}
