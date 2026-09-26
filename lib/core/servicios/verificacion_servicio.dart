import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../base_datos_local/database.dart';

/// Resultado de la verificación facial de un perfil.
enum VerificarResultado {
  coincide,
  noCoincide,
  sinFotos,
  error,
}

/// Comparación facial vía Edge Function `verificar_rostro` (face-api.js).
///
/// Se usa solo como respaldo (p. ej. web). El flujo principal es la revisión
/// manual: la selfie se sube y un administrador la aprueba desde admin_flumi.
/// Sin ML on-device: la app no incluye FaceNet ni detección de gestos.
class VerificacionServicio {
  VerificacionServicio._();

  /// Delega la comparación facial en la Edge Function `verificar_rostro`.
  ///
  /// [selfieUrl] es la URL pública de la selfie ya subida a Storage y
  /// [perfil].fotosUrls son las URLs de las fotos de perfil a comparar.
  static Future<VerificarResultado> verificarPerfilWeb({
    required Usuario perfil,
    required String selfieUrl,
  }) async {
    final fotos = perfil.fotosUrls.where((u) => u.isNotEmpty).toList();
    if (fotos.isEmpty) return VerificarResultado.sinFotos;
    try {
      final res = await sb.Supabase.instance.client.functions.invoke(
        'verificar_rostro',
        body: {'selfie': selfieUrl, 'fotos': fotos},
      );
      final data = res.data as Map<String, dynamic>?;
      final coincide = data?['coincide'] == true;
      return coincide
          ? VerificarResultado.coincide
          : VerificarResultado.noCoincide;
    } on sb.FunctionException {
      return VerificarResultado.error;
    } catch (_) {
      return VerificarResultado.error;
    }
  }
}
