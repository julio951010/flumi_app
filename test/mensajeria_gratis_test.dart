import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El chat se desacopla del sistema de suscripciones con el flag
/// `mensajes_requieren_plus`. Por defecto (`false`) el chat es gratis para
/// todos; `true` vuelve al comportamiento anterior (solo Plus/Premium).
void main() {
  group('Chat gratis (flag mensajes_requieren_plus)', () {
    final schema = File('supabase/schema.sql').readAsStringSync();

    test('la semilla crea el flag por defecto en false', () {
      expect(
        schema,
        contains("('mensajes_requieren_plus', 'false', 'feature')"),
      );
    });

    test('el trigger exige plan solo cuando el flag está activo', () {
      expect(schema, contains("where clave = 'mensajes_requieren_plus'"));
      expect(schema, contains("lower(valor) = 'true'"));
      expect(
        schema,
        contains("public.plan_efectivo(new.emisor_id) = 'gratis'"),
      );
    });

    test('el match obligatorio no se relaja con el flag', () {
      expect(schema, contains("raise exception 'No hay match'"));
    });

    test('filtrosMensajes (feature fantasma) ya no existe en Flutter', () {
      final dart = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.readAsStringSync())
          .join('\n');
      expect(dart.contains('filtrosMensajes'), isFalse);
    });

    test('la migración existe y replica el flag, la tabla y el trigger', () {
      final migracion = File('supabase_migration_chat_gratis.sql');
      expect(migracion.existsSync(), isTrue);
      final sql = migracion.readAsStringSync();
      expect(sql, contains("'mensajes_requieren_plus', 'false'"));
      expect(sql, contains('function public.validar_envio_mensaje('));
      expect(sql, contains('No hay match'));
      expect(sql, contains('create table if not exists public.chat_solicitudes'));
      expect(sql, contains("'limite_solicitudes_chat_diarias'"));
    });

    test('Premium puede escribir sin match (excepción del servidor)', () {
      expect(
        schema,
        contains("public.plan_efectivo(new.emisor_id) <> 'premium'"),
      );
      expect(schema, contains("raise exception 'No hay match'"));
    });

    test('los planes anuncian las solicitudes de chat de Premium', () {
      expect(
        File('lib/features/perfiles/pantallas/detalle_plan_pantalla.dart')
            .readAsStringSync(),
        contains('Solicitudes de chat sin match'),
      );
      expect(
        File(
                'lib/features/configuracion/pantallas/administrar_suscripcion_pantalla.dart')
            .readAsStringSync(),
        contains('Solicitudes de chat sin match'),
      );
    });
  });

  group('Solicitudes de chat sin match (freno anti-spam)', () {
    final schema = File('supabase/schema.sql').readAsStringSync();

    test('existe la tabla de solicitudes con decisión del receptor', () {
      expect(
        schema,
        contains('create table if not exists public.chat_solicitudes'),
      );
      expect(schema, contains("check (estado in ('pendiente', 'aceptada', 'rechazada'))"));
      expect(schema, contains('receptor_responde_su_solicitud'));
    });

    test('el cliente no puede insertar solicitudes (tope no se salta)', () {
      // Solo hay políticas de SELECT y de UPDATE del receptor: el INSERT lo
      // hace el trigger security definer, no la API.
      final bloque = schema.substring(
        schema.indexOf('create table if not exists public.chat_solicitudes'),
        schema.indexOf(
            'drop policy if exists "matches_visibles_solo_para_participantes"'),
      );
      expect(bloque.contains('for insert'), isFalse);
      expect(bloque.contains('for select'), isTrue);
      expect(bloque.contains('for update'), isTrue);
    });

    test('hay tope diario configurable y error propio', () {
      expect(
        schema,
        contains("('limite_solicitudes_chat_diarias', '5', 'feature')"),
      );
      expect(schema, contains("clave = 'limite_solicitudes_chat_diarias'"));
      expect(
        schema,
        contains("raise exception 'Alcanzaste el limite de solicitudes de hoy'"),
      );
    });

    test('mientras está pendiente nadie más escribe en el hilo', () {
      expect(schema, contains("elsif v_sol.estado = 'pendiente'"));
      expect(
        schema,
        contains("raise exception 'Solicitud pendiente de aceptacion'"),
      );
    });

    test('descartada bloquea al emisor para siempre', () {
      expect(schema, contains("elsif v_sol.estado = 'rechazada'"));
      expect(schema, contains("raise exception 'Solicitud rechazada'"));
    });

    test('la UI tiene aceptar/descartar y filtra las pendientes', () {
      final chats =
          File('lib/features/chat/pantallas/chats_pantalla.dart').readAsStringSync();
      expect(chats, contains('responderSolicitud'));
      expect(chats, contains("'Aceptar'"));
      expect(chats, contains("'Descartar'"));
      expect(chats, contains('observarSolicitudesPendientes'));

      final repo = File('lib/features/chat/chat_repositorio.dart').readAsStringSync();
      expect(repo, contains("if (!sol.enviada && sol.estado != 'aceptada') continue;"));
    });

    test('el chat bloquea la entrada según la solicitud', () {
      final chat =
          File('lib/features/chat/pantallas/chat_pantalla.dart').readAsStringSync();
      expect(chat, contains('_bloqueoSolicitud'));
      expect(chat, contains('Esperando a que acepte tu solicitud'));
      expect(chat, contains('Acepta la solicitud en Chats para responder'));
    });
  });
}
