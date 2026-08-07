import 'package:flutter/material.dart';
import '../../../../core/estilos/tema.dart';

typedef CategoriasCallback = void Function(Set<String> seleccionados);

class SelectorCategorias extends StatelessWidget {
  final List<(String, List<String>)> categorias;
  final Set<String> seleccionados;
  final CategoriasCallback onCambio;
  final int? maxSeleccion;

  const SelectorCategorias({
    super.key,
    required this.categorias,
    required this.seleccionados,
    required this.onCambio,
    this.maxSeleccion,
  });

  @override
  Widget build(BuildContext context) {
    const primario = FlumiTema.colorPrimario;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final categoria in categorias) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                categoria.$1,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: primario,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categoria.$2.map((o) {
                final seleccionada = seleccionados.contains(o);
                final maximoAlcanzado = maxSeleccion != null &&
                    seleccionados.length >= maxSeleccion! &&
                    !seleccionada;
                return FilterChip(
                  label: Text(
                    o,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  selected: seleccionada,
                  onSelected: maximoAlcanzado
                      ? null
                      : (s) {
                          final nuevo = Set<String>.from(seleccionados);
                          if (s) {
                            nuevo.add(o);
                          } else {
                            nuevo.remove(o);
                          }
                          onCambio(nuevo);
                        },
                  selectedColor: primario.withValues(alpha: 0.15),
                  checkmarkColor: primario,
                  side: BorderSide(color: primario.withValues(alpha: 0.3)),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}