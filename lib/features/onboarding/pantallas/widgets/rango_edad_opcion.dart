import 'package:flutter/material.dart';

typedef RangoEdadCallback = void Function(RangeValues rango);

class RangoEdadOpcion extends StatelessWidget {
  final RangeValues rango;
  final int minimo;
  final int maximo;
  final bool deshabilitado;
  final RangoEdadCallback onCambio;

  const RangoEdadOpcion({
    super.key,
    required this.rango,
    required this.minimo,
    required this.maximo,
    required this.deshabilitado,
    required this.onCambio,
  });

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: primario.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primario.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${rango.start.round()} años',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'a',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  Text(
                    '${rango.end.round()} años',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              RangeSlider(
                values: rango,
                min: minimo.toDouble(),
                max: maximo.toDouble(),
                divisions: maximo - minimo,
                activeColor: primario,
                inactiveColor: primario.withValues(alpha: 0.2),
                labels: RangeLabels(
                  '${rango.start.round()}',
                  '${rango.end.round()}',
                ),
                onChanged: deshabilitado ? null : onCambio,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Ajusta ambos extremos para definir el rango de edad con el que te sientes cómodo/a.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ],
    );
  }
}