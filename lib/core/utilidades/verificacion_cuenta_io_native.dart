import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Espeja horizontalmente la selfie (como un espejo) para que el gesto
/// coincida con el preview y la referencia, y hornea la orientación EXIF.
/// Devuelve (rutaFinal, espejada). Solo se usa en plataformas nativas.
Future<(String, bool)> espejarSelfie(String rutaOriginal) async {
  try {
    final bytes = await File(rutaOriginal).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return (rutaOriginal, false);
    final procesada = img.flipHorizontal(img.bakeOrientation(decoded));
    final dir = await getTemporaryDirectory();
    final rutaFinal =
        '${dir.path}/selfie_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(rutaFinal).writeAsBytes(img.encodeJpg(procesada, quality: 90));
    // Limpia el archivo temporal que generó el plugin de cámara.
    try {
      await File(rutaOriginal).delete();
    } catch (_) {}
    return (rutaFinal, true);
  } catch (_) {
    return (rutaOriginal, false);
  }
}

/// Borra el archivo local de la selfie. No-op si no existe.
Future<void> borrarArchivo(String ruta) async {
  try {
    final archivo = File(ruta);
    if (await archivo.exists()) await archivo.delete();
  } catch (_) {
    // Si no se puede borrar (p. ej. ya removido), se ignora.
  }
}
