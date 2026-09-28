import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum EstadoConexion { conectado, desconectado }

/// Igual patrón que en Closi: expone un stream para que la UI reaccione
/// y un getter síncrono para checks puntuales antes de encolar sync.
class ConnectivityService {
  ConnectivityService._interno();
  static final ConnectivityService instancia = ConnectivityService._interno();

  final _controlador = StreamController<EstadoConexion>.broadcast();
  Stream<EstadoConexion> get stream => _controlador.stream;

  EstadoConexion _estadoActual = EstadoConexion.desconectado;
  EstadoConexion get estadoActual => _estadoActual;

  StreamSubscription<List<ConnectivityResult>>? _suscripcion;

  Future<void> iniciar() async {
    if (kIsWeb) {
      // En web asumimos conexión salvo que detectemos lo contrario.
      // connectivity_plus en web puede reportar 'none' inicialmente.
      _estadoActual = EstadoConexion.conectado;
      _controlador.add(_estadoActual);
      _suscripcion = Connectivity()
          .onConnectivityChanged
          .listen(_actualizarEstado);
      debugPrint('[Connectivity] Web: asumimos conexión inicial');
      return;
    }
    final resultado = await Connectivity().checkConnectivity();
    _actualizarEstado(resultado);

    _suscripcion = Connectivity()
        .onConnectivityChanged
        .listen(_actualizarEstado);
  }

  void _actualizarEstado(List<ConnectivityResult> resultados) {
    // En web, si todos son 'none' no necesariamente significa sin internet
    // (puede ser limitación del plugin). Usamos heurística simple.
    final hayConexion = resultados.any((r) => r != ConnectivityResult.none);

    final nuevoEstado =
        hayConexion ? EstadoConexion.conectado : EstadoConexion.desconectado;

    if (nuevoEstado != _estadoActual) {
      _estadoActual = nuevoEstado;
      _controlador.add(_estadoActual);
      debugPrint('[Connectivity] estado cambiado: $nuevoEstado (raw: $resultados)');
    }
  }

  bool get hayConexion => _estadoActual == EstadoConexion.conectado;

  /// Fuerza una comprobación inmediata del estado de red y actualiza el stream.
  /// Devuelve si hay conexión tras la comprobación.
  Future<bool> comprobarAhora() async {
    if (kIsWeb) return true; // Web: asumimos conexión
    final resultado = await Connectivity().checkConnectivity();
    _actualizarEstado(resultado);
    return hayConexion;
  }

  void dispose() {
    _suscripcion?.cancel();
    _controlador.close();
  }
}
