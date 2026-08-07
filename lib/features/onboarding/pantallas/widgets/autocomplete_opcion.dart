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
  @override
  Widget build(BuildContext context) {
    const primario = FlumiTema.colorPrimario;

    return Column(
      children: [
        TextFormField(
          controller: widget.controller,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: widget.hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primario.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primario, width: 1.5),
            ),
          ),
          onChanged: widget.onCambio,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 10,
              children: widget.sugerencias.map((p) {
                return GestureDetector(
                  onTap: () {
                    widget.controller.text = p;
                    widget.onCambio(p);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: primario.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: primario.withValues(alpha: 0.3)),
                    ),
                    child: Text(p, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}