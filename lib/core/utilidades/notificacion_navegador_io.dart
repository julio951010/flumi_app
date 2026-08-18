import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../config/env.dart';

/// Implementación móvil (Android/iOS): push real con Firebase Cloud
/// Messaging. Las notificaciones que llegan con la app en primer plano se
/// muestran localmente (con el logo de la app); las que llegan con la app en
/// segundo plano o cerrada las muestra el sistema desde el payload FCM.
class _PushMovil {
  final FlutterLocalNotificationsPlugin _locales =
      FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _fcm;
  bool _disponible = false;
  String? _token;
  bool _mostrarLocales = false;

  /// Inicializa Firebase y los handlers de FCM. Nunca lanza: si Firebase no
  /// está configurado (falta google-services.json / GoogleService-Info.plist)
  /// la app sigue funcionando sin push.
  Future<void> inicializar() async {
    try {
      await Firebase.initializeApp();
      _fcm = FirebaseMessaging.instance;

      const androidInit = AndroidInitializationSettings('ic_launcher');
      const init = InitializationSettings(android: androidInit);
      await _locales.initialize(init);
      _mostrarLocales = true;

      await _fcm!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      _fcm!.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // App en primer plano: mostrar la notificación localmente.
      FirebaseMessaging.onMessage.listen(_mostrarMensajeFcm);
      _disponible = true;
    } catch (_) {
      _disponible = false;
    }
  }

  Future<void> _mostrarMensajeFcm(RemoteMessage mensaje) {
    return notificarNavegador(
      mensaje.notification?.title ?? 'Flumi',
      mensaje.notification?.body ?? '',
    );
  }

  Future<String?> _obtenerToken() async {
    try {
      final fcm = _fcm ?? FirebaseMessaging.instance;
      return await fcm.getToken();
    } catch (_) {
      return null;
    }
  }

  /// Pide permiso para notificaciones (Android 13+ muestra el diálogo).
  Future<bool> solicitarPermiso() async {
    try {
      await inicializar();
      return _disponible;
    } catch (_) {
      return false;
    }
  }

  /// Registra el token FCM del dispositivo en Supabase (RPC
  /// registrar_device_token). Sin conexión o sin Firebase: no hace nada.
  Future<void> registrarToken() async {
    if (kUsarServidorLocal) return;
    final token = await _obtenerToken();
    if (token == null || token == _token) return;
    _token = token;
    try {
      await sb.Supabase.instance.client.rpc(
        'registrar_device_token',
        params: {
          'p_token': token,
          'p_plataforma': Platform.isIOS ? 'ios' : 'android',
        },
      );
    } catch (_) {}
  }

  /// Elimina el token de Supabase al cerrar sesión.
  Future<void> eliminarToken() async {
    final token = _token;
    if (token == null || kUsarServidorLocal) return;
    try {
      await sb.Supabase.instance.client.rpc(
        'eliminar_device_token',
        params: {'p_token': token},
      );
    } catch (_) {}
    _token = null;
  }

  /// Notificación local inmediata con el logo de la app (primer plano).
  Future<void> mostrarLocal(String titulo, String cuerpo) async {
    if (!_mostrarLocales) return;
    try {
      ByteArrayAndroidBitmap? logo;
      try {
        final datos = await rootBundle.load('assets/images/flumi_logo.png');
        logo = ByteArrayAndroidBitmap(datos.buffer.asUint8List());
      } catch (_) {}
      const canal = AndroidNotificationDetails(
        'flumi',
        'Flumi',
        channelDescription: 'Mensajes, Me Gustas, visitas y matches',
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_launcher',
      );
      await _locales.show(
        DateTime.now().millisecondsSinceEpoch % 100000,
        titulo,
        cuerpo,
        NotificationDetails(
          android: logo == null
              ? canal
              : AndroidNotificationDetails(
                  'flumi',
                  'Flumi',
                  channelDescription: 'Mensajes, Me Gustas, visitas y matches',
                  importance: Importance.high,
                  priority: Priority.high,
                  icon: 'ic_launcher',
                  styleInformation:
                      BigPictureStyleInformation(logo, contentTitle: titulo, summaryText: cuerpo),
                ),
        ),
      );
    } catch (_) {}
  }
}

final _push = _PushMovil();

/// Pide permiso para notificaciones push (móvil).
Future<bool> solicitarPermisoNotificaciones() => _push.solicitarPermiso();

/// Muestra una notificación local con el logo de la app.
Future<void> notificarNavegador(String titulo, String cuerpo) =>
    _push.mostrarLocal(titulo, cuerpo);

/// Inicializa Firebase y los handlers de FCM (una sola vez al arrancar).
Future<void> inicializarPush() => _push.inicializar();

/// Registra el token FCM en Supabase (al iniciar sesión).
Future<void> registrarTokenPush() => _push.registrarToken();

/// Elimina el token FCM de Supabase (al cerrar sesión).
Future<void> eliminarTokenPush() => _push.eliminarToken();