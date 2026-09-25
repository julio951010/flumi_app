import 'dart:async';

import 'package:flutter/material.dart';

import '../utilidades/notificacion_navegador.dart';

/// Servicio que decide si mostrar notificación local (app en foreground)
/// o dejar que llegue por push (app en background/cerrada).
class NotificacionLocalServicio with WidgetsBindingObserver {
  static final NotificacionLocalServicio _instancia =
      NotificacionLocalServicio._();
  static NotificacionLocalServicio get instancia => _instancia;
  NotificacionLocalServicio._();

  AppLifecycleState? _estadoVida;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _estadoVida = state;
  }

  /// Indica si la app está en primer plano y visible para el usuario.
  bool get _enPrimerPlano =>
      _estadoVida == AppLifecycleState.resumed;

  /// Inicializa el listener de ciclo de vida.
  void inicializar() {
    WidgetsBinding.instance.addObserver(this);
    _estadoVida = WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
  }

  /// Muestra notificación local si la app está en primer plano;
  /// si no, no hace nada (se espera que llegue por push FCM).
  Future<void> mostrarSiEnPrimerPlano({
    required String titulo,
    required String cuerpo,
    String? payload,
  }) async {
    if (!_enPrimerPlano) return; // Dejamos que FCM lo maneje
    await notificarNavegador(titulo, cuerpo);
  }

  /// Versión completa con payload opcional para navegación.
  Future<void> mostrarConPayload({
    required String titulo,
    required String cuerpo,
    String? payload,
  }) async {
    if (!_enPrimerPlano) return;
    await notificarNavegador(
      titulo,
      cuerpo,
    );
  }

  /// Lógica corregida: el push del destinatario NO depende del estado del
  /// emisor. El servidor (triggers enviar_push_pg) ya envía push a TODOS los
  /// destinatarios en background/cerrado para mensajes, likes, visitas y
  /// matches. Esta función solo decide qué mostrar *en el emisor* si está en
  /// foreground (feedback local). Nunca dispara RPC enviar_push_pg desde el
  /// cliente: evita duplicados y evita que el push dependa de que el emisor
  /// esté en background.
  Future<void> notificarInteligente({
    required String titulo,
    required String cuerpo,
    required String usuarioIdDestino,
    String? categoria, // 'mensajes', 'matches', 'lesGusto', 'visitas', etc.
    String? payload,
  }) async {
    // El push real lo hacen los triggers de la BD (schema.sql) en el
    // destinatario. Aquí solo mostramos local si *el emisor* está en
    // foreground (feedback inmediato) y si no, no hacemos nada.
    if (_enPrimerPlano) {
      await notificarNavegador(titulo, cuerpo);
    }
    // No llamar a enviar_push_pg desde el cliente: el servidor ya lo hace.
  }

  /// Compat: alias del método corregido.
  Future<void> notificarInteligenteLegacy({
    required String titulo,
    required String cuerpo,
    required String usuarioIdDestino,
    String? categoria,
    String? payload,
  }) =>
      notificarInteligente(
        titulo: titulo,
        cuerpo: cuerpo,
        usuarioIdDestino: usuarioIdDestino,
        categoria: categoria,
        payload: payload,
      );
}