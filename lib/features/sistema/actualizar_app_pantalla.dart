import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/estilos/tema.dart';
import '../../core/servicios/notificacion_servicio.dart';

/// Pantalla de actualización obligatoria: bloquea la app hasta instalar la
/// versión mínima exigida desde admin_flumi (`version_minima_build`).
class ActualizarAppPantalla extends StatelessWidget {
  final String mensaje;
  final String urlDescarga;

  const ActualizarAppPantalla({
    super.key,
    required this.mensaje,
    required this.urlDescarga,
  });

  Future<void> _descargar(BuildContext context) async {
    final uri = Uri.tryParse(urlDescarga);
    if (uri == null || urlDescarga.isEmpty) {
      NotificacionServicio.alerta(
          context, 'Enlace de descarga no disponible.');
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        NotificacionServicio.alerta(
            context, 'No se pudo abrir el enlace de descarga.');
      }
    } catch (_) {
      if (context.mounted) {
        NotificacionServicio.alerta(
            context, 'No se pudo abrir el enlace de descarga.');
      }
    }
  }

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
                  Icons.system_update_outlined,
                  size: 48,
                  color: FlumiTema.colorPrimario,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Actualiza Flumi',
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
                    : 'Hay una nueva versión de Flumi con mejoras importantes. Actualiza para seguir usándola.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _descargar(context),
                  icon: const Icon(Icons.download_outlined, size: 20),
                  label: const Text(
                    'Descargar actualización',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: FlumiTema.colorPrimario,
                    foregroundColor: Colors.white,
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
