import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

const _carpetaFotosPrueba =
    'C:/_Proyectos_Flutter/flumi_app/test/features/perfiles';
const _assetFotosPrueba = 'assets/fotos_prueba';

const _carpetasPrueba = [
  'Alice',
  'Bob',
  'Carla',
  'David',
  'Elena',
  'Julio Cesar',
];

String _normalizar(String s) {
  const conAcentos = 'áéíóúüñ';
  const sinAcentos = 'aeiouun';
  final b = StringBuffer();
  for (final ch in s.trim().toLowerCase().split('')) {
    final i = conAcentos.indexOf(ch);
    b.write(i >= 0 ? sinAcentos[i] : ch);
  }
  return b.toString();
}

Future<String> _resolverCarpeta(String nombre) async {
  final dirLocal = Directory(_carpetaFotosPrueba);
  if (dirLocal.existsSync()) {
    final carpetas = dirLocal
        .listSync(followLinks: false)
        .whereType<Directory>()
        .map((d) => d.path.split(Platform.pathSeparator).last)
        .toList();
    final n = _normalizar(nombre);
    for (final c in carpetas) {
      if (_normalizar(c) == n) return c;
    }
    if (carpetas.isNotEmpty) return carpetas.first;
    return '';
  }
  final n = _normalizar(nombre);
  for (final c in _carpetasPrueba) {
    if (_normalizar(c) == n) return c;
  }
  return _carpetasPrueba.first;
}

Future<List<String>> fotosMockDePrueba(String nombre) async {
  final carpeta = await _resolverCarpeta(nombre);
  if (carpeta.isEmpty) return const [];
  final dirLocal = Directory('$_carpetaFotosPrueba/$carpeta');
  if (dirLocal.existsSync()) {
    return [
      for (var i = 1; i <= 4; i++)
        if (File('${dirLocal.path}/imagen$i.png').existsSync())
          '${dirLocal.path}/imagen$i.png',
    ];
  }
  final docs = await getApplicationDocumentsDirectory();
  final dirDestino = Directory('${docs.path}/fotos_prueba/$carpeta');
  final rutas = <String>[];
  for (var i = 1; i <= 4; i++) {
    final destino = File('${dirDestino.path}/imagen$i.png');
    if (!destino.existsSync()) {
      try {
        final datos = await rootBundle.load(
            '$_assetFotosPrueba/${Uri.encodeComponent(carpeta)}/imagen$i.png');
        await dirDestino.create(recursive: true);
        await destino.writeAsBytes(datos.buffer.asUint8List(), flush: true);
      } catch (_) {
        continue;
      }
    }
    rutas.add(destino.path);
  }
  return rutas;
}