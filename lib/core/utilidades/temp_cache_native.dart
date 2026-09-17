import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Borra los archivos temporales de la app (nativo). Devuelve los bytes
/// liberados. Solo se usa en plataformas nativas.
Future<int> borrarCacheTemporal() async {
  var liberados = 0;
  try {
    final dir = await getTemporaryDirectory();
    if (await dir.exists()) {
      await for (final entidad
          in dir.list(recursive: true, followLinks: false)) {
        try {
          if (entidad is File) {
            final tamano = await entidad.length();
            await entidad.delete();
            liberados += tamano;
          }
        } catch (_) {}
      }
    }
  } catch (_) {}
  return liberados;
}
