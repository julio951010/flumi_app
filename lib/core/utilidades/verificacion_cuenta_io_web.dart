/// Stub web: no hay sistema de archivos local ([dart:io] no disponible). La
/// selfie del picker es un blob efímero, así que no se espeja ni se borra.
Future<(String, bool)> espejarSelfie(String rutaOriginal) async =>
    (rutaOriginal, false);

/// Stub web: no aplica borrar archivo local.
Future<void> borrarArchivo(String ruta) async {}
