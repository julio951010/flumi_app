import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../config/env.dart';
import '../utilidades/app_log.dart';

/// Ping anónimo de instalación.
///
/// Guarda un UUID local la primera vez que se abre la app y lo registra en
/// Supabase (`registrar_instalacion`). Sirve para contar instalaciones
/// aunque el usuario nunca llegue a registrarse.
class InstallPingServicio {
  InstallPingServicio._();

  static const _prefsKey = 'flumi_install_id';
  static const _plataforma = 'android';

  static Future<void> registrar() async {
    if (kUsarServidorLocal) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_prefsKey);
      if (id == null || id.isEmpty) {
        id = const Uuid().v4();
        await prefs.setString(_prefsKey, id);
      }

      String version = '';
      try {
        final info = await PackageInfo.fromPlatform();
        version = '${info.version}+${info.buildNumber}';
      } catch (_) {}

      await Supabase.instance.client.rpc(
        'registrar_instalacion',
        params: {
          'p_id': id,
          'p_plataforma': _plataforma,
          'p_version': version,
        },
      ).timeout(const Duration(seconds: 6));
      appLog('[InstallPing] instalación registrada: $id ($version)');
    } catch (e) {
      // Sin red o sin Supabase: no es crítico, se reintenta en el próximo
      // arranque porque el UUID queda guardado en SharedPreferences.
      appLog('[InstallPing] no se pudo registrar: $e');
    }
  }
}
