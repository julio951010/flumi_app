import 'package:flutter/material.dart';
import '../../../../core/estilos/tema.dart';

typedef MultiOpcionesCallback = void Function(Set<String> seleccionados);

class SelectorMultiOpciones extends StatefulWidget {
  final Set<String> seleccionados;
  final List<String> opciones;
  final MultiOpcionesCallback onCambio;
  final bool permitirOtra;
  final ValueChanged<String>? onAgregarOtra;

  const SelectorMultiOpciones({
    super.key,
    required this.seleccionados,
    required this.opciones,
    required this.onCambio,
    this.permitirOtra = false,
    this.onAgregarOtra,
  });

  @override
  State<SelectorMultiOpciones> createState() => _SelectorMultiOpcionesState();
}

class _SelectorMultiOpcionesState extends State<SelectorMultiOpciones> {
  final _textoCtrl = TextEditingController();
  final _focusNode = FocusNode();
  String _consulta = '';
  bool _campoFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) {
        setState(() => _campoFocused = _focusNode.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _textoCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _normalizar(String valor) {
    return valor
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
  }

  List<String> _sugerencias() {
    if (_consulta.trim().isEmpty) return const [];
    final consulta = _normalizar(_consulta.trim().toLowerCase());
    return widget.opciones
        .where((opcion) =>
            _normalizar(opcion.toLowerCase()).contains(consulta))
        .toList();
  }

  double _anchoCampo() {
    final cadena = _consulta.isEmpty ? 'Escribe un idioma...' : _consulta;
    final estimado = cadena.length * 8.0 + 20;
    if (_textoCtrl.text.isEmpty) return estimado.clamp(150.0, 260.0);
    return 150.0;
  }

  Widget _tagIdioma(String idioma, Color primario) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: primario.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            idioma,
            style: TextStyle(
                fontSize: 13, color: primario, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              final nuevo = Set<String>.from(widget.seleccionados)
                ..remove(idioma);
              widget.onCambio(nuevo);
            },
            child: Icon(Icons.close, size: 16, color: primario),
          ),
        ],
      ),
    );
  }

  void _agregar(String valor) {
    final p = valor.trim();
    if (p.isEmpty) return;
    final nuevo = Set<String>.from(widget.seleccionados)..add(p);
    _textoCtrl.clear();
    _consulta = '';
    if (widget.onAgregarOtra != null) {
      widget.onAgregarOtra!(p);
    }
    widget.onCambio(nuevo);
  }

  @override
  Widget build(BuildContext context) {
    const primario = FlumiTema.colorPrimario;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _campoFocused
                    ? primario
                    : primario.withValues(alpha: 0.3),
                width: _campoFocused ? 1.5 : 1,
              ),
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final idioma in widget.seleccionados)
                  _tagIdioma(idioma, primario),
                SizedBox(
                  width: _anchoCampo(),
                  child: TextField(
                    controller: _textoCtrl,
                    focusNode: _focusNode,
                    onChanged: (v) {
                      setState(() => _consulta = v);
                    },
                    onSubmitted: _agregar,
                    style: const TextStyle(
                        color: Colors.black87, fontSize: 15),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Escribe un idioma...',
                      hintStyle:
                          TextStyle(color: Colors.black38, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_campoFocused && _consulta.trim().isNotEmpty &&
              _sugerencias().isNotEmpty) ...[
            const SizedBox(height: 8),
            Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _sugerencias().length,
                  itemBuilder: (context, index) {
                    final sugerencia = _sugerencias()[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.language,
                        size: 20,
                        color: primario.withValues(alpha: 0.8),
                      ),
                      title: Text(sugerencia,
                          style: const TextStyle(fontSize: 14)),
                      onTap: () {
                        _agregar(sugerencia);
                        _focusNode.requestFocus();
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}