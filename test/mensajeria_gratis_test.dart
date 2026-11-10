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

    test('no se promete chatear sin match (el servidor lo exige)', () {
      for (final ruta in [
        'lib/features/encuentros/pantallas/me_gusta_pantalla.dart',
        'lib/features/encuentros/pantallas/encuentros_pantalla.dart',
        'lib/features/encuentros/pantallas/cerca_de_ti_pantalla.dart',
        'lib/features/perfiles/pantallas/detalle_plan_pantalla.dart',
        'lib/features/configuracion/pantallas/administrar_suscripcion_pantalla.dart',
      ]) {
        expect(
          File(ruta).readAsStringSync().contains('sin necesidad de match'),
          isFalse,
          reason: 'Promesa falsa en $ruta',
        );
      }
    });
  });
}
