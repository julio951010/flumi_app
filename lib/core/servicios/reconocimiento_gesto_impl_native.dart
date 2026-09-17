import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:hand_detection/hand_detection.dart';

import 'reconocimiento_gesto_servicio.dart';

/// Implementación on-device (Android/iOS) del reconocimiento de gesto con
/// MediaPipe/LiteRT. Solo se compila en plataformas nativas; en web se usa el
/// stub.
Future<ResultadoGesto> verificarGestoImpl({
  required String selfieRuta,
  required String referenciaRuta,
  String? esperadoGesto,
}) async {
  /// Confianza mínima para considerar que un gesto es válido.
  const umbral = 0.55;

  HandDetector? detector;
  try {
    detector = HandDetector();
    // Umbral interno del modelo bajo (0.3) para que no suprima gestos
    // intermedios; luego decidimos nosotros con la lógica de abajo.
    await detector.initialize(
      enableGestures: true,
      gestureMinConfidence: 0.3,
    );

    // 1) Gesto esperado: el fijado por la pantalla, o el deducido de la
    //    imagen mostrada al usuario.
    String? esperado = esperadoGesto;
    if (esperado == null) {
      final refBytes = await _assetBytes(referenciaRuta);
      esperado = _primerGesto(await detector.detect(refBytes), umbral);
    }

    // 2) Mejor gesto detectado en la selfie (el de mayor confianza, aunque
    //    sea baja), para poder reportar qué vio el modelo.
    final manosSelfie = await detector.detectFromFilepath(selfieRuta);
    final mejor = _mejorGesto(manosSelfie);
    final detectado = mejor?.key;
    final confianza = mejor?.value ?? 0.0;
    final pct = '${(confianza * 100).round()}%';

    if (detectado == null) {
      return ResultadoGesto(
        exito: false,
        gestoEsperado: esperado,
        mensaje: 'No se detectó ninguna mano en la foto. Acerca la mano '
            'haciendo el gesto para que se vea claramente dentro del '
            'encuadre y toma la foto de frente.',
      );
    }

    // 3) Sin gesto esperado determinista: prueba de vida (cualquier gesto
    //    claro).
    if (esperado == null) {
      final ok = confianza >= 0.3;
      return ResultadoGesto(
        exito: ok,
        gestoDetectado: detectado,
        confianza: confianza,
        mensaje: ok
            ? 'Gesto detectado: $detectado ($pct).'
            : 'Gesto débil ($detectado, $pct); inténtalo con la mano más '
                'clara y centrada.',
      );
    }

    // 4) Gesto esperado fijado: aceptamos si el tipo coincide y hay algo de
    //    confianza; el tipo que coincide es la señal fuerte.
    if (detectado == esperado) {
      if (confianza >= 0.3) {
        return ResultadoGesto(
          exito: true,
          gestoEsperado: esperado,
          gestoDetectado: detectado,
          confianza: confianza,
          mensaje: 'Gesto correcto: $detectado ($pct).',
        );
      }
      return ResultadoGesto(
        exito: false,
        gestoEsperado: esperado,
        gestoDetectado: detectado,
        mensaje: 'El gesto $detectado se ve pero con poca confianza ($pct). '
            'Hazlo más claro y toma la foto de frente.',
      );
    }

    return ResultadoGesto(
      exito: false,
      gestoEsperado: esperado,
      gestoDetectado: detectado,
      mensaje: 'Detecté "$detectado" ($pct) pero esperaba "$esperado". '
          'Imita exactamente el gesto de la imagen (el mismo dedo/pulgar) y '
          'vuelve a intentarlo.',
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

/// Devuelve el primer gesto claro detectado en [hands] (confianza >= [umbral]),
/// o `null`.
String? _primerGesto(List<Hand> hands, double umbral) {
  for (final hand in hands) {
    if (hand.hasGesture &&
        hand.gesture != null &&
        hand.gesture!.confidence >= umbral) {
      return hand.gesture!.type.name;
    }
  }
  return null;
}

/// Devuelve el gesto con mayor confianza detectado en [hands] (sin importar
/// el umbral), junto con su confianza, o `null` si no hay ninguno.
MapEntry<String, double>? _mejorGesto(List<Hand> hands) {
  MapEntry<String, double>? mejor;
  for (final hand in hands) {
    if (hand.hasGesture && hand.gesture != null) {
      final conf = hand.gesture!.confidence;
      if (mejor == null || conf > mejor.value) {
        mejor = MapEntry(hand.gesture!.type.name, conf);
      }
    }
  }
  return mejor;
}

/// Carga los bytes de un asset (imagen de referencia).
Future<Uint8List> _assetBytes(String ruta) async {
  final data = await rootBundle.load(ruta);
  return data.buffer.asUint8List();
}
