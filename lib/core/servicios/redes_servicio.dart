import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/env.dart';

/// Red social oficial de Flumi (fila de `public.redes_sociales`).
/// Se gestionan desde admin_flumi; la app solo lee.
class RedSocial {
  final String id;
  final String nombre;
  final String usuario;
  final String url;
  final String icono;
  final int orden;

  const RedSocial({
    required this.id,
    required this.nombre,
    required this.usuario,
    required this.url,
    required this.icono,
    required this.orden,
  });

  factory RedSocial.fromMap(Map<String, dynamic> m) => RedSocial(
        id: (m['id'] as String?) ?? '',
        nombre: (m['nombre'] as String?) ?? '',
        usuario: (m['usuario'] as String?) ?? '',
        url: (m['url'] as String?) ?? '',
        icono: (m['icono'] as String?) ?? 'web',
        orden: (m['orden'] as int?) ?? 0,
      );
}

/// Estilo (icono + color) por clave de `icono`. Claves válidas:
/// telegram | whatsapp | instagram | facebook | x | tiktok | youtube | web.
({IconData icono, Color color}) estiloRed(String clave) {
  switch (clave) {
    case 'telegram':
      return (icono: Icons.send_outlined, color: const Color(0xFF229ED9));
    case 'whatsapp':
      return (icono: Icons.chat_outlined, color: const Color(0xFF25D366));
    case 'instagram':
      return (
        icono: Icons.camera_alt_outlined,
        color: const Color(0xFFE1306C)
      );
    case 'facebook':
      return (icono: Icons.facebook_outlined, color: const Color(0xFF1877F2));
    case 'x':
      return (icono: Icons.alternate_email_outlined, color: Colors.black87);
    case 'tiktok':
      return (icono: Icons.music_note_outlined, color: Colors.black87);
    case 'youtube':
      return (
        icono: Icons.ondemand_video_outlined,
        color: const Color(0xFFFF0000)
      );
    default:
      return (icono: Icons.link_outlined, color: Colors.grey);
  }
}

/// Lee `public.redes_sociales` (solo `activo = true`, ordenadas).
/// Caché en memoria con frescura; sin red usa la caché aunque esté vencida.
class RedesServicio {
  RedesServicio._();
  static final RedesServicio instancia = RedesServicio._();

  /// Tiempo que la lista se considera fresca sin volver a la red.
  static const frescuraMaxima = Duration(minutes: 15);

  List<RedSocial>? _cache;
  DateTime? _cacheEn;

  Future<List<RedSocial>> obtenerRedes({bool forzarRefresh = false}) async {
    final fresco = _cacheEn != null &&
        DateTime.now().difference(_cacheEn!) < frescuraMaxima;
    if (!forzarRefresh && fresco && _cache != null) return _cache!;
    if (kUsarServidorLocal) {
      if (_cache != null) return _cache!;
      throw Exception('sin servidor');
    }
    try {
      final res = await Supabase.instance.client
          .from('redes_sociales')
          .select('id,nombre,usuario,url,icono,orden')
          .eq('activo', true)
          .order('orden')
          .order('nombre')
          .timeout(const Duration(seconds: 8));
      final redes = (res as List)
          .map((e) => RedSocial.fromMap(Map<String, dynamic>.from(e as Map)))
          .where((r) => r.nombre.isNotEmpty && r.url.isNotEmpty)
          .toList();
      _cache = redes;
      _cacheEn = DateTime.now();
      return redes;
    } catch (_) {
      if (_cache != null) return _cache!;
      rethrow;
    }
  }

  void limpiarCache() {
    _cache = null;
    _cacheEn = null;
  }
}
