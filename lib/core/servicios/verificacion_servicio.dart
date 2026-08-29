import 'dart:io';

import 'package:face_verification/face_verification.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../base_datos_local/database.dart';

/// Resultado de la verificación facial de un perfil.
enum VerificarResultado {
  coincide,
  noCoincide,
  sinFotos,
  error,
}

/// Verifica la identidad del usuario comparando la selfie de verificación
/// (con un gesto) contra las fotos de perfil ya registradas, de forma
/// on-device con [face_verification] (FaceNet).
class VerificacionServicio {
  VerificacionServicio._();

  static const String _idEnrolamiento = 'perfil_propia';
  static const double _umbral = 0.70;

  static bool _inicializado = false;

  /// Inicializa el modelo FaceNet una sola vez por sesión.
  static Future<void> _asegurarInit() async {
    if (_inicializado) return;
    await FaceVerification.instance.init();
    _inicializado = true;
  }

  /// Resuelve las fotos de perfil a archivos locales.
  /// Usa las rutas locales cuando existen; en caso contrario descarga las
  /// URLs remotas a un archivo temporal.
  static Future<List<File>> _archivosPerfil(Usuario perfil) async {
    final archivos = <File>[];
    for (final ruta in perfil.fotosLocalesRutas) {
      final f = File(ruta);
      if (await f.exists()) archivos.add(f);
    }
    for (final url in perfil.fotosUrls) {
      if (url.isEmpty) continue;
      try {
        final res = await http.get(Uri.parse(url));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          final dir = await getTemporaryDirectory();
          final f = File(
            '${dir.path}/verif_${archivos.length}_'
            '${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          await f.writeAsBytes(res.bodyBytes);
          archivos.add(f);
        }
      } catch (_) {
        // Ignora fotos que no se puedan resolver y continúa con las demás.
      }
    }
    return archivos;
  }

  /// Compara [rutaSelfie] contra las fotos del [perfil].
  ///
  /// Devuelve [VerificarResultado.coincide] cuando la selfie corresponde a la
  /// misma persona enrolada en las fotos de perfil; [noCoincide] si no;
  /// [sinFotos] si el perfil no tiene fotos con las que comparar; y [error]
  /// ante cualquier fallo (p. ej. plataforma no soportada o sin rostro).
  static Future<VerificarResultado> verificarPerfil({
    required Usuario perfil,
    required String rutaSelfie,
  }) async {
    if (kIsWeb) return VerificarResultado.error;
    try {
      await _asegurarInit();

      final archivos = await _archivosPerfil(perfil);
      if (archivos.isEmpty) return VerificarResultado.sinFotos;

      // Enrola (o reemplaza) las fotos de perfil como muestras de la persona.
      await FaceVerification.instance.deleteUserFaces(_idEnrolamiento);
      for (var i = 0; i < archivos.length; i++) {
        await FaceVerification.instance.registerFromImagePath(
          id: _idEnrolamiento,
          imagePath: archivos[i].path,
          imageId: 'foto_$i',
          replace: true,
        );
      }

      final match = await FaceVerification.instance.verifyFromImagePath(
        imagePath: rutaSelfie,
        threshold: _umbral,
        staffId: _idEnrolamiento,
      );

      return match == _idEnrolamiento
          ? VerificarResultado.coincide
          : VerificarResultado.noCoincide;
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
    final fotos =
        perfil.fotosUrls.where((u) => u.isNotEmpty).toList();
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
