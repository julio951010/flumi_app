import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../base_datos_local/database.dart';
import '../utilidades/ubicacion_util.dart';
import '../../features/perfiles/perfil_repositorio.dart';

/// Actualiza la ubicación GPS real cada vez que abre la app. Guarda `ciudad`
/// real vía reverse-geocoding (Nominatim OSM) + `ubicacion_lat/lon` para
/// "Cerca de ti". Si no hay red, fallback a provincia cubana offline. Si estás
/// en Miami → Miami, La Habana → La Habana, Moscú → Moscú.
///
/// Es 100% silencioso: no muestra diálogos; si el GPS falla o el permiso está
/// denegado, mantiene la ubicación anterior.
class UbicacionAutoServicio {
  UbicacionAutoServicio._();

  static const _umbralKm = 0.5;

  /// Actualiza ciudad + lat/lon si el GPS da una posición distinta.
  static Future<void> actualizarAlAbrirApp({
    required AppDatabase db,
    required PerfilRepositorio repo,
  }) async {
    try {
      final pos = await obtenerUbicacionGps().timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw TimeoutException('gps timeout'),
      );

      // Ciudad real vía Nominatim (online) → fallback offline Cuba
      String? ciudadReal = await obtenerCiudadReal(pos.lat, pos.lon);
      if (ciudadReal == null || ciudadReal.trim().isEmpty) {
        try {
          final mapa = await cargarMapaProvincias();
          ciudadReal = await resolverNombreUbicacion(
                latitud: pos.lat,
                longitud: pos.lon,
                provincias: mapa,
              ) ??
              provinciaMasCercanaDirecta(pos.lat, pos.lon);
        } catch (_) {
          ciudadReal = provinciaMasCercanaDirecta(pos.lat, pos.lon);
        }
      }
      ciudadReal = ciudadReal.trim();
      if (ciudadReal.isEmpty) return;

      final perfil = await repo.obtenerPerfilPropio();
      final actual = perfil ??
          await (db.select(db.usuarios)
                ..where((u) => u.esPerfilPropio.equals(true))
                ..limit(1))
              .getSingleOrNull();
      if (actual == null) return;

      final lat0 = actual.ubicacionLat;
      final lon0 = actual.ubicacionLon;
      final ciudad0 = actual.ciudad.trim();

      final distancia = (lat0 == 0 && lon0 == 0)
          ? double.infinity
          : _distanciaKm(lat0, lon0, pos.lat, pos.lon);
      final ciudadCambio = ciudad0.toLowerCase() != ciudadReal.toLowerCase();
      final movido = distancia > _umbralKm;

      if (!ciudadCambio && !movido) {
        debugPrint('[UbicacionAuto] sin cambio: $ciudadReal @ ${pos.lat},${pos.lon}');
        return;
      }

      debugPrint('[UbicacionAuto] actualizando $ciudad0 -> $ciudadReal @ ${pos.lat},${pos.lon} (dist ${distancia.toStringAsFixed(2)}km)');

      await repo.guardarOCambiarPerfil(
        UsuariosCompanion(
          uuid: Value(actual.uuid),
          ciudad: Value(ciudadReal),
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
