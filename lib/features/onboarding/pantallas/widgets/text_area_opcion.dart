import 'package:flutter/material.dart';

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
    final primario = Theme.of(context).colorScheme.primary;

    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(
          color: Colors.black87, fontSize: 15, height: 1.4),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: colorFondo ?? Colors.grey[100],
        counterStyle:
            const TextStyle(fontSize: 12, color: Colors.black54),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primario.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primario.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black54, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      onChanged: onCambio,
    );
  }
}