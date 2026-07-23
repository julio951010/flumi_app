import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../core/base_datos_local/database.dart';
import '../perfil_repositorio.dart';

class EditarPerfilPantalla extends StatefulWidget {
  final Usuario perfil;
  final PerfilRepositorio repositorio;

  const EditarPerfilPantalla({
    super.key,
    required this.perfil,
    required this.repositorio,
  });

  @override
  State<EditarPerfilPantalla> createState() => _EditarPerfilPantallaState();
}

class _EditarPerfilPantallaState extends State<EditarPerfilPantalla> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _bioCtrl;
  late final _formKey = GlobalKey<FormState>();

  late String _genero;
  late String _buscaGenero;
  late int _edadMin;
  late int _edadMax;

  bool _cargando = false;

  static const _opcionesGenero = ['hombre', 'mujer', 'otro'];
  static const _opcionesBusca = ['hombre', 'mujer', 'ambos', 'otro'];

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.perfil.nombre);
    _bioCtrl = TextEditingController(text: widget.perfil.biografia);
    _genero = widget.perfil.genero;
    _buscaGenero = widget.perfil.buscaGenero;
    _edadMin = widget.perfil.preferenciaEdadMin;
    _edadMax = widget.perfil.preferenciaEdadMax;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);

    try {
      await widget.repositorio.guardarOCambiarPerfil(
        UsuariosCompanion(
          uuid: Value(widget.perfil.uuid),
          nombre: Value(_nombreCtrl.text.trim()),
          biografia: Value(_bioCtrl.text.trim()),
          genero: Value(_genero),
          buscaGenero: Value(_buscaGenero),
          preferenciaEdadMin: Value(_edadMin),
          preferenciaEdadMax: Value(_edadMax),
          pendienteDeSincronizar: const Value(true),
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        actions: [
          TextButton(
            onPressed: _cargando ? null : _guardar,
            child: _cargando
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Guardar', style: TextStyle(color: primario, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _campoTexto(
                label: 'Nombre',
                controlador: _nombreCtrl,
                validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              _campoTexto(
                label: 'Biografía',
                controlador: _bioCtrl,
                maxLines: 4,
              ),
              const SizedBox(height: 20),
              Text('Género', style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _selector(_opcionesGenero, _genero, (v) => setState(() => _genero = v!)),
              const SizedBox(height: 20),
              Text('Busca', style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _selector(_opcionesBusca, _buscaGenero, (v) => setState(() => _buscaGenero = v!)),
              const SizedBox(height: 24),
              Text('Preferencia de edad', style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              RangeSlider(
                values: RangeValues(_edadMin.toDouble(), _edadMax.toDouble()),
                min: 18,
                max: 99,
                divisions: 81,
                labels: RangeLabels('$_edadMin', '$_edadMax'),
                activeColor: primario,
                onChanged: (v) => setState(() {
                  _edadMin = v.start.round();
                  _edadMax = v.end.round();
                }),
              ),
              Center(
                child: Text('$_edadMin - $_edadMax años', style: TextStyle(color: primario, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _campoTexto({
    required String label,
    required TextEditingController controlador,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controlador,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _selector(List<String> opciones, String seleccion, ValueChanged<String?> onChanged) {
    final primario = Theme.of(context).colorScheme.primary;
    return SegmentedButton<String>(
      segments: opciones.map((o) => ButtonSegment(value: o, label: Text(o[0].toUpperCase() + o.substring(1)))).toList(),
      selected: {seleccion},
      onSelectionChanged: (s) => onChanged(s.first),
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: primario.withOpacity(0.15),
        selectedForegroundColor: primario,
        foregroundColor: Colors.grey[700],
      ),
    );
  }
}
