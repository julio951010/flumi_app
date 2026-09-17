import '../../core/base_datos_local/database.dart';
import 'verificacion_servicio.dart';

/// Stub web: la verificación on-device no existe en web ([dart:ffi] no está
/// disponible). Usa [VerificacionServicio.verificarPerfilWeb] en su lugar.
Future<VerificarResultado> verificarPerfilImpl({
  required Usuario perfil,
  required String rutaSelfie,
}) async {
  return VerificarResultado.error;
}
