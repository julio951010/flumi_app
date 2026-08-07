import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drift/native.dart';

import 'package:Flumi/core/base_datos_local/database.dart';
import 'package:Flumi/features/configuracion/pantallas/informacion_basica_pantalla.dart';
import 'package:Flumi/features/onboarding/pantallas/cuestionario_perfil_pantalla.dart';
import 'package:Flumi/features/perfiles/pantallas/subpaginas_perfil.dart';
import 'package:Flumi/features/perfiles/perfil_repositorio.dart';

Future<void> _cargarFuentes() async {
  final loader = FontLoader('Roboto');
  for (final nombre in ['roboto-regular.ttf', 'roboto-bold.ttf']) {
    final bytes = File('test/fonts/$nombre').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

class _FakeRepositorio extends PerfilRepositorio {
  _FakeRepositorio() : super(AppDatabase(NativeDatabase.memory()));

  @override
  Future<Usuario?> obtenerPerfilPropio() async => null;

  @override
  Future<void> guardarOCambiarPerfil(UsuariosCompanion perfil) async {}
}

final _tamDimensiones = <Size>[
  const Size(320, 568),
  const Size(360, 640),
  const Size(414, 896),
];

Future<void> _ponerTamano(WidgetTester tester, Size tamanio) async {
  tester.view.physicalSize = tamanio;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _comprobarSinDesborde(
  WidgetTester tester,
  Widget widget,
  String nombre,
) async {
  await tester.pumpWidget(MaterialApp(home: widget));
  await tester.pumpAndSettle();
  expect(
    tester.takeException(),
    isNull,
    reason: '$nombre se desbordó',
  );
}

void main() {
  setUpAll(_cargarFuentes);

  final fabricas = <(String, Widget Function())>[
    ('Orientación sexual', () => OrientacionSexualPantalla(repositorio: _FakeRepositorio())),
    ('Situación sentimental', () => SituacionSentimentalPantalla(repositorio: _FakeRepositorio())),
    ('Nivel educativo', () => NivelEducativoPantalla(repositorio: _FakeRepositorio())),
    ('Trabajo', () => TrabajoPantalla(repositorio: _FakeRepositorio())),
    ('Hijos', () => HijosPantalla(repositorio: _FakeRepositorio())),
    ('Tabaco', () => TabacoPantalla(repositorio: _FakeRepositorio())),
    ('Alcohol', () => AlcoholPantalla(repositorio: _FakeRepositorio())),
    ('Mascotas', () => MascotasPantalla(repositorio: _FakeRepositorio())),
    ('Religión', () => ReligionPantalla(repositorio: _FakeRepositorio())),
    ('Tatuajes', () => TatuajesPantalla(repositorio: _FakeRepositorio())),
    ('Estatura', () => EstaturaPantalla(repositorio: _FakeRepositorio())),
    ('Signo zodiacal', () => SignoZodiacalPantalla(repositorio: _FakeRepositorio())),
    ('Profesión', () => ProfesionPantalla(repositorio: _FakeRepositorio())),
    ('Idiomas', () => IdiomasPantalla(repositorio: _FakeRepositorio())),
    ('Qué busca', () => QueBuscaPantalla(repositorio: _FakeRepositorio())),
    ('Quiero conocer', () => QuieroConocerPantalla(repositorio: _FakeRepositorio())),
    ('Rango de edad', () => RangoEdadPantalla(repositorio: _FakeRepositorio())),
    ('Intereses', () => InteresesPerfilPantalla(repositorio: _FakeRepositorio())),
    ('Personalidad', () => PersonalidadPantalla(repositorio: _FakeRepositorio())),
    ('Sobre mí', () => SobreMiPantalla(repositorio: _FakeRepositorio())),
    ('Preguntas', () => PreguntasPantalla(repositorio: _FakeRepositorio())),
    ('Fecha de nacimiento', () => ActualizarFechaPantalla(repositorio: _FakeRepositorio())),
  ];

  for (final nombre in _tamDimensiones) {
    testWidgets('Editar: $nombre sin desbordes', (tester) async {
      for (final fabrica in fabricas) {
        await _ponerTamano(tester, nombre);
        await _comprobarSinDesborde(tester, fabrica.$2(), fabrica.$1);
      }
    });
  }

  testWidgets('Cuestionario perfil no se desborda en todos los pasos',
      (tester) async {
    for (final size in _tamDimensiones) {
      final db = AppDatabase(NativeDatabase.memory());
      await db.into(db.usuarios).insert(UsuariosCompanion.insert(
            uuid: 'u1',
            nombre: 'Ana',
            edad: 30,
            genero: 'Mujer',
            buscaGenero: 'Hombre',
          ));
      await _ponerTamano(tester, size);

      int saltos = 0;
      bool listo = false;
      var aviso = '';
      final db2 = db;
      await tester.pumpWidget(MaterialApp(
        home: CuestionarioPerfilPantalla(
            db: db2,
            usuarioUuid: 'u1',
            onCompletado: () => listo = true),
      ));
      await tester.pumpAndSettle();

      while (saltos < 25) {
        final comenzar = find.text('Comenzar');
        final irAlCuestionario = find.text('Ir al cuestionario');
        final siguiente = find.byIcon(Icons.arrow_forward_ios_rounded);
        if (comenzar.evaluate().isNotEmpty) {
          await tester.tap(comenzar.first);
          await tester.pump();
          break;
        } else if (irAlCuestionario.evaluate().isNotEmpty) {
          await tester.tap(irAlCuestionario.first);
        } else if (siguiente.evaluate().isNotEmpty) {
          await tester.tap(siguiente.first);
        } else {
          break;
        }
        await tester.pumpAndSettle();
        final error = tester.takeException();
        if (error != null) {
          aviso = '$error';
          break;
        }
        saltos++;
      }
      expect(listo, isTrue, reason: 'No se llegó a la pantalla final: $aviso');
      expect(tester.takeException(), isNull, reason: 'Desborde en $size');
    }
  });
}