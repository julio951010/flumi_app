import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../config/env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utilidades/notificacion_navegador.dart';

/// Servicio que decide si mostrar notificación local (app en foreground)
/// o dejar que llegue por push (app en background/cerrada).
class NotificacionLocalServicio with WidgetsBindingObserver {
  static final NotificacionLocalServicio _instancia =
      NotificacionLocalServicio._();
  static NotificacionLocalServicio get instancia => _instancia;
  NotificacionLocalServicio._();

  AppLifecycleState? _estadoVida;
  StreamSubscription<AppLifecycleState>? _subVida;

  /// Inicializa el listener de ciclo de vida.
  void inicializar() {
    WidgetsBinding.instance.addObserver(this);
    _estadoVida = WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _estadoVida = state;
  }

  /// Indica si la app está en primer plano y visible para el usuario.
  bool get _enPrimerPlano =>
      _estadoVida == AppLifecycleState.resumed;

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

  /// Lógica completa: si app en foreground -> notificación local;
  /// si no, dispara push vía Supabase RPC.
  Future<void> notificarInteligente({
    required String titulo,
    required String cuerpo,
    required String usuarioIdDestino,
    String? categoria, // 'mensajes', 'matches', 'lesGusto', 'visitas', etc.
    String? payload,
  }) async {
    if (_enPrimerPlano) {
      // App en foreground -> notificación local instantánea
      await notificarNavegador(titulo, cuerpo);
      return;
    }

    // App en background/cerrada -> disparar push via Supabase RPC
    if (!kUsarServidorLocal) {
      try {
        await Supabase.instance.client.rpc('enviar_push_pg', params: {
          'usuario_id': usuarioIdDestino,
          'titulo': titulo,
          'cuerpo': cuerpo,
          'categoria': categoria ?? 'mensajes',
        });
      } catch (_) {
        // Fallback: si falla el push, al menos mostramos local si estamos en foreground
        if (_enPrimerPlano) {
          await notificarNavegador(titulo, cuerpo);
        }
      }
    }
  }
}