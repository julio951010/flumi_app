import 'reconocimiento_gesto_servicio.dart';

/// Stub web: el reconocimiento de gesto on-device no existe en web ([dart:ffi]
/// no está disponible). Se omite y se continúa con la verificación facial.
Future<ResultadoGesto> verificarGestoImpl({
  required String selfieRuta,
  required String referenciaRuta,
  String? esperadoGesto,
}) async {
  return const ResultadoGesto(
    exito: true,
    mensaje: 'Reconocimiento de gesto omitido en web.',
  );
}
