import 'package:flutter/material.dart';
import '../core/estilos/tema.dart';

/// Estado vacío del feed: nada que mostrar. Ofrece "Ampliar búsqueda"
/// (quita distancia/edad y pide más perfiles al servidor) y "Recargar".
class EstadoVacioEncuentros extends StatelessWidget {
  final String mensaje;
  final IconData icono;
  final Future<void> Function()? onAmpliarBusqueda;
  final Future<void> Function()? onRecargar;

  const EstadoVacioEncuentros({
    super.key,
    required this.mensaje,
    this.icono = Icons.person_search,
    this.onAmpliarBusqueda,
    this.onRecargar,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          if (onAmpliarBusqueda != null) ...[
            ElevatedButton.icon(
              onPressed: onAmpliarBusqueda,
              icon: const Icon(Icons.expand_circle_down_outlined),
              label: const Text('Ampliar b\u00fasqueda'),
              style: ElevatedButton.styleFrom(
                backgroundColor: FlumiTema.colorPrimario,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
                minimumSize: const Size(220, 48),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (onRecargar != null)
            TextButton(
              onPressed: onRecargar,
              child: const Text('Recargar'),
            ),
        ],
      ),
    );
  }
}