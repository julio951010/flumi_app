import 'package:flutter/foundation.dart';

import 'reconocimiento_gesto_impl_native.dart'
    if (dart.library.html) 'reconocimiento_gesto_impl_web.dart';

/// Resultado del análisis de gesto sobre una selfie comparada con la imagen
/// de referencia mostrada al usuario.
class ResultadoGesto {
  const ResultadoGesto({
    required this.exito,
    this.gestoEsperado,
    this.gestoDetectado,
    this.confianza,
    required this.mensaje,
  });

  /// `true` cuando el gesto de la selfie coincide con el de la imagen mostrada
  /// (o, si no se pudo clasificar la referencia, cuando hay un gesto claro).
  final bool exito;

  /// Gesto esperado según la imagen mostrada (p. ej. `thumbUp`, `victory`),
  /// o `null` si no se pudo clasificar la referencia.
  final String? gestoEsperado;

  /// Gesto detectado en la selfie, si aplica.
  final String? gestoDetectado;

  /// Confianza del gesto detectado en la selfie (0..1).
  final double? confianza;

  final String mensaje;
}

/// Verifica, on-device, que la selfie de verificación contenga el mismo gesto
/// que la imagen de referencia mostrada al usuario.
///
/// En Android/iOS usa [HandDetector] (MediaPipe/LiteRT). En web se omite
/// porque el reconocimiento on-device no está disponible ([dart:ffi]); la
/// verificación facial ya se delega al servidor.
class ReconocimientoGestoServicio {
  ReconocimientoGestoServicio._();

  /// [selfieRuta] es la ruta local del archivo de la selfie (no se usa el tipo
  /// [File] para mantener la API web-safe).
  static Future<ResultadoGesto> verificarGesto({
    required String selfieRuta,
    required String referenciaRuta,
    String? esperadoGesto,
  }) async {
    if (kIsWeb) {
      return const ResultadoGesto(
        exito: true,
        mensaje: 'Reconocimiento de gesto omitido en web.',
      );
    }
    return verificarGestoImpl(
      selfieRuta: selfieRuta,
      referenciaRuta: referenciaRuta,
      esperadoGesto: esperadoGesto,
    );
  }
}
