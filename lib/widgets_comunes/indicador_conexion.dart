import 'dart:async';

import 'package:flutter/material.dart';
import '../core/servicios/connectivity_service.dart';
import '../core/servicios/estado_servidor_servicio.dart';
import '../core/servicios/notificacion_servicio.dart';
import 'sin_conexion_pantalla.dart';

class IndicadorConexion extends StatefulWidget {
  final Widget child;

  const IndicadorConexion({super.key, required this.child});

  @override
  State<IndicadorConexion> createState() => _IndicadorConexionState();
}

class _IndicadorConexionState extends State<IndicadorConexion> {
  bool _conectado = true;
  StreamSubscription<EstadoConexion>? _subRed;

  @override
  void initState() {
    super.initState();
    _conectado = ConnectivityService.instancia.hayConexion;
    _subRed =
        ConnectivityService.instancia.stream.listen((estado) {
      if (!mounted) return;
      final ahora = estado == EstadoConexion.conectado;
      if (ahora == _conectado) return;
      setState(() => _conectado = ahora);

      if (ahora) {
        NotificacionServicio.exito(context, 'Conexión restablecida');
      }
    });
    EstadoServidorServicio.instancia.addListener(_alCambiarServidor);
  }

  @override
  void dispose() {
    _subRed?.cancel();
    EstadoServidorServicio.instancia.removeListener(_alCambiarServidor);
    super.dispose();
  }

  void _alCambiarServidor() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // La navegación siempre permanece montada: si se reemplazara el child,
    // un parpadeo de conexión desmontaría todo el State y los indicadores
    // del bottom nav (ValueNotifiers) se reiniciarían a 0. La pantalla de
    // sin conexión se superpone encima sin tocar el árbol de abajo.
    //
    // Dos estados con pantalla: sin red (interfaz caída) y servidor
    // inalcanzable (hay red pero Supabase no responde: caído, lento o DNS
    // bloqueado). El segundo solo salta tras fallos repetidos (el servicio
    // deduplica ráfagas), así un parpadeo no tapa la app.
    if (_conectado &&
        EstadoServidorServicio.instancia.servidorDisponible) {
      return widget.child;
    }
    final sinRed = !_conectado;
    return Stack(
      children: [
        widget.child,
        SinConexionPantalla(
          titulo: sinRed ? 'Sin conexión' : 'Conexión inestable',
          mensaje: sinRed
              ? 'No pudimos conectar con Flumi. Revisa tu Wi-Fi o datos móviles '
                  'y vuelve a intentarlo.'
              : 'Tienes red, pero Flumi no responde (servidor caído, lento o '
                  'bloqueado). Puedes seguir usando la app sin conexión: se '
                  'sincronizará sola al recuperarse.',
          icono: sinRed ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
          comprobarServidor: sinRed
              ? null
              : () => EstadoServidorServicio.instancia.comprobar(),
          onReintentar: () {
            if (ConnectivityService.instancia.hayConexion && mounted) {
              setState(() => _conectado = true);
            }
          },
        ),
      ],
    );
  }
}
