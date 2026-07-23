import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/base_datos_local/database.dart';
import '../perfil_repositorio.dart';

class EditarPerfilPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;
  final Usuario? perfilExistente;

  const EditarPerfilPantalla({
    super.key,
    required this.repositorio,
    this.perfilExistente,
  });

  @override
  State<EditarPerfilPantalla> createState() => _EditarPerfilPantallaState();
}

class _EditarPerfilPantallaState extends State<EditarPerfilPantalla> {
  final _nombreCtrl = TextEditingController();
  final _edadCtrl = TextEditingController();
  final _biografiaCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    if (widget.perfilExistente != null) {
      _nombreCtrl.text = widget.perfilExistente!.nombre;
      _edadCtrl.text = widget.perfilExistente!.edad.toString();
      _biografiaCtrl.text = widget.perfilExistente!.biografia;
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);

    final uuid = widget.perfilExistente?.uuid ?? const Uuid().v4();

    await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion.insert(
      uuid: uuid,
      nombre: _nombreCtrl.text.trim(),
      edad: int.parse(_edadCtrl.text.trim()),
      genero: widget.perfilExistente?.genero ?? 'otro',
      buscaGenero: widget.perfilExistente?.buscaGenero ?? 'otro',
      esPerfilPropio: const Value(true),
      pendienteDeSincronizar: const Value(true),
    ));

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _edadCtrl.dispose();
    _biografiaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar Perfil')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _edadCtrl,
                decoration: const InputDecoration(labelText: 'Edad'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requerido';
                  final edad = int.tryParse(v);
                  if (edad == null || edad < 18) return 'Debes ser mayor de 18';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _biografiaCtrl,
                decoration: const InputDecoration(labelText: 'Biografía'),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _cargando ? null : _guardar,
                child: _cargando
                    ? const CircularProgressIndicator()
                    : const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
