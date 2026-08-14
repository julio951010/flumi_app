import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Flumi/features/encuentros/pantallas/filtros_encuentros_sheet.dart';

Future<void> _cargarFuentes() async {
  final loader = FontLoader('Roboto');
  for (final nombre in ['roboto-regular.ttf', 'roboto-bold.ttf']) {
    final bytes = File('test/fonts/$nombre').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  setUpAll(_cargarFuentes);

  testWidgets('selección en Más opciones llega al resultado final', (tester) async {
    Future<FiltrosEncuentros?>? futuro;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  futuro = mostrarFiltrosEncuentros(
                    context,
                    actuales: FiltrosEncuentros(),
                    estaEnCercaDeTi: false,
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Filtros'), findsOneWidget);

    await tester.tap(find.text('Más opciones'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Religión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Religión'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Católica'), findsWidgets);
    await tester.ensureVisible(find.textContaining('Católica'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Católica'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Aplicar').last);
    await tester.pumpAndSettle();

    final filaReligion = find.text('Religión');
    expect(filaReligion, findsOneWidget);
    final tile = tester.widget<ListTile>(
      find.ancestor(of: filaReligion, matching: find.byType(ListTile)).first,
    );
    expect(tile.subtitle.toString(), contains('Católica'));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Aplicar filtros'));
    await tester.pumpAndSettle();

    expect(futuro, isNotNull);
    final resultado = await futuro!;
    expect(resultado, isNotNull);
    expect(resultado!.avanzado['religion'], isNotNull);
    expect(resultado!.avanzado['religion']!.join(','), contains('Católica'));
  });
}