import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/env.dart';

/// Lee `public.contenidos_legales` (términos, privacidad, contactos, etc.).
/// Caché en memoria por clave; sin red lanza y la UI muestra el fallback.
class ContenidosServicio {
  ContenidosServicio._();
  static final ContenidosServicio instancia = ContenidosServicio._();

  final Map<String, String> _cache = {};

  Future<String> obtenerCuerpo(String clave) async {
    if (_cache.containsKey(clave)) return _cache[clave]!;
    if (kUsarServidorLocal) throw Exception('sin servidor');
    final res = await Supabase.instance.client
        .from('contenidos_legales')
        .select('cuerpo')
        .eq('clave', clave)
        .maybeSingle()
        .timeout(const Duration(seconds: 8));
    if (res == null) throw Exception('sin contenido');
    final cuerpo = (res['cuerpo'] as String?) ?? '';
    _cache[clave] = cuerpo;
    return cuerpo;
  }

  void limpiarCache() => _cache.clear();

  @visibleForTesting
  void sembrarParaTest(String clave, String cuerpo) =>
      _cache[clave] = cuerpo;
}
