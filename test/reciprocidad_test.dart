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

  group('Preferencia de género ("¿A quién quieres conocer?")', () {
    test('solo se ofrecen opciones con reciprocidad real', () {
      final etiquetas =
          File('lib/features/perfiles/perfil_etiquetas.dart').readAsStringSync();
      final bloque = etiquetas.substring(
        etiquetas.indexOf('const opcionesBuscaGenero'),
        etiquetas.indexOf('const opcionesGenero'),
      );
      expect(bloque, contains("'hombres'"));
      expect(bloque, contains("'mujeres'"));
      expect(bloque, contains("'no_binarias'"));
      expect(bloque, contains("'todos'"));
      // El comodín encubierto se retiró: abría la visibilidad al máximo.
      expect(bloque.contains('prefiero_no_decirlo'), isFalse);
    });

    test('los valores retirados se muestran como "Todos/as"', () {
      final etiquetas =
          File('lib/features/perfiles/perfil_etiquetas.dart').readAsStringSync();
      final legacy = etiquetas.substring(
        etiquetas.indexOf('const _buscaGeneroLegacy'),
        etiquetas.indexOf('String buscaGeneroTexto'),
      );
      expect(legacy, contains("'otro': '\\ud83c\\udf08 Todos/as'"));
      expect(
        legacy,
        contains("'prefiero_no_decirlo': '\\ud83c\\udf08 Todos/as'"),
      );
    });

    test('la migración de datos normaliza los valores retirados', () {
      final migracion = File('supabase_migration_genero_prefiero.sql');
      expect(migracion.existsSync(), isTrue);
      final sql = migracion.readAsStringSync();
      expect(sql, contains("set busca_genero = 'todos'"));
      expect(sql, contains("'prefiero_no_decirlo'"));
      expect(sql, contains("'otro'"));
      expect(
        File('supabase/schema.sql').readAsStringSync(),
        contains("set busca_genero = 'todos'"),
      );
    });

    test('el onboarding ya no ofrece la opción', () {
      expect(
        File(
                'lib/features/onboarding/pantallas/widgets/busca_genero_opcion.dart')
            .readAsStringSync()
            .contains('codigoPrefieroNoDecir'),
        isFalse,
      );
    });
  });

  group('Género obligatorio', () {
    final schema = File('supabase/schema.sql').readAsStringSync();

    test('el servidor no deja borrar un género ya definido', () {
      expect(schema, contains('function public.validar_genero_perfil('));
      expect(schema, contains("raise exception 'El genero no puede quedar vacio'"));
      expect(schema, contains('before update on public.profiles'));
    });

    test('sin género el perfil es invisible (motivo del bloqueo)', () {
      // cumple_genero nunca coincide con un género vacío: no es un bug, es la
      // razón por la que el dato pasa a ser obligatorio.
      expect(
        schema,
        contains("then normalizar_genero(genero) in ('mujer', 'mujertrans')"),
      );
    });

    test('la app bloquea el acceso hasta completar el género', () {
      expect(
        File('lib/features/onboarding/pantallas/genero_obligatorio_pantalla.dart')
            .existsSync(),
        isTrue,
      );
      final main = File('lib/main.dart').readAsStringSync();
      expect(main, contains('_requiereGenero'));
      expect(main, contains('GeneroObligatorioPantalla('));
      expect(main, contains('_sinGenero'));
    });

    test('el porcentaje de perfil cuenta el género', () {
      expect(
        File('lib/features/perfiles/perfil_completado.dart').readAsStringSync(),
        contains('p.genero.trim().isNotEmpty'),
      );
    });

    test('la migración y el diagnóstico existen', () {
      final migracion = File('supabase_migration_genero_obligatorio.sql');
      expect(migracion.existsSync(), isTrue);
      expect(
        migracion.readAsStringSync(),
        contains('function public.validar_genero_perfil('),
      );
      final diagnostico = File('supabase_diagnostico_feed.sql');
      expect(diagnostico.existsSync(), isTrue);
      expect(diagnostico.readAsStringSync(), contains('public.perfiles_cercanos('));
    });
  });
}
