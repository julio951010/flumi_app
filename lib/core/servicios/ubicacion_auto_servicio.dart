import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../base_datos_local/database.dart';
import '../utilidades/ubicacion_util.dart';
import '../../features/perfiles/perfil_repositorio.dart';

/// Actualiza la ubicación GPS real cada vez que abre la app. Solo guarda
/// `ubicacion_lat` y `ubicacion_lon` para "Cerca de ti" (cálculos de
/// distancia y RPC `perfiles_cercanos`). `ciudad` NO se toca aquí: solo se
/// edita desde Onboarding perfil, Editar Perfil y Configuración →
/// Información básica, tal como pide producto.
///
/// Es 100% silencioso: no muestra diálogos ni toasts; si el GPS falla o el
/// permiso está denegado, mantiene la ubicación anterior.
class UbicacionAutoServicio {
  UbicacionAutoServicio._();

  /// Distancia mínima para considerar que el usuario se movió y vale la pena
  /// escribir en BD (evita escrituras constantes si está quieto en casa).
  static const _umbralKm = 0.5;

  /// Actualiza lat/lon si el GPS da una posición distinta a la guardada.
  /// Llamar en `initState` de la pantalla principal y en `didChangeAppLifecycleState(resumed)`.
  static Future<void> actualizarAlAbrirApp({
    required AppDatabase db,
    required PerfilRepositorio repo,
  }) async {
    try {
      final pos = await obtenerUbicacionGps().timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw TimeoutException('gps timeout'),
      );

      final perfil = await repo.obtenerPerfilPropio();
      final actual = perfil ??
          await (db.select(db.usuarios)
                ..where((u) => u.esPerfilPropio.equals(true))
                ..limit(1))
              .getSingleOrNull();
      if (actual == null) return;

      final lat0 = actual.ubicacionLat;
      final lon0 = actual.ubicacionLon;

      final distancia = (lat0 == 0 && lon0 == 0)
          ? double.infinity
          : _distanciaKm(lat0, lon0, pos.lat, pos.lon);

      if (distancia <= _umbralKm) {
        debugPrint('[UbicacionAuto] sin cambio lat/lon @ ${pos.lat},${pos.lon} (dist ${distancia.toStringAsFixed(2)}km) - ciudad intacta: ${actual.ciudad}');
        return;
      }

      debugPrint('[UbicacionAuto] actualizando lat/lon @ ${pos.lat},${pos.lon} (dist ${distancia.toStringAsFixed(2)}km) - ciudad intacta: ${actual.ciudad}');

      await repo.guardarOCambiarPerfil(
        UsuariosCompanion(
          uuid: Value(actual.uuid),
          ubicacionLat: Value(pos.lat),
          ubicacionLon: Value(pos.lon),
        ),
      );
    } catch (e) {
      debugPrint('[UbicacionAuto] no actualizado: $e');
    }
  }

  static double _distanciaKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _aRadianes(lat2 - lat1);
    final dLon = _aRadianes(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_aRadianes(lat1)) * cos(_aRadianes(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  static double _aRadianes(double g) => g * pi / 180;
}
