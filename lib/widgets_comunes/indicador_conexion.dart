import 'package:flutter/material.dart';
import '../core/servicios/connectivity_service.dart';
import '../core/servicios/notificacion_servicio.dart';

class IndicadorConexion extends StatefulWidget {
  final Widget child;

  const IndicadorConexion({super.key, required this.child});

  @override
  State<IndicadorConexion> createState() => _IndicadorConexionState();
}

class _IndicadorConexionState extends State<IndicadorConexion> {
  bool _conectado = true;

  @override
  void initState() {
    super.initState();
    _conectado = ConnectivityService.instancia.hayConexion;
    ConnectivityService.instancia.stream.listen((estado) {
      if (!mounted) return;
      final ahora = estado == EstadoConexion.conectado;
      if (ahora == _conectado) return;
      setState(() => _conectado = ahora);

      if (!ahora) {
        NotificacionServicio.advertencia(
          context,
          'Sin conexión — los cambios se sincronizarán después',
        );
      } else {
        NotificacionServicio.exito(
          context,
          'Conexión restablecida',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
