import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Error de GPS con mensaje listo para mostrar al usuario.
class UbicacionException implements Exception {
  final String mensaje;
  const UbicacionException(this.mensaje);
  @override
  String toString() => mensaje;
}

/// Coordenadas obtenidas del GPS del dispositivo.
class CoordenadasGps {
  final double lat;
  final double lon;
  const CoordenadasGps(this.lat, this.lon);
}

/// Obtiene la posición GPS: precisión media (15 s) y reintento rápido con
/// precisión baja (10 s, suficiente a nivel de provincia/ciudad).
/// Lanza [UbicacionException] con texto mostrable si falla.
Future<CoordenadasGps> obtenerUbicacionGps() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const UbicacionException(
        'El GPS está desactivado. Actívalo en los ajustes del dispositivo.');
  }
  var permiso = await Geolocator.checkPermission();
  if (permiso == LocationPermission.denied) {
    permiso = await Geolocator.requestPermission();
  }
  if (permiso == LocationPermission.denied) {
    throw const UbicacionException(
        'Permiso de ubicación denegado. Permítelo para usar esta función.');
  }
  if (permiso == LocationPermission.deniedForever) {
    throw const UbicacionException(
        'El permiso de ubicación está bloqueado. Actívalo manualmente en Ajustes > Permisos.');
  }
  Position posicion;
  try {
    posicion = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    );
  } on TimeoutException {
    try {
      posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } on TimeoutException {
      throw const UbicacionException(
          'Tiempo de espera agotado. Verifica la señal GPS e intenta de nuevo.');
    }
  } on PlatformException catch (e) {
    throw UbicacionException(_mensajeGpsPlataforma(e.code));
  }
  if (posicion.latitude == 0 && posicion.longitude == 0) {
    throw const UbicacionException(
        'No se pudo obtener una ubicación válida. Verifica la señal GPS e intenta de nuevo.');
  }
  return CoordenadasGps(posicion.latitude, posicion.longitude);
}

String _mensajeGpsPlataforma(String codigo) {
  switch (codigo) {
    case 'location_unavailable':
      return 'Ubicación no disponible. Verifica la señal GPS e intenta de nuevo.';
    case 'permission_denied':
      return 'Permiso de ubicación denegado.';
    case 'timeout':
      return 'Tiempo de espera agotado para obtener la ubicación. Intenta de nuevo.';
    case 'service_not_available':
      return 'Servicio de ubicación no disponible en este dispositivo.';
    default:
      return 'Error del GPS. Intenta de nuevo.';
  }
}

/// Coordenadas aproximadas de las capitales provinciales de Cuba.
///
/// Permiten determinar la provincia más cercana a unas coordenadas GPS de
/// forma 100% local y offline, sin depender de Google Maps ni de ningún
/// servicio de terceros (la resolución de nombre se hace por distancia).
/// También se usa en sentido inverso: para aproximar lat/lon cuando el
/// usuario elige su ubicación a mano (sin GPS) desde la lista de
/// provincias/municipios.
const Map<String, (double lat, double lng)> coordenadasProvinciasCuba = {
  'Pinar del Río': (22.4170, -83.6970),
  'Artemisa': (22.8080, -82.7640),
  'La Habana': (23.1130, -82.3660),
  'Mayabeque': (22.9500, -82.1500),
  'Matanzas': (23.0530, -81.5770),
  'Villa Clara': (22.4070, -79.9640),
  'Cienfuegos': (22.1470, -80.4450),
  'Sancti Spíritus': (21.9330, -79.4450),
  'Ciego de Ávila': (21.8400, -78.7600),
  'Camagüey': (21.3800, -77.9200),
  'Las Tunas': (20.9600, -76.9500),
  'Holguín': (20.8870, -76.2600),
  'Granma': (20.3870, -76.6430),
  'Santiago de Cuba': (20.0200, -75.8300),
  'Guantánamo': (20.1400, -75.2100),
  'Isla de la Juventud': (21.7200, -82.8500),
};

/// Aproxima lat/lon para una opción elegida a mano (provincia o municipio),
/// usando las coordenadas de la capital provincial como referencia. No es
/// tan preciso como el GPS, pero es suficiente para el radio de búsqueda de
/// "cerca de ti" (decenas de km) y evita dejar ubicacion_lat/lon en 0.
///
/// [provincias] es el mapa provincia -> lista de municipios (el mismo que
/// usan las pantallas de ubicación para el autocompletado).
(double lat, double lon)? coordenadasParaOpcion(
  String opcion,
  Map<String, List<String>> provincias,
) {
  final directa = coordenadasProvinciasCuba[opcion];
  if (directa != null) return (directa.$1, directa.$2);
  for (final entrada in provincias.entries) {
    if (entrada.value.contains(opcion)) {
      final coord = coordenadasProvinciasCuba[entrada.key];
      if (coord != null) return (coord.$1, coord.$2);
    }
  }
  return null;
}

/// Resuelve un nombre de ubicación conocido a partir de unas coordenadas.
///
/// La resolución es 100% local y offline: se calcula la provincia más cercana
/// por distancia entre las coordenadas GPS y una tabla de coordenadas de
/// Cuba. No realiza ninguna llamada de red ni depende de Google Maps u otros
/// servicios de terceros.
///
/// Devuelve `null` únicamente si no se pudo determinar ninguna ubicación.
Future<String?> resolverNombreUbicacion({
  required double latitud,
  required double longitud,
  required Map<String, List<String>> provincias,
}) async {
  return _provinciaMasCercana(latitud, longitud, provincias);
}

/// Provincia más cercana usando solo la tabla estática (sin depender del
/// JSON de municipios). Nunca devuelve null: es el último recurso para que
/// "Usar mi ubicación" siempre resuelva un nombre aunque falle la otra vía.
String provinciaMasCercanaDirecta(double latitud, double longitud) {
  var mejor = coordenadasProvinciasCuba.keys.first;
  var mejorDistancia = double.infinity;
  for (final entrada in coordenadasProvinciasCuba.entries) {
    final d =
        _distanciaKm(latitud, longitud, entrada.value.$1, entrada.value.$2);
    if (d < mejorDistancia) {
      mejorDistancia = d;
      mejor = entrada.key;
    }
  }
  return mejor;
}

String? _provinciaMasCercana(
  double latitud,
  double longitud,
  Map<String, List<String>> provincias,
) {
  String? mejor;
  var mejorDistancia = double.infinity;
  for (final nombre in provincias.keys) {
    final coord = coordenadasProvinciasCuba[nombre];
    if (coord == null) continue;
    final distancia = _distanciaKm(latitud, longitud, coord.$1, coord.$2);
    if (distancia < mejorDistancia) {
      mejorDistancia = distancia;
      mejor = nombre;
    }
  }
  return mejor;
}

double _distanciaKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = _aRadianes(lat2 - lat1);
  final dLon = _aRadianes(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_aRadianes(lat1)) * cos(_aRadianes(lat2)) *
          sin(dLon / 2) * sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return r * c;
}

double _aRadianes(double grados) => grados * pi / 180;

/// Reverse geocoding online (Nominatim OSM) para ciudad real en cualquier
/// país (Miami, Moscú, La Habana...). Si no hay red o falla, devuelve null
/// y el caller usa fallback offline (provincias cubanas). No requiere API key.
Future<String?> obtenerCiudadReal(double lat, double lon) async {
  try {
    final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&zoom=10&accept-language=es');
    final res = await http
        .get(uri, headers: {'User-Agent': 'Flumi/1.0 (flumi.app)'})
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final addr = data['address'] as Map<String, dynamic>?;
    if (addr == null) return null;
    return (addr['city'] as String?) ??
        (addr['town'] as String?) ??
        (addr['village'] as String?) ??
        (addr['municipality'] as String?) ??
        (addr['county'] as String?) ??
        (addr['state'] as String?);
  } catch (_) {
    return null;
  }
}

/// Carga el mapa provincia -> municipios desde el JSON asset.
Future<Map<String, List<String>>> cargarMapaProvincias() async {
  try {
    final jsonStr =
        await rootBundle.loadString('assets/data/cuba_provincias_municipios.json');
    return parsearMapaProvincias(jsonStr);
  } catch (_) {
    return {};
  }
}

/// Parsea el JSON de provincias/municipios a mapa.
Map<String, List<String>> parsearMapaProvincias(String jsonStr) {
  try {
    final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
    final paises = decoded['paises'] as List?;
    if (paises == null || paises.isEmpty) return {};
    final pais = paises.first as Map<String, dynamic>;
    final provincias = pais['provincias'] as List?;
    if (provincias == null) return {};
    final mapa = <String, List<String>>{};
    for (final p in provincias) {
      final m = p as Map<String, dynamic>;
      final nombre = (m['nombre'] as String?) ?? '';
      if (nombre.isEmpty) continue;
      final municipios = (m['municipios'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];
      mapa[nombre] = municipios;
    }
    return mapa;
  } catch (_) {
    return {};
  }
}
