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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    _etiquetaEdad(rango.start.round(), primario),
                    const Text(
                      'a',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    _etiquetaEdad(rango.end.round(), primario),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$minimo',
                      style:
                          TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    Text(
                      '$maximo',
                      style:
                          TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _etiquetaEdad(int edad, Color primario) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: primario,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$edad',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}