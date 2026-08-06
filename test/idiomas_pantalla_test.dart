import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drift/drift.dart' hide Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  testWidgets('IdiomasPantalla muestra sugerencias al escribir',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: IdiomasPantalla(repositorio: _FakeRepositorio()),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'es');
    await tester.pump();

    expect(find.text('Español'), findsWidgets);
  });

  testWidgets('IdiomasPantalla muestra sugerencias con teclado abierto',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1800);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: IdiomasPantalla(repositorio: _FakeRepositorio()),
    ));
    await tester.pumpAndSettle();

    tester.view.viewInsets = const FakeViewPadding(bottom: 400);
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'es');
    await tester.pump();

    expect(find.text('Español'), findsWidgets);
    expect(tester.takeException(), null);
  });
}
