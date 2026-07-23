import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

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
    final resultado = await Connectivity().checkConnectivity();
    _actualizarEstado(resultado);

    _suscripcion = Connectivity()
        .onConnectivityChanged
        .listen(_actualizarEstado);
  }

  void _actualizarEstado(List<ConnectivityResult> resultados) {
    final hayConexion =
        resultados.any((r) => r != ConnectivityResult.none);

    final nuevoEstado =
        hayConexion ? EstadoConexion.conectado : EstadoConexion.desconectado;

    if (nuevoEstado != _estadoActual) {
      _estadoActual = nuevoEstado;
      _controlador.add(_estadoActual);
    }
  }

  bool get hayConexion => _estadoActual == EstadoConexion.conectado;

  void dispose() {
    _suscripcion?.cancel();
    _controlador.close();
  }
}
