import 'package:flutter/material.dart';

import '../../../../core/estilos/tema.dart';

typedef CampoPersonalizadoCallback = void Function(String texto);

class CampoPersonalizadoOpcion extends StatelessWidget {
  final TextEditingController controlador;
  final bool habilitado;
  final CampoPersonalizadoCallback onCambio;

  const CampoPersonalizadoOpcion({
    super.key,
    required this.controlador,
    required this.habilitado,
    required this.onCambio,
  });

  @override
  Widget build(BuildContext context) {
    const primario = FlumiTema.colorPrimario;
    return TextField(
      controller: controlador,
      enabled: habilitado,
      onChanged: onCambio,
      style: const TextStyle(color: Colors.black87, fontSize: 15),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey[100],
        labelText: '¿No encuentras la tuya? Escríbela aquí',
        labelStyle: const TextStyle(color: Colors.black45, fontSize: 13),
        prefixIcon:
            Icon(Icons.edit_outlined, color: primario.withValues(alpha: 0.7), size: 20),
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
          borderSide: const BorderSide(color: primario, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}