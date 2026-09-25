import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../config/env.dart';

/// Handler de segundo plano (top-level, requerido por FCM en Android).
/// Se ejecuta en un isolate separado cuando llega un push con la app
/// cerrada o en background y el mensaje es de tipo `data`.
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage mensaje) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

/// Callback global para taps en notificaciones (foreground/background/cerrada).
/// La app lo asigna al arrancar para navegar a la bandeja/chat correspondiente.
typedef NotifTapCallback = void Function(RemoteMessage mensaje);
NotifTapCallback? _onTap;

void setNotifTapHandler(NotifTapCallback cb) => _onTap = cb;

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

  /// Fase crítica: Firebase + registro del handler de background. Se espera
  /// con `await` antes de `runApp()`: sin este registro, los push que llegan
  /// con la app cerrada no despiertan a la app. Nunca lanza.
  Future<void> inicializarCritico() async {
    try {
      await Firebase.initializeApp();
      _fcm = FirebaseMessaging.instance;
      // Background: handler top-level (data messages cuando app cerrada).
      FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);
    } catch (_) {}
  }

  /// Inicializa Firebase y los handlers de FCM. Nunca lanza: si Firebase no
  /// está configurado (falta google-services.json / GoogleService-Info.plist)
  /// la app sigue funcionando sin push.
  Future<void> inicializar() async {
    await inicializarCritico();
    final fcm = _fcm;
    if (fcm == null) {
      _disponible = false;
      return;
    }
    try {

      // Canal Android 8+ (obligatorio para background). Sin esto, los push en
      // segundo plano no suenan / no aparecen en algunos OEMs.
      const androidInit = AndroidInitializationSettings('ic_notif');
      const init = InitializationSettings(android: androidInit);
      await _locales.initialize(
        init,
        onDidReceiveNotificationResponse: (resp) {
          // Tap en notificación local (foreground) → placeholder, el FCM lleva el payload real.
        },
      );
      _mostrarLocales = true;

      // Crea el canal 'flumi' explícitamente para que los FCM en background
      // usen el mismo canal con importancia alta.
      try {
        const canal = AndroidNotificationChannel(
          'flumi',
          'Flumi',
          description: 'Mensajes, Me Gustas, visitas y matches',
          importance: Importance.high,
        );
        await _locales
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(canal);
      } catch (_) {}

      await fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Foreground: mostrar local.
      FirebaseMessaging.onMessage.listen(_mostrarMensajeFcm);
      // Tap en notificación del sistema (background / terminada).
      FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
      // App abierta desde notificación estando terminada.
      try {
        final inicial = await fcm.getInitialMessage();
        if (inicial != null) _handleTap(inicial);
      } catch (_) {}
      // Refresh token: Android lo rota periódicamente.
      fcm.onTokenRefresh.listen((nuevo) {
        _token = nuevo;
        registrarToken();
      });

      _disponible = true;
    } catch (_) {
      _disponible = false;
    }
  }

  void _handleTap(RemoteMessage mensaje) {
    try {
      _onTap?.call(mensaje);
    } catch (_) {}
  }

  Future<void> _mostrarMensajeFcm(RemoteMessage mensaje) {
    // Usa data si viene, sino notification.
    final titulo = mensaje.notification?.title ??
        mensaje.data['titulo'] ??
        'Flumi';
    final cuerpo = mensaje.notification?.body ??
        mensaje.data['cuerpo'] ??
        '';
    return notificarNavegador(titulo, cuerpo);
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
    if (token == null) return;
    // Evita spam si es el mismo, pero siempre re-registra tras refresh.
    if (token == _token) return;
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

  /// Fuerza re-registro (tras login).
  Future<void> forzarRegistro() async {
    _token = null;
    await registrarToken();
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
      const canalBase = AndroidNotificationDetails(
        'flumi',
        'Flumi',
        channelDescription: 'Mensajes, Me Gustas, visitas y matches',
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_notif',
      );
      await _locales.show(
        DateTime.now().millisecondsSinceEpoch % 100000,
        titulo,
        cuerpo,
        NotificationDetails(
          android: logo == null
              ? canalBase
              : AndroidNotificationDetails(
                  'flumi',
                  'Flumi',
                  channelDescription: 'Mensajes, Me Gustas, visitas y matches',
                  importance: Importance.high,
                  priority: Priority.high,
                  icon: 'ic_notif',
                  styleInformation: BigPictureStyleInformation(logo,
                      contentTitle: titulo, summaryText: cuerpo),
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

/// Fase crítica de push (Firebase + handler de background). Llamar con
/// `await` antes de `runApp()`.
Future<void> inicializarPushCritico() => _push.inicializarCritico();

/// Inicializa Firebase y los handlers de FCM (una sola vez al arrancar).
Future<void> inicializarPush() => _push.inicializar();

/// Registra el token FCM en Supabase (al iniciar sesión).
Future<void> registrarTokenPush() => _push.registrarToken();
Future<void> forzarRegistroPush() => _push.forzarRegistro();

/// Elimina el token FCM de Supabase (al cerrar sesión).
Future<void> eliminarTokenPush() => _push.eliminarToken();

/// Asigna handler de tap en notificación (usado por main.dart para navegar).
void setNotificacionTapHandler(NotifTapCallback cb) => setNotifTapHandler(cb);
