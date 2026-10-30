import 'dart:ui';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import '../utilidades/app_log.dart';

/// Firebase Analytics + Crashlytics.
///
/// Todo es best-effort: si Firebase no está configurado (por ejemplo en
/// escritorio o sin google-services.json), la app sigue funcionando.
class AnalyticsServicio {
  AnalyticsServicio._();

  static bool _listo = false;
  static bool _inicializando = false;

  static FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;
  static FirebaseCrashlytics get _crashlytics =>
      FirebaseCrashlytics.instance;

  static Future<void> inicializar() async {
    if (_listo || _inicializando) return;
    _inicializando = true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      await _analytics.setAnalyticsCollectionEnabled(true);
      await _crashlytics.setCrashlyticsCollectionEnabled(true);

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        _crashlytics.recordFlutterFatalError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        _crashlytics.recordError(error, stack, fatal: true);
        appLog('[Crashlytics] Error no capturado: $error');
        return true;
      };

      _listo = true;
      appLog('[Analytics] Firebase Analytics/Crashlytics listos');
    } catch (e) {
      appLog('[Analytics] No disponible: $e');
    } finally {
      _inicializando = false;
    }
  }

  static Future<void> logEvent(
    String nombre, [
    Map<String, Object>? parametros,
  ]) async {
    if (!_listo) return;
    try {
      await _analytics.logEvent(
        name: nombre,
        parameters: parametros,
      );
    } catch (e) {
      appLog('[Analytics] logEvent($nombre) falló: $e');
    }
  }

  static Future<void> logAppOpen() => logEvent('app_inicio');

  static Future<void> logLogin(String metodo) =>
      logEvent('login', {'method': metodo});

  static Future<void> logSignUp(String metodo) =>
      logEvent('sign_up', {'method': metodo});

  static Future<void> setUserId(String? id) async {
    if (!_listo) return;
    try {
      await _analytics.setUserId(id: id);
      await _crashlytics.setUserIdentifier(id ?? '');
    } catch (_) {}
  }

  static Future<void> registrarError(
    Object error,
    StackTrace stack, {
    bool fatal = false,
  }) async {
    if (!_listo) return;
    try {
      await _crashlytics.recordError(error, stack, fatal: fatal);
    } catch (_) {}
  }
}
