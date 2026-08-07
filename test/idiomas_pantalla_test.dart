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
  testWidgets('IdiomasPantalla muestra los idiomas disponibles',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: IdiomasPantalla(repositorio: _FakeRepositorio()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Español'), findsOneWidget);
    expect(find.text('Inglés'), findsOneWidget);
    expect(tester.takeException(), null);
  });

  testWidgets('IdiomasPantalla permite seleccionar idiomas de la lista',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: IdiomasPantalla(repositorio: _FakeRepositorio()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Español'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), null);
  });
}