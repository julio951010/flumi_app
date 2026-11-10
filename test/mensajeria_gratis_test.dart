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

    test('la migración existe y replica el flag y el trigger', () {
      final migracion = File('supabase_migration_chat_gratis.sql');
      expect(migracion.existsSync(), isTrue);
      final sql = migracion.readAsStringSync();
      expect(sql, contains("'mensajes_requieren_plus', 'false'"));
      expect(sql, contains('function public.validar_envio_mensaje('));
      expect(sql, contains('No hay match'));
    });

    test('Premium puede escribir sin match (excepción del servidor)', () {
      expect(
        schema,
        contains("public.plan_efectivo(new.emisor_id) <> 'premium'"),
      );
      expect(schema, contains("raise exception 'No hay match'"));
    });

    test('el receptor puede responder aunque no sea Premium', () {
      expect(schema, contains('from public.messages prev'));
      expect(schema, contains('prev.emisor_id = new.receptor_id'));
      expect(schema, contains('prev.receptor_id = new.emisor_id'));
    });

    test('los planes anuncian el chat sin match de Premium', () {
      expect(
        File('lib/features/perfiles/pantallas/detalle_plan_pantalla.dart')
            .readAsStringSync(),
        contains('sin necesidad de match'),
      );
      expect(
        File(
                'lib/features/configuracion/pantallas/administrar_suscripcion_pantalla.dart')
            .readAsStringSync(),
        contains('sin necesidad de match'),
      );
    });
  });
}
