// Opciones de Firebase generadas a mano desde android/app/google-services.json
// (equivalente a `flutterfire configure`; evita depender del plugin Gradle
// com.google.gms.google-services). Si cambias de proyecto Firebase,
// actualiza estos valores con los del nuevo google-services.json.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;

/// Opciones de Firebase para las plataformas soportadas.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions no está configurado para web: '
        'las notificaciones web usan la Notification API del navegador.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions: falta el GoogleService-Info.plist de iOS.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions no soportado en esta plataforma.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAOvhLaqVctrE5gUGhz4kYE8rmrPVEa5oY',
    appId: '1:629098605972:android:dd0299a8338607552df381',
    messagingSenderId: '629098605972',
    projectId: 'flumi-app',
    storageBucket: 'flumi-app.firebasestorage.app',
  );
}
