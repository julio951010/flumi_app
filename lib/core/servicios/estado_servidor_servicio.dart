import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../config/env.dart';
import 'connectivity_service.dart';

/// Rastrea si el servidor (Supabase) responde de verdad, a diferencia de
/// [ConnectivityService], que solo sabe si hay red: un WiFi sin salida a
/// internet cuenta como "conectado" y todo falla en silencio.
///
/// Cada fallo de RED llama a [marcarFallo]; un sondeo periódico revalida el
/// estado y cualquier éxito lo restaura inmediatamente.
class EstadoServidorServicio with ChangeNotifier {
  EstadoServidorServicio._interno();
  static final EstadoServidorServicio instancia =
      EstadoServidorServicio._interno();

  static const _sondeoCada = Duration(seconds: 30);

  /// Fallos consecutivos necesarios para avisar: evita que un fallo único y
  /// transitorio encienda el banner.
  static const _fallosParaAvisar = 2;

  /// Ventana de deduplicación: los fallos que llegan en ráfaga (p. ej. el
  /// mismo episodio de red caída que tumba varios syncs a la vez) cuentan
  /// como uno solo. Así el banner requiere dos EPISODIOS distintos, no dos
  /// excepciones cualesquiera.
  static const _ventanaDeduplicacion = Duration(seconds: 15);

  bool _servidorDisponible = true;
  bool get servidorDisponible => _servidorDisponible;

  int _fallosConsecutivos = 0;
  DateTime? _ultimoFallo;
  Timer? _timer;
  bool _sondeoEnCurso = false;

  /// Distingue un fallo real de red (socket, timeout, conexión rechazada...)
  /// de un error del servidor (RPC que falla, permisos, función inexistente):
  /// solo los primeros indican que el servidor está inalcanzable, y son los
  /// únicos que deben encender el banner de "fallo de conexión".
  static bool esFalloRed(Object error) {
    // PostgrestException solo se lanza cuando el servidor RESPONDIÓ con un
    // error (RPC que falla, permisos, función inexistente...), nunca por red.
    if (error is sb.PostgrestException) return false;
    return error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException ||
        error is IOException ||
        error is sb.AuthException;
  }

  /// Arranca el sondeo periódico de salud del servidor.
  void iniciarSondeo() {
    _timer?.cancel();
    _timer = Timer.periodic(_sondeoCada, (_) {
      if (ConnectivityService.instancia.hayConexion) {
        comprobar();
      }
    });
  }

  /// Reporta un fallo puntual. Con [error] solo se cuenta si es un fallo de
  /// red: un error del servidor no significa que esté "caído".
  void marcarFallo([Object? error]) {
    if (error != null && !esFalloRed(error)) return;
    final ahora = DateTime.now();
    final ultimo = _ultimoFallo;
    _ultimoFallo = ahora;
    if (ultimo != null && ahora.difference(ultimo) < _ventanaDeduplicacion) {
      return;
    }
    _fallosConsecutivos++;
    if (_fallosConsecutivos >= _fallosParaAvisar && _servidorDisponible) {
      _servidorDisponible = false;
      notifyListeners();
    }
  }

  /// Reporta un éxito: el servidor respondió.
  void marcarExito() {
    _fallosConsecutivos = 0;
    _ultimoFallo = null;
    if (!_servidorDisponible) {
      _servidorDisponible = true;
      notifyListeners();
    }
  }

  /// Sonda ligera: comprueba ahora mismo si el servidor responde.
  Future<bool> comprobar() async {
    if (_sondeoEnCurso) return _servidorDisponible;
    _sondeoEnCurso = true;
    try {
      if (!kUsarServidorLocal) {
        await sb.Supabase.instance.client
            .from('perfiles')
            .select('id')
            .limit(1);
      }
      marcarExito();
      return true;
    } catch (e) {
      marcarFallo(e);
      return false;
    } finally {
      _sondeoEnCurso = false;
    }
  }
}