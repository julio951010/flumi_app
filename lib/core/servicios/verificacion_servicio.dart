import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../base_datos_local/database.dart';
import 'verificacion_impl_native.dart'
    if (dart.library.html) 'verificacion_impl_web.dart';

/// Resultado de la verificación facial de un perfil.
enum VerificarResultado {
  coincide,
  noCoincide,
  sinFotos,
  error,
}

/// Verifica la identidad del usuario comparando la selfie de verificación
/// (con un gesto) contra las fotos de perfil ya registradas.
///
/// En Android/iOS usa FaceNet on-device ([face_verification]); en web se delega
/// al servidor vía [verificarPerfilWeb] (la implementación on-device no existe
/// en web por [dart:ffi]).
class VerificacionServicio {
  VerificacionServicio._();

  /// Verificación on-device (Android/iOS). En web devuelve [VerificarResultado.error]
  /// porque el modelo no está disponible; usa [verificarPerfilWeb] en su lugar.
  static Future<VerificarResultado> verificarPerfil({
    required Usuario perfil,
    required String rutaSelfie,
  }) async {
    if (kIsWeb) return VerificarResultado.error;
    try {
      return await verificarPerfilImpl(perfil: perfil, rutaSelfie: rutaSelfie)
          .timeout(
        const Duration(seconds: 60),
        onTimeout: () => VerificarResultado.error,
      );
    } catch (_) {
      return VerificarResultado.error;
    }
  }

  /// Variante web: delega la comparación facial en la Edge Function
  /// `verificar_rostro` (Deno + face-api.js), ya que [face_verification]
  /// solo funciona en Android/iOS.
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
