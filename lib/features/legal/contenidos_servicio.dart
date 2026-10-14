import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/env.dart';

/// Lee `public.contenidos_legales` (términos, privacidad, contactos, etc.).
/// Caché en memoria por clave con frescura: pasado [frescuraMaxima] se
/// vuelve a leer del servidor (así los cambios de admin_flumi llegan sin
/// reiniciar). Con `forzarRefresh` se salta la caché (botón Recargar y
/// pull-to-refresh). Sin red se usa la caché aunque esté vencida (offline-first).
class ContenidosServicio {
  ContenidosServicio._();
  static final ContenidosServicio instancia = ContenidosServicio._();

  /// Tiempo que un contenido se considera fresco sin volver a la red.
  static const frescuraMaxima = Duration(minutes: 15);

  final Map<String, String> _cache = {};
  final Map<String, DateTime> _cacheEn = {};

  Future<String> obtenerCuerpo(String clave,
      {bool forzarRefresh = false}) async {
    final guardadoEn = _cacheEn[clave];
    final fresco = guardadoEn != null &&
        DateTime.now().difference(guardadoEn) < frescuraMaxima;
    if (!forzarRefresh && fresco && _cache.containsKey(clave)) {
      return _cache[clave]!;
    }
    if (kUsarServidorLocal) {
      if (_cache.containsKey(clave)) return _cache[clave]!;
      throw Exception('sin servidor');
    }
    try {
      final res = await Supabase.instance.client
          .from('contenidos_legales')
          .select('cuerpo')
          .eq('clave', clave)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));
      if (res == null) throw Exception('sin contenido');
      final cuerpo = (res['cuerpo'] as String?) ?? '';
      _cache[clave] = cuerpo;
      _cacheEn[clave] = DateTime.now();
      return cuerpo;
    } catch (_) {
      // Fallback a caché vencida antes de fallar (offline-first).
      if (_cache.containsKey(clave)) return _cache[clave]!;
      rethrow;
    }
  }

  void limpiarCache() {
    _cache.clear();
    _cacheEn.clear();
  }

  @visibleForTesting
  void sembrarParaTest(String clave, String cuerpo) =>
      _cache[clave] = cuerpo;
}
