import 'package:flutter/material.dart';
import '../../../perfiles/perfil_etiquetas.dart';
import 'tarjeta_opcion_check.dart';

typedef OpcionSeleccionada = void Function(String valor);

class SelectorOpciones extends StatelessWidget {
  final String? valorActual;
  final List<OpcionEtiqueta> opciones;
  final OpcionSeleccionada onSeleccion;
  final bool permitirOtra;

  const SelectorOpciones({
    super.key,
    required this.valorActual,
    required this.opciones,
    required this.onSeleccion,
    this.permitirOtra = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: RejillaCardsOpciones(
        tarjetas: [
          for (final o in opciones)
            TarjetaOpcionCheck(
              etiqueta: o.$1,
              seleccionada: valorActual == o.$2,
              onTap: () => onSeleccion(o.$2),
            ),
        ],
      ),
    );
  }
}