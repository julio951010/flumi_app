import 'package:flutter/material.dart';
import '../core/servicios/connectivity_service.dart';

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
      if (mounted) {
        setState(() => _conectado = estado == EstadoConexion.conectado);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!_conectado)
          Container(
            width: double.infinity,
            color: Colors.orange,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: const Text(
              'Sin conexión — los cambios se sincronizarán después',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
