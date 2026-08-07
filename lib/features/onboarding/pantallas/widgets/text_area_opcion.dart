import 'package:flutter/material.dart';
import '../../../../core/estilos/tema.dart';

typedef TextoCallback = void Function(String texto);

class TextAreaOpcion extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final int? maxLength;
  final TextoCallback onCambio;
  final Color? colorFondo;

  const TextAreaOpcion({
    super.key,
    required this.controller,
    required this.hint,
    required this.onCambio,
    this.maxLines = 5,
    this.maxLength,
    this.colorFondo,
  });

  @override
  Widget build(BuildContext context) {
    const primario = FlumiTema.colorPrimario;

    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: colorFondo ?? primario.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primario.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primario, width: 1.5),
        ),
      ),
      onChanged: onCambio,
    );
  }
}