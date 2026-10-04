import 'package:flutter/material.dart';

import '../core/estilos/tema.dart';
import '../core/servicios/connectivity_service.dart';
import '../core/servicios/notificacion_servicio.dart';

/// Pantalla a pantalla completa para problemas de conexión. Dos modos:
/// - sin red (no hay interfaz): título/mensaje/icono por defecto.
/// - servidor inalcanzable (hay red pero Supabase no responde: caído,
///   lento o DNS bloqueado): se pasa título/mensaje/icono propios y el
///   reintento sondea al servidor en vez de la interfaz de red.
/// Ofrece un botón para reintentar y, si se reconecta, el contenedor que
/// la muestra (p. ej. [IndicadorConexion]) vuelve a renderizar la app.
class SinConexionPantalla extends StatefulWidget {
  final VoidCallback? onReintentar;
  final bool mostrarBotonReintentar;
  final String titulo;
  final String mensaje;
  final IconData icono;
  final Future<bool> Function()? comprobarServidor;

  const SinConexionPantalla({
    super.key,
    this.onReintentar,
    this.mostrarBotonReintentar = true,
    this.titulo = 'Sin conexión',
    this.mensaje =
        'No pudimos conectar con Flumi. Revisa tu Wi-Fi o datos móviles '
        'y vuelve a intentarlo.',
    this.icono = Icons.wifi_off_rounded,
    this.comprobarServidor,
  });

  @override
  State<SinConexionPantalla> createState() => _SinConexionPantallaState();
}

class _SinConexionPantallaState extends State<SinConexionPantalla> {
  bool _verificando = false;

  Future<void> _reintentar() async {
    setState(() => _verificando = true);
    try {
      // Si hay comprobador de servidor, lo usamos (modo servidor caído);
      // si no, comprobamos la interfaz de red (modo sin red).
      final comprobar = widget.comprobarServidor;
      if (comprobar != null) {
        final responde = await comprobar();
        if (responde) {
          widget.onReintentar?.call();
          return;
        }
        if (mounted) {
          NotificacionServicio.advertencia(
            context,
            'Flumi sigue sin responder. Puedes seguir usando la app '
            'sin conexión; se sincronizará sola al recuperarse.',
          );
        }
        return;
      }
      final conectado =
          await ConnectivityService.instancia.comprobarAhora();
      if (conectado) {
        widget.onReintentar?.call();
        return;
      }
      if (mounted) {
        NotificacionServicio.advertencia(
          context,
          'Sigue sin conexión. Revisa tu Wi-Fi o datos móviles e intenta otra vez.',
        );
      }
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primario = FlumiTema.colorPrimario;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.icono,
                  size: 96,
                  color: primario.withValues(alpha: 0.85),
                ),
                const SizedBox(height: 28),
                Text(
                  widget.titulo,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.mensaje,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                ),
                if (widget.mostrarBotonReintentar) ...[
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _verificando ? null : _reintentar,
                      icon: _verificando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(
                        _verificando ? 'Comprobando...' : 'Reintentar',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: primario,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
