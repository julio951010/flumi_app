import 'package:flutter/material.dart';
import '../../../perfiles/perfil_etiquetas.dart';
import 'tarjeta_opcion_check.dart';

typedef OpcionSeleccionada = void Function(String valor);

class SelectorOpciones extends StatelessWidget {
  final String? valorActual;
  final List<OpcionEtiqueta> opciones;
  final OpcionSeleccionada onSeleccion;
  final bool permitirOtra;
  final bool dobleColumna;

  const SelectorOpciones({
    super.key,
    required this.valorActual,
    required this.opciones,
    required this.onSeleccion,
    this.permitirOtra = false,
    this.dobleColumna = false,
  });

  @override
  Widget build(BuildContext context) {
    final tarjetas = [
      for (final o in opciones)
        TarjetaOpcionCheck(
          etiqueta: o.$1,
          seleccionada: valorActual == o.$2,
          onTap: () => onSeleccion(o.$2),
        ),
    ];
    if (dobleColumna) {
      return SingleChildScrollView(child: RejillaCardsOpciones(tarjetas: tarjetas));
    }
    return SingleChildScrollView(
      child: Column(
        children: [
          for (final tarjeta in tarjetas) ...[
            tarjeta,
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}