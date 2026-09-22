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
Future<void> notificarNavegador(String titulo, String cuerpo) async {
  try {
    if (html.Notification.permission != 'granted') return;
    final icono = await _obtenerIconoUrl();
    html.Notification(
      titulo,
      body: cuerpo,
      tag: 'flumi-notif',
      icon: icono,
    );
  } catch (_) {}
}

/// No aplica en web: el navegador gestiona sus propias notificaciones.
Future<void> inicializarPush() async {}

Future<void> registrarTokenPush() async {}

Future<void> eliminarTokenPush() async {}

void setNotificacionTapHandler(void Function(dynamic) _) {}
void setNotifTapHandler(void Function(dynamic) _) {}