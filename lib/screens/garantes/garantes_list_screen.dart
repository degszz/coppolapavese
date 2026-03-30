import 'dart:async';
import 'package:flutter/material.dart';
import '../../database/database_helper.dart';

class GarantesListScreen extends StatefulWidget {
  const GarantesListScreen({super.key});

  /// Abre el diálogo de creación de garante desde cualquier contexto.
  static Future<void> mostrarDialogNuevoGarante(BuildContext context) async {
    const magenta = Color(0xFFC2185B);
    const gray = Color(0xFF757575);
    final db = DatabaseHelper();

    final nombreCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String tipoGarantia = 'recibo_sueldo';

    final contratos = await db.obtenerContratosActivos();
    int? contratoId;

    if (!context.mounted) return;

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified_user,
                              color: magenta, size: 22),
                          const SizedBox(width: 8),
                          const Text(
                            'Nuevo garante',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: magenta),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: nombreCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nombre *',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Requerido'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: telefonoCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Teléfono',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: emailCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        value: contratoId,
                        decoration: const InputDecoration(
                          labelText: 'Contrato asociado',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('— Sin asignar —',
                                style: TextStyle(color: Colors.grey)),
                          ),
                          ...contratos.map((c) {
                            final dir = c['propiedad_direccion'] as String? ??
                                'Sin propiedad';
                            final inq = c['inquilino_nombre'] as String? ?? '';
                            return DropdownMenuItem<int?>(
                              value: c['id'] as int,
                              child: Text(
                                '$dir${inq.isNotEmpty ? ' — $inq' : ''}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }),
                        ],
                        onChanged: (v) => setS(() => contratoId = v),
                        validator: (v) =>
                            v == null ? 'Seleccioná un contrato' : null,
                      ),
                      const SizedBox(height: 12),
                      const Text('Tipo de garantía:',
                          style: TextStyle(fontSize: 12, color: gray)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Recibo de sueldo',
                                  style: TextStyle(fontSize: 12)),
                              value: 'recibo_sueldo',
                              groupValue: tipoGarantia,
                              onChanged: (v) =>
                                  setS(() => tipoGarantia = v!),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Garantía propietaria',
                                  style: TextStyle(fontSize: 12)),
                              value: 'garante_propietario',
                              groupValue: tipoGarantia,
                              onChanged: (v) =>
                                  setS(() => tipoGarantia = v!),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            icon: const Icon(Icons.save, size: 16),
                            label: const Text('Crear garante'),
                            style: FilledButton.styleFrom(
                                backgroundColor: magenta),
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              final dbI = await db.database;
                              final data = {
                                'contrato_id': contratoId,
                                'nombre': nombreCtrl.text.trim(),
                                'telefono': telefonoCtrl.text.trim().isEmpty
                                    ? null
                                    : telefonoCtrl.text.trim(),
                                'email': emailCtrl.text.trim().isEmpty
                                    ? null
                                    : emailCtrl.text.trim(),
                                'tipo_garantia': tipoGarantia,
                              };
                              await dbI.insert('garantes', data);
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<GarantesListScreen> createState() => _GarantesListScreenState();
}

class _GarantesListScreenState extends State<GarantesListScreen> {
  static const _magenta = Color(0xFFC2185B);
  static const _dark = Color(0xFF212121);
  static const _gray = Color(0xFF757575);

  final _db = DatabaseHelper();
  List<Map<String, dynamic>> _garantes = [];
  List<Map<String, dynamic>> _filtrados = [];
  bool _cargando = true;
  final _busquedaCtrl = TextEditingController();
  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
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
      final data = await _db.obtenerGarantesConDetalle();
      if (mounted) {
        setState(() {
          _garantes = data;
          _filtrar();
        });
      }
    } catch (_) {}
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final data = await _db.obtenerGarantesConDetalle();
      setState(() {
        _garantes = data;
        _filtrados = data;
        _cargando = false;
      });
    } catch (e) {
      setState(() => _cargando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar garantes: $e')),
        );
      }
    }
  }

  void _filtrar() {
    final q = _busquedaCtrl.text.toLowerCase();
    setState(() {
      _filtrados = _garantes.where((g) {
        final nombre = (g['nombre'] as String? ?? '').toLowerCase();
        final propietario =
            (g['propietario_nombre'] as String? ?? '').toLowerCase();
        final inquilino =
            (g['inquilino_nombre'] as String? ?? '').toLowerCase();
        return nombre.contains(q) ||
            propietario.contains(q) ||
            inquilino.contains(q);
      }).toList();
    });
  }

  Future<void> _nuevo() async {
    await _mostrarDialog(null);
  }

  Future<void> _editar(Map<String, dynamic> datos) async {
    await _mostrarDialog(datos);
  }

  Future<void> _eliminar(int id, String nombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar garante'),
        content:
            Text('Se eliminará a "$nombre". Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      final db = await _db.database;
      await db.delete('garantes', where: 'id = ?', whereArgs: [id]);
      _cargar();
    }
  }

  Future<void> _mostrarDialog(Map<String, dynamic>? datos) async {
    final esEdicion = datos != null;
    final nombreCtrl =
        TextEditingController(text: datos?['nombre'] as String? ?? '');
    final telefonoCtrl =
        TextEditingController(text: datos?['telefono'] as String? ?? '');
    final emailCtrl =
        TextEditingController(text: datos?['email'] as String? ?? '');
    String tipoGarantia =
        datos?['tipo_garantia'] as String? ?? 'recibo_sueldo';

    // Cargar contratos para asociar
    final contratos = await _db.obtenerContratosActivos();
    int? contratoId = datos?['contrato_id'] as int?;

    if (!mounted) return;

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified_user,
                              color: _magenta, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            esEdicion ? 'Editar garante' : 'Nuevo garante',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _magenta),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: nombreCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nombre *',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Requerido'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: telefonoCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Teléfono',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: emailCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        value: contratoId,
                        decoration: const InputDecoration(
                          labelText: 'Contrato asociado',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('— Sin asignar —',
                                style: TextStyle(color: Colors.grey)),
                          ),
                          ...contratos.map((c) {
                            final dir = c['propiedad_direccion'] as String? ??
                                'Sin propiedad';
                            final inq = c['inquilino_nombre'] as String? ?? '';
                            return DropdownMenuItem<int?>(
                              value: c['id'] as int,
                              child: Text(
                                '$dir${inq.isNotEmpty ? ' — $inq' : ''}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }),
                        ],
                        onChanged: (v) => setS(() => contratoId = v),
                        validator: (v) =>
                            v == null ? 'Seleccioná un contrato' : null,
                      ),
                      const SizedBox(height: 12),
                      const Text('Tipo de garantía:',
                          style: TextStyle(fontSize: 12, color: _gray)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Recibo de sueldo',
                                  style: TextStyle(fontSize: 12)),
                              value: 'recibo_sueldo',
                              groupValue: tipoGarantia,
                              onChanged: (v) =>
                                  setS(() => tipoGarantia = v!),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Garantía propietaria',
                                  style: TextStyle(fontSize: 12)),
                              value: 'garante_propietario',
                              groupValue: tipoGarantia,
                              onChanged: (v) =>
                                  setS(() => tipoGarantia = v!),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            icon: const Icon(Icons.save, size: 16),
                            label: Text(
                                esEdicion ? 'Guardar' : 'Crear garante'),
                            style: FilledButton.styleFrom(
                                backgroundColor: _magenta),
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              final db = await _db.database;
                              final data = {
                                'contrato_id': contratoId,
                                'nombre': nombreCtrl.text.trim(),
                                'telefono': telefonoCtrl.text.trim().isEmpty
                                    ? null
                                    : telefonoCtrl.text.trim(),
                                'email': emailCtrl.text.trim().isEmpty
                                    ? null
                                    : emailCtrl.text.trim(),
                                'tipo_garantia': tipoGarantia,
                              };
                              if (esEdicion) {
                                await db.update('garantes', data,
                                    where: 'id = ?',
                                    whereArgs: [datos['id']]);
                              } else {
                                await db.insert('garantes', data);
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                              _cargar();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Garantes',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: _dark,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE0E0E0)),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevo,
        backgroundColor: _magenta,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo Garante'),
      ),
      body: Column(
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _busquedaCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, propietario o inquilino...',
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          // Lista
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _filtrados.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_user_outlined,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              _garantes.isEmpty
                                  ? 'No hay garantes registrados'
                                  : 'Sin resultados',
                              style: const TextStyle(color: _gray),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        itemCount: _filtrados.length,
                        itemBuilder: (_, i) => _tarjeta(_filtrados[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta(Map<String, dynamic> g) {
    final nombre = g['nombre'] as String? ?? '—';
    final telefono = g['telefono'] as String? ?? '';
    final email = g['email'] as String? ?? '';
    final tipo = g['tipo_garantia'] as String? ?? 'recibo_sueldo';
    final propietario = g['propietario_nombre'] as String? ?? '';
    final inquilino = g['inquilino_nombre'] as String? ?? '';
    final direccion = g['propiedad_direccion'] as String? ?? '';
    final id = g['id'] as int;

    final tipoLabel = tipo == 'garante_propietario'
        ? 'Garantía propietaria'
        : 'Recibo de sueldo';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _magenta.withValues(alpha: 0.1),
                  child: const Icon(Icons.verified_user,
                      size: 18, color: _magenta),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _dark)),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: tipo == 'garante_propietario'
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(tipoLabel,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: tipo == 'garante_propietario'
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFE65100))),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'editar') _editar(g);
                    if (action == 'eliminar') _eliminar(id, nombre);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'editar',
                      child: Row(children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Editar'),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'eliminar',
                      child: Row(children: [
                        Icon(Icons.delete_outline,
                            size: 18, color: Color(0xFFC62828)),
                        SizedBox(width: 8),
                        Text('Eliminar',
                            style: TextStyle(color: Color(0xFFC62828))),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Info contacto
            if (telefono.isNotEmpty || email.isNotEmpty)
              Wrap(
                spacing: 16,
                children: [
                  if (telefono.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone, size: 13, color: _gray),
                        const SizedBox(width: 4),
                        Text(telefono,
                            style:
                                const TextStyle(fontSize: 12, color: _gray)),
                      ],
                    ),
                  if (email.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.email, size: 13, color: _gray),
                        const SizedBox(width: 4),
                        Text(email,
                            style:
                                const TextStyle(fontSize: 12, color: _gray)),
                      ],
                    ),
                ],
              ),
            if (direccion.isNotEmpty || propietario.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 16,
                children: [
                  if (propietario.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person, size: 13, color: _gray),
                        const SizedBox(width: 4),
                        Text('Prop: $propietario',
                            style:
                                const TextStyle(fontSize: 11, color: _gray)),
                      ],
                    ),
                  if (inquilino.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_search,
                            size: 13, color: _gray),
                        const SizedBox(width: 4),
                        Text('Inq: $inquilino',
                            style:
                                const TextStyle(fontSize: 11, color: _gray)),
                      ],
                    ),
                  if (direccion.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.home, size: 13, color: _gray),
                        const SizedBox(width: 4),
                        Text(direccion,
                            style:
                                const TextStyle(fontSize: 11, color: _gray)),
                      ],
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
