import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drift/native.dart';

import '../lib/core/base_datos_local/database.dart';
import '../lib/features/perfiles/pantallas/subpaginas_perfil.dart';
import '../lib/features/perfiles/perfil_repositorio.dart';

class _FakeRepositorio extends PerfilRepositorio {
  _FakeRepositorio() : super(AppDatabase(NativeDatabase.memory()));

  @override
  Future<Usuario?> obtenerPerfilPropio() async => null;

  @override
  Future<void> guardarOCambiarPerfil(UsuariosCompanion perfil) async {}
}

void main() {
  testWidgets('IdiomasPantalla muestra el campo y permite escribir',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: IdiomasPantalla(repositorio: _FakeRepositorio()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('¿Qué idiomas hablas?'), findsOneWidget);
    expect(find.text('Escribe un idioma...'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Esp');
    await tester.pumpAndSettle();

    expect(find.text('Español'), findsOneWidget);
    expect(tester.takeException(), null);
  });

  testWidgets('IdiomasPantalla permite agregar un idioma desde las sugerencias',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: IdiomasPantalla(repositorio: _FakeRepositorio()),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Esp');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Español'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), null);
    expect(find.text('Español'), findsOneWidget);
  });
}