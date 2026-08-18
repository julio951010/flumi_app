import 'dart:math';

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
