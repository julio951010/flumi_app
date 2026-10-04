import 'dart:html' as html;

import 'package:flutter/services.dart' show rootBundle;

/// Pide permiso para mostrar notificaciones del navegador (web).
/// En navegadores que lo exigen, el permiso se concede con gesto de usuario.
Future<bool> solicitarPermisoNotificaciones() async {
  try {
    if (html.Notification.permission == 'granted') return true;
    final estado = await html.Notification.requestPermission();
    return estado == 'granted';
  } catch (_) {
    return false;
  }
}

String? _iconoUrl;

/// Carga el logo de la app una sola vez y lo expone como blob URL, que es
/// la única forma fiable de que el navegador muestre un asset local en la
/// notificación (rutas relativas dependen de cómo se sirva la web).
Future<String?> _obtenerIconoUrl() async {
  if (_iconoUrl != null) return _iconoUrl;
  try {
    final data = await rootBundle.load('assets/images/flumi_logo.png');
    _iconoUrl = html.Url.createObjectUrlFromBlob(
        html.Blob([data.buffer.asUint8List()], 'image/png'));
    return _iconoUrl;
  } catch (_) {
    return null;
  }
}

/// Muestra una notificación del navegador siempre que el permiso esté
/// concedido, esté o no la pestaña enfocada: el usuario quiere enterarse de
/// likes, visitas y matches aunque esté mirando otra pestaña del navegador.
/// Sin título: solo cuerpo con la foto del remitente (o el logo de la app).
/// El tap navega a la sección (ver routing en main).
Future<void> notificarNavegador(String titulo, String cuerpo,
    {String? fotoUrl, String? categoria}) async {
  try {
    if (html.Notification.permission != 'granted') return;
    final icono = (fotoUrl != null && fotoUrl.startsWith('http'))
        ? fotoUrl
        : await _obtenerIconoUrl();
    final notif = html.Notification(
      '',
      body: cuerpo,
      tag: 'flumi-notif',
      icon: icono,
    );
    final cat = categoria;
    if (cat != null && cat.isNotEmpty) {
      notif.onClick.listen((_) {
        try {
          _onLocalTap?.call(cat);
        } catch (_) {}
      });
    }
  } catch (_) {}
}

/// Tap en notificaciones locales web → navega por categoría.
void Function(String)? _onLocalTap;

void setNotificacionLocalTapHandler(void Function(String) cb) =>
    _onLocalTap = cb;

/// No aplica en web: el navegador gestiona sus propias notificaciones.
Future<void> inicializarPushCritico() async {}

Future<void> inicializarPush() async {}

Future<void> registrarTokenPush() async {}

Future<void> forzarRegistroPush() async {}

Future<void> eliminarTokenPush() async {}

/// null = aún no se pidió el permiso; true/false = concedido/denegado.
bool? get notificacionesPermitidas {
  switch (html.Notification.permission) {
    case 'granted':
      return true;
    case 'denied':
      return false;
    default:
      return null;
  }
}

void setNotificacionTapHandler(void Function(dynamic) _) {}
void setNotifTapHandler(void Function(dynamic) _) {}