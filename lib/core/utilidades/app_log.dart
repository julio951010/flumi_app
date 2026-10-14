import 'package:flutter/foundation.dart';

/// Log diagnóstico SOLO en debug. En release no hace nada.
///
/// Motivo: `debugPrint`/`print` sí escriben en logcat en release, y varios
/// puntos del código registran datos sensibles (contenido de mensajes,
/// UUIDs de usuarios, payloads de sync). Cualquier app con permiso de
/// lectura de logs podría verlos. Todo log de diagnóstico debe pasar
/// por aquí en vez de `debugPrint`/`print` directos.
void appLog(String mensaje) {
  if (kDebugMode) debugPrint(mensaje);
}
