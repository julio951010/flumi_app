import 'package:flutter/material.dart';
import '../../../perfiles/perfil_etiquetas.dart';
import 'tarjeta_opcion_check.dart';

typedef OpcionSeleccionada = void Function(String valor);

class SelectorOpcionesLayout extends StatelessWidget {
  final String? valorActual;
  final List<List<OpcionEtiqueta>> filas;
  final OpcionSeleccionada onSeleccion;

  const SelectorOpcionesLayout({
    super.key,
    required this.valorActual,
    required this.filas,
    required this.onSeleccion,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          for (final fila in filas) ...[
            if (fila.length == 1)
              TarjetaOpcionCheck(
                etiqueta: fila.first.$1,
                seleccionada: valorActual == fila.first.$2,
                onTap: () => onSeleccion(fila.first.$2),
              )
            else
              Row(
                children: [
                  for (final opcion in fila) ...[
                    if (opcion != fila.first) const SizedBox(width: 10),
                    Expanded(
                      child: TarjetaOpcionCheck(
                        etiqueta: opcion.$1,
                        seleccionada: valorActual == opcion.$2,
                        onTap: () => onSeleccion(opcion.$2),
                      ),
                    ),
                  ],
                ],
              ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}