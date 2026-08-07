import 'package:flutter/material.dart';
import 'tarjeta_opcion_check.dart';

typedef MultiOpcionesCallback = void Function(Set<String> seleccionados);

class SelectorMultiOpciones extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: RejillaCardsOpciones(
        tarjetas: [
          for (final o in opciones)
            TarjetaOpcionCheck(
              etiqueta: o,
              seleccionada: seleccionados.contains(o),
              onTap: () {
                final nuevo = Set<String>.from(seleccionados);
                if (nuevo.contains(o)) {
                  nuevo.remove(o);
                } else {
                  nuevo.add(o);
                }
                onCambio(nuevo);
              },
            ),
        ],
      ),
    );
  }
}