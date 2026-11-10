import 'dart:io';

import 'package:Flumi/core/servicios/visitas_historial_servicio.dart';
import 'package:flutter_test/flutter_test.dart';

/// La reciprocidad se aplica en Postgres (`supabase/schema.sql` y la
/// migración), pero el cliente debe entender la respuesta `no_reciproco`
/// para no contar el like ni mostrarlo como enviado.
void main() {
  group('ResultadoMeGusta', () {
    test('un like no recíproco no se marca como enviado', () {
      final r = ResultadoMeGusta.desdeJson({
        'match': false,
        'likeado': false,
        'limite': false,
        'no_reciproco': true,
      });

      expect(r.noReciproco, isTrue);
      expect(r.likeado, isFalse);
      expect(r.limite, isFalse);
      expect(r.match, isFalse);
    });

    test('la respuesta normal conserva el comportamiento anterior', () {
      final r = ResultadoMeGusta.desdeJson({
        'match': true,
        'likeado': true,
        'limite': false,
      });

      expect(r.match, isTrue);
      expect(r.likeado, isTrue);
      expect(r.noReciproco, isFalse);
    });

    test('el límite diario sigue distinguiéndose del no recíproco', () {
      final r = ResultadoMeGusta.desdeJson({
        'match': false,
        'likeado': false,
        'limite': true,
      });

      expect(r.limite, isTrue);
      expect(r.noReciproco, isFalse);
    });
  });

  group('SQL de reciprocidad', () {
    final schema = File('supabase/schema.sql').readAsStringSync();

    test('el feed exige que el otro perfil también me busque', () {
      // `busca_genero` puede ser multi-selección ('hombres,mujeres'), así que
      // la reciprocidad parsea la lista y usa cumple_genero por opción.
      expect(schema, contains('unnest(string_to_array(coalesce(p.busca_genero'));
      expect(schema, contains('public.cumple_genero(op.opcion, mi_genero)'));
      expect(schema, contains('coalesce(p.preferencia_edad_max, 99) >= mi_edad'));
      expect(schema, contains('mi_genero text'));
    });

    test('el like no recíproco se rechaza sin consumir cupo', () {
      expect(schema, contains("'no_reciproco', true"));
    });

    test('la migración existe y replica ambas funciones', () {
      final migracion = File('supabase_migration_reciprocidad.sql');
      expect(migracion.existsSync(), isTrue);
      final sql = migracion.readAsStringSync();
      expect(sql, contains('function public.perfiles_cercanos('));
      expect(sql, contains('function public.registrar_me_gusta('));
      expect(sql, contains('no_reciproco'));
    });
  });
}
