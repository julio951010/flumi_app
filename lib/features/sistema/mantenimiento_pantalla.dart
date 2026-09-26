import 'package:flutter/material.dart';

import '../../core/estilos/tema.dart';

/// Pantalla de mantenimiento: la app no puede usarse mientras esté activa.
/// Se muestra/oculta en vivo desde admin_flumi (flag `mantenimiento`).
class MantenimientoPantalla extends StatelessWidget {
  final String mensaje;
  final VoidCallback? onReintentar;

  const MantenimientoPantalla({
    super.key,
    required this.mensaje,
    this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: FlumiTema.colorPrimario.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.build_outlined,
                  size: 48,
                  color: FlumiTema.colorPrimario,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'En mantenimiento',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                mensaje.isNotEmpty
                    ? mensaje
                    : 'Estamos mejorando Flumi para ti. Vuelve en unos minutos.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              const Spacer(),
              if (onReintentar != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onReintentar,
                    icon: const Icon(Icons.refresh, size: 20),
                    label: const Text(
                      'Reintentar',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FlumiTema.colorPrimario,
                      side: BorderSide(color: FlumiTema.colorPrimario),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
