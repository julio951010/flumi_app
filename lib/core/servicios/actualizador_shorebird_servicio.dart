import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// Shorebird code push: permite enviar parches de código Dart a las apps
/// ya instaladas, sin reinstalar ni mostrar diálogo.
///
/// Requiere:
///   1. Cuenta en shorebird.dev
///   2. `shorebird init` en el proyecto (genera shorebird.yaml con el appId)
///   3. Compilar con `shorebird release android` en lugar de `flutter build apk`
///   4. Publicar parches con `shorebird patch android`
///
/// Sin esos pasos, este servicio no hace nada (habilitado = false).
class ActualizadorShorebirdServicio {
  ActualizadorShorebirdServicio._();
  static final ActualizadorShorebirdServicio instancia =
      ActualizadorShorebirdServicio._();

  final _updater = ShorebirdUpdater();
  bool habilitado = true;

  /// Comprueba y descarga un parche en segundo plano. Al reiniciar la app
  /// se aplica automáticamente.
  Future<void> comprobarYParchear() async {
    if (!habilitado || kIsWeb) return;
    try {
      final status = await _updater.checkForUpdate();
      if (status == UpdateStatus.outdated) {
        await _updater.update();
      }
    } catch (_) {
      // Shorebird no configurado o sin red: silencioso.
    }
  }
}
