import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

/// Actualización vía Google Play In-App Update API.
///
/// SOLO funciona si la app está publicada en Play Store. En sideload (Cuba)
/// no hace nada. Se deja como opción futura: basta con activar
/// [habilitado] = true y publicar en Play Store.
class ActualizadorPlayServicio {
  ActualizadorPlayServicio._();
  static final ActualizadorPlayServicio instancia = ActualizadorPlayServicio._();

  /// Activar solo cuando la app esté en Play Store.
  bool habilitado = false;

  Future<void> comprobarYActualizar(BuildContext context) async {
    if (!habilitado || kIsWeb) return;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        } else if (info.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (_) {
      // No estamos en Play Store o no hay update: silencioso.
    }
  }
}
