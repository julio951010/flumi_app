import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../config/env.dart';
import '../../firebase_options.dart';

/// Handler de segundo plano (top-level, requerido por FCM en Android).
/// Se ejecuta en un isolate separado cuando llega un push con la app
/// cerrada o en background y el mensaje es de tipo `data`.
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage mensaje) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('[Push] background Firebase.init falló: $e');
  }
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
  /// Usuario para el que quedó registrado [_token] en device_tokens. El token
  /// FCM es por dispositivo (igual para todas las cuentas que lo usen): si
  /// cambia de cuenta sin reiniciar hay que re-registrar aunque el token
  /// sea el mismo, o los push del otro seguirán llegando aquí.
  String? _tokenUsuarioId;
  bool _mostrarLocales = false;
  bool _criticoOk = false;
  bool _completoOk = false;

  /// Fase crítica: Firebase + registro del handler de background. Se espera
  /// con `await` antes de `runApp()`: sin este registro, los push que llegan
  /// con la app cerrada no despiertan a la app. Nunca lanza.
  Future<void> inicializarCritico() async {
    if (_criticoOk && _fcm != null) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _fcm = FirebaseMessaging.instance;
      // Background: handler top-level (data messages cuando app cerrada).
      FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);
      _criticoOk = true;
    } catch (e) {
      debugPrint('[Push] Firebase.init falló (revisa firebase_options.dart): $e');
    }
  }

  /// Inicializa Firebase y los handlers de FCM. Nunca lanza: si Firebase no
  /// está configurado la app sigue funcionando sin push. Idempotente: una
  /// segunda llamada (p. ej. desde solicitarPermiso) no duplica listeners.
  Future<void> inicializar() async {
    await inicializarCritico();
    if (_completoOk) return;
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
      _completoOk = true;
    } catch (e) {
      debugPrint('[Push] inicializar falló: $e');
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
    } catch (e) {
      debugPrint('[Push] getToken falló: $e');
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
  /// registrar_device_token, upsert por token: reclama el token para el
  /// usuario actual). Sin conexión o sin Firebase: no hace nada (y NO marca
  /// como registrado, para reintentar en la próxima llamada).
  Future<void> registrarToken() async {
    if (kUsarServidorLocal) return;
    final token = await _obtenerToken();
    if (token == null) {
      debugPrint('[Push] sin token FCM: no se registra nada');
      return;
    }
    final miId = sb.Supabase.instance.client.auth.currentUser?.id;
    // Evita spam si ya quedó registrado este token PARA ESTE usuario.
    // Si cambió la cuenta (mismo dispositivo, otra sesión) hay que
    // re-registrar aunque el token sea idéntico.
    if (token == _token && miId != null && miId == _tokenUsuarioId) return;
    try {
      await sb.Supabase.instance.client.rpc(
        'registrar_device_token',
        params: {
          'p_token': token,
          'p_plataforma': Platform.isIOS ? 'ios' : 'android',
        },
      );
      _token = token;
      _tokenUsuarioId = miId;
      debugPrint('[Push] token registrado en device_tokens');
    } catch (e) {
      debugPrint('[Push] registrar_device_token falló: $e');
    }
  }

  /// Fuerza re-registro (tras login).
  Future<void> forzarRegistro() async {
    _token = null;
    _tokenUsuarioId = null;
    await registrarToken();
  }

  /// Elimina el token de Supabase al cerrar sesión. Debe llamarse ANTES de
  /// cerrar la sesión (con el JWT aún válido): el RPC solo borra la fila del
  /// usuario autenticado y sin sesión no borra nada.
  Future<void> eliminarToken() async {
    final token = _token ?? await _obtenerToken();
    if (token == null || kUsarServidorLocal) return;
    try {
      await sb.Supabase.instance.client.rpc(
        'eliminar_device_token',
        params: {'p_token': token},
      );
      debugPrint('[Push] token eliminado de device_tokens');
    } catch (e) {
      debugPrint('[Push] eliminar_device_token falló: $e');
    }
    _token = null;
    _tokenUsuarioId = null;
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
