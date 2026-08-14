import 'package:flutter/material.dart';

import '../core/estilos/tema.dart';
import '../core/servicios/connectivity_service.dart';
import '../core/servicios/notificacion_servicio.dart';

/// Pantalla a pantalla completa que se muestra cuando la app no tiene
/// conexión a la red. Ofrece un botón para reintentar y, si se reconecta,
/// el contenedor que la muestra (p. ej. [IndicadorConexion]) vuelve a
/// renderizar la app.
class SinConexionPantalla extends StatefulWidget {
  final VoidCallback? onReintentar;
  final bool mostrarBotonReintentar;

  const SinConexionPantalla({
    super.key,
    this.onReintentar,
    this.mostrarBotonReintentar = true,
  });

  @override
  State<SinConexionPantalla> createState() => _SinConexionPantallaState();
}

class _SinConexionPantallaState extends State<SinConexionPantalla> {
  bool _verificando = false;

  Future<void> _reintentar() async {
    setState(() => _verificando = true);
    try {
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
    final primario = FlumiTema.colorPrimario;
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
                  Icons.wifi_off_rounded,
                  size: 96,
                  color: primario.withValues(alpha: 0.85),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Sin conexión',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No pudimos conectar con Flumi. Revisa tu Wi-Fi o datos móviles '
                  'y vuelve a intentarlo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
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
