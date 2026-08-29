import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hand_detection/hand_detection.dart';

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
/// Flujo:
/// 1. Se detecta el gesto de la imagen mostrada (`referenciaRuta`).
/// 2. Se detecta el gesto de la selfie.
/// 3. Se exige que ambos coincidan con confianza >= [_umbral].
///
/// Si la imagen de referencia no puede clasificarse (p. ej. es un icono y no
/// una foto de mano), se relaja a "cualquier gesto claro" (prueba de vida)
/// para no bloquear al usuario. Si el modelo no corre en absoluto, se falla
/// abierto y deja que la verificación facial decida.
///
/// Usa [HandDetector] (MediaPipe/LiteRT, paquete `hand_detection`), válido en
/// Android/iOS. En web se omite porque el rostro ya se delega al servidor.
class ReconocimientoGestoServicio {
  ReconocimientoGestoServicio._();

  /// Confianza mínima para considerar que un gesto es válido.
  static const double _umbral = 0.7;

  /// Devuelve el primer gesto claro detectado en [bytes], o `null`.
  static String? _primerGesto(List<Hand> hands) {
    for (final hand in hands) {
      if (hand.hasGesture && hand.gesture != null &&
          hand.gesture!.confidence >= _umbral) {
        return hand.gesture!.type.name;
      }
    }
    return null;
  }

  /// Carga los bytes de un asset (imagen de referencia).
  static Future<Uint8List> _assetBytes(String ruta) async {
    final data = await rootBundle.load(ruta);
    return data.buffer.asUint8List();
  }

  /// Compara el gesto de [selfie] con el de la imagen mostrada en
  /// [referenciaRuta] (ruta de asset, p. ej. `assets/images/gestos/gesto1.png`).
  static Future<ResultadoGesto> verificarGesto({
    required File selfie,
    required String referenciaRuta,
  }) async {
    if (kIsWeb) {
      return const ResultadoGesto(
        exito: true,
        mensaje: 'Reconocimiento de gesto omitido en web.',
      );
    }

    HandDetector? detector;
    try {
      detector = HandDetector();
      await detector.initialize(
        enableGestures: true,
        gestureMinConfidence: _umbral,
      );

      // 1) Gesto esperado: el de la imagen mostrada al usuario.
      final refBytes = await _assetBytes(referenciaRuta);
      final esperado = _primerGesto(await detector.detect(refBytes));

      // 2) Gesto detectado en la selfie del usuario.
      final manosSelfie = await detector.detectFromFilepath(selfie.path);
      final detectado = _primerGesto(manosSelfie);

      if (detectado == null) {
        return ResultadoGesto(
          exito: false,
          gestoEsperado: esperado,
          mensaje: 'No se detectó un gesto claro en tu foto. Imita el gesto '
              'mostrado con la mano bien visible y toma la foto de frente.',
        );
      }

      // 3) Si la referencia no se pudo clasificar, exigimos al menos un gesto
      //    claro (prueba de vida) para no bloquear al usuario.
      if (esperado == null) {
        return ResultadoGesto(
          exito: true,
          gestoDetectado: detectado,
          confianza: _confianzaDe(manosSelfie, detectado),
          mensaje: 'Gesto detectado: $detectado.',
        );
      }

      if (detectado == esperado) {
        return ResultadoGesto(
          exito: true,
          gestoEsperado: esperado,
          gestoDetectado: detectado,
          confianza: _confianzaDe(manosSelfie, detectado),
          mensaje: 'Gesto correcto: $detectado.',
        );
      }

      return ResultadoGesto(
        exito: false,
        gestoEsperado: esperado,
        gestoDetectado: detectado,
        mensaje: 'El gesto de tu foto ($detectado) no coincide con el que te '
            'mostramos ($esperado). Imita el gesto de la imagen y vuelve a '
            'intentarlo.',
      );
    } catch (_) {
      return const ResultadoGesto(
        exito: true,
        mensaje: 'No se pudo analizar el gesto; se continuó con la verificación '
            'facial.',
      );
    } finally {
      await detector?.dispose();
    }
  }

  /// Recupera la confianza del gesto [tipo] dentro de [manos].
  static double? _confianzaDe(List<Hand> manos, String tipo) {
    for (final hand in manos) {
      if (hand.hasGesture &&
          hand.gesture != null &&
          hand.gesture!.type.name == tipo) {
        return hand.gesture!.confidence;
      }
    }
    return null;
  }
}
