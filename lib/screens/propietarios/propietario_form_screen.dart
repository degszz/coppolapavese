import 'package:flutter/material.dart';
import '../../database/database_helper.dart';

class PropietarioFormScreen extends StatefulWidget {
  final Map<String, dynamic>? datosExistentes;

  const PropietarioFormScreen({super.key, this.datosExistentes});

  @override
  State<PropietarioFormScreen> createState() => _PropietarioFormScreenState();
}

class _PropietarioFormScreenState extends State<PropietarioFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper();
  bool _guardando = false;
  bool get _esEdicion => widget.datosExistentes != null;

  // ── Propietario ────────────────────────────────────────────────
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // ── Inquilino ─────────────────────────────────────────────────
  final _nombreInquilinoCtrl = TextEditingController();
  final _telefonoInquilinoCtrl = TextEditingController();

  // ── Domicilio ─────────────────────────────────────────────────
  final _direccionCtrl = TextEditingController();
  final _localidadCtrl = TextEditingController();

  // IDs existentes (solo en edición)
  int? _inquilinoId;
  int? _domicilioId;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) _cargarDatosExistentes();
  }

  Future<void> _cargarDatosExistentes() async {
    final datos = widget.datosExistentes!;
    final propietarioId = datos['id'] as int?;

    _nombreCtrl.text = datos['propietario_nombre'] as String? ?? '';
    _telefonoCtrl.text = datos['propietario_telefono'] as String? ?? '';
    _emailCtrl.text = datos['propietario_email'] as String? ?? '';
    _nombreInquilinoCtrl.text = datos['inquilino_nombre'] as String? ?? '';
    _direccionCtrl.text = datos['direccion'] as String? ?? '';
    _localidadCtrl.text = datos['localidad'] as String? ?? '';

    // Cargar teléfono del inquilino desde BD
    if (propietarioId != null) {
      final inquilinos =
          await _db.obtenerInquilinosPorPropietario(propietarioId);
      if (inquilinos.isNotEmpty) {
        _inquilinoId = inquilinos.first['id'] as int?;
        _telefonoInquilinoCtrl.text =
            inquilinos.first['telefono'] as String? ?? '';
      }

      final domicilios =
          await _db.obtenerDomiciliosPorPropietario(propietarioId);
      if (domicilios.isNotEmpty) {
        _domicilioId = domicilios.first['id'] as int?;
      }
    }

    setState(() {});
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _nombreInquilinoCtrl.dispose();
    _telefonoInquilinoCtrl.dispose();
    _direccionCtrl.dispose();
    _localidadCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    try {
      if (_esEdicion) {
        await _actualizar();
      } else {
        await _insertar();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_esEdicion
                ? 'Propietario actualizado correctamente'
                : 'Propietario registrado correctamente'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _insertar() async {
    // 1. Insertar propietario
    final propietarioId = await _db.insertarPropietario({
      'nombre': _nombreCtrl.text.trim(),
      'telefono': _telefonoCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
    });

    // 2. Insertar inquilino (si se completó el nombre)
    int? inquilinoId;
    if (_nombreInquilinoCtrl.text.trim().isNotEmpty) {
      inquilinoId = await _db.insertarInquilino({
        'nombre': _nombreInquilinoCtrl.text.trim(),
        'telefono': _telefonoInquilinoCtrl.text.trim(),
        'propietario_id': propietarioId,
      });
    }

    // 3. Insertar domicilio (si se completó la dirección)
    if (_direccionCtrl.text.trim().isNotEmpty) {
      await _db.insertarDomicilio({
        'direccion': _direccionCtrl.text.trim(),
        'localidad': _localidadCtrl.text.trim(),
        'propietario_id': propietarioId,
        'inquilino_id': inquilinoId,
      });
    }
  }

  Future<void> _actualizar() async {
    final propietarioId = widget.datosExistentes!['id'] as int;

    // 1. Actualizar propietario
    await _db.actualizarPropietario(propietarioId, {
      'nombre': _nombreCtrl.text.trim(),
      'telefono': _telefonoCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
    });

    // 2. Actualizar / insertar inquilino
    if (_nombreInquilinoCtrl.text.trim().isNotEmpty) {
      final datosInquilino = {
        'nombre': _nombreInquilinoCtrl.text.trim(),
        'telefono': _telefonoInquilinoCtrl.text.trim(),
        'propietario_id': propietarioId,
      };
      if (_inquilinoId != null) {
        await _db.actualizarInquilino(_inquilinoId!, datosInquilino);
      } else {
        _inquilinoId = await _db.insertarInquilino(datosInquilino);
      }
    }

    // 3. Actualizar / insertar domicilio
    if (_direccionCtrl.text.trim().isNotEmpty) {
      final datosDomicilio = {
        'direccion': _direccionCtrl.text.trim(),
        'localidad': _localidadCtrl.text.trim(),
        'propietario_id': propietarioId,
        'inquilino_id': _inquilinoId,
      };
      if (_domicilioId != null) {
        await _db.actualizarDomicilio(_domicilioId!, datosDomicilio);
      } else {
        await _db.insertarDomicilio(datosDomicilio);
      }
    }
  }

  Future<void> _confirmarEliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar propietario'),
        content: const Text(
          '¿Estás seguro de eliminar este propietario?\n\n'
          'Se eliminarán también todos sus inquilinos, domicilios y recibos asociados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC62828)),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      try {
        final propietarioId = widget.datosExistentes!['id'] as int;
        await _db.eliminarPropietario(propietarioId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Propietario eliminado'),
              backgroundColor: Color(0xFF2E7D32),
            ),
          );
          Navigator.pop(context, true);
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

  Future<void> _confirmarEliminarInquilino() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar inquilino'),
        content: const Text(
          '¿Estás seguro de eliminar este inquilino?\n\n'
          'Se eliminarán también sus recibos y datos asociados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC62828)),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      try {
        await _db.eliminarInquilino(_inquilinoId!);
        setState(() {
          _inquilinoId = null;
          _nombreInquilinoCtrl.clear();
          _telefonoInquilinoCtrl.clear();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Inquilino eliminado'),
              backgroundColor: Color(0xFF2E7D32),
            ),
          );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(_esEdicion ? 'Editar Propietario' : 'Nuevo Propietario'),
        actions: [
          if (_esEdicion)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar',
              onPressed: _confirmarEliminar,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _seccion(
              titulo: 'Datos del Propietario',
              icono: Icons.person,
              children: [
                _campo(
                  controller: _nombreCtrl,
                  label: 'Nombre completo *',
                  icono: Icons.badge_outlined,
                  validar: (v) =>
                      v == null || v.trim().isEmpty ? 'El nombre es obligatorio' : null,
                ),
                const SizedBox(height: 12),
                _campo(
                  controller: _telefonoCtrl,
                  label: 'Teléfono',
                  icono: Icons.phone_outlined,
                  teclado: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                _campo(
                  controller: _emailCtrl,
                  label: 'Email',
                  icono: Icons.email_outlined,
                  teclado: TextInputType.emailAddress,
                  validar: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final re = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w]{2,4}$');
                    return re.hasMatch(v.trim()) ? null : 'Email inválido';
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _seccion(
              titulo: 'Datos del Inquilino',
              icono: Icons.people,
              children: [
                _campo(
                  controller: _nombreInquilinoCtrl,
                  label: 'Nombre del inquilino',
                  icono: Icons.person_outline,
                ),
                const SizedBox(height: 12),
                _campo(
                  controller: _telefonoInquilinoCtrl,
                  label: 'Teléfono del inquilino',
                  icono: Icons.phone_outlined,
                  teclado: TextInputType.phone,
                ),
                if (_esEdicion && _inquilinoId != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Eliminar inquilino'),
                      style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFC62828)),
                      onPressed: _confirmarEliminarInquilino,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            _seccion(
              titulo: 'Domicilio del Alquiler',
              icono: Icons.home,
              children: [
                _campo(
                  controller: _direccionCtrl,
                  label: 'Dirección',
                  icono: Icons.location_on_outlined,
                ),
                const SizedBox(height: 12),
                _campo(
                  controller: _localidadCtrl,
                  label: 'Localidad / Ciudad',
                  icono: Icons.location_city_outlined,
                ),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(_esEdicion ? Icons.save : Icons.add),
                label: Text(
                  _guardando
                      ? 'Guardando...'
                      : _esEdicion
                          ? 'Guardar Cambios'
                          : 'Registrar Propietario',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _seccion({
    required String titulo,
    required IconData icono,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, size: 18, color: const Color(0xFFC2185B)),
                const SizedBox(width: 8),
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC2185B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _campo({
    required TextEditingController controller,
    required String label,
    required IconData icono,
    TextInputType teclado = TextInputType.text,
    String? Function(String?)? validar,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: teclado,
      validator: validar,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icono, size: 20),
      ),
    );
  }
}
