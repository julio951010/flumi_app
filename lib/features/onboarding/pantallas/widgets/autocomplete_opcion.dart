import 'package:flutter/material.dart';
import '../../../../core/estilos/tema.dart';

typedef AutocompleteCallback = void Function(String valor);

class AutocompleteOpcion extends StatefulWidget {
  final TextEditingController controller;
  final List<String> sugerencias;
  final String hint;
  final AutocompleteCallback onCambio;

  const AutocompleteOpcion({
    super.key,
    required this.controller,
    required this.sugerencias,
    required this.hint,
    required this.onCambio,
  });

  @override
  State<AutocompleteOpcion> createState() => _AutocompleteOpcionState();
}

class _AutocompleteOpcionState extends State<AutocompleteOpcion> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    const primario = FlumiTema.colorPrimario;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue texto) {
            if (texto.text.trim().isEmpty) {
              return const Iterable<String>.empty();
            }
            final consulta = _normalizar(texto.text.trim().toLowerCase());
            return widget.sugerencias
                .where((opcion) => _normalizar(
                    opcion.toLowerCase()).contains(consulta));
          },
          displayStringForOption: (opcion) => opcion,
          fieldViewBuilder: (context, controladorTexto, focusNodeTexto,
              onFieldSubmitted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (controladorTexto.text.isEmpty &&
                  widget.controller.text.isNotEmpty) {
                controladorTexto.text = widget.controller.text;
              }
            });
            return TextField(
              controller: controladorTexto,
              focusNode: _focusNode,
              onChanged: (v) {
                widget.controller.text = v;
                widget.onCambio(v);
              },
              onSubmitted: (_) => onFieldSubmitted(),
              style: const TextStyle(color: Colors.black87, fontSize: 15),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[100],
                labelText: widget.hint,
                labelStyle:
                    const TextStyle(color: Colors.black45, fontSize: 14),
                prefixIcon: Icon(Icons.badge_outlined,
                    color: primario.withValues(alpha: 0.7), size: 20),
                suffixIcon:
                    Icon(Icons.arrow_drop_down, color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: primario.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: primario.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: primario, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, opciones) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: opciones.length,
                    itemBuilder: (context, index) {
                      final opcion = opciones.elementAt(index);
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.work_outline,
                          size: 20,
                          color: primario.withValues(alpha: 0.8),
                        ),
                        title: Text(opcion,
                            style: const TextStyle(fontSize: 14)),
                        onTap: () {
                          onSelected(opcion);
                          _focusNode.unfocus();
                        },
                      );
                    },
                  ),
                ),
              ),
            );
          },
          onSelected: (opcion) {
            widget.controller.text = opcion;
            widget.onCambio(opcion);
          },
        ),
      ],
    );
  }
}