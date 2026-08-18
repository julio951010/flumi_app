// Limpia los datos de interacción de la BD local de Flumi (Me Gusta,
// visitas, matches, mensajes, rechazos, bloqueos, reportes y usos diarios)
// conservando los perfiles (usuarios) y la suscripción.
//
// Uso:
//   flutter test tool/limpiar_datos_test.dart
//   flutter test tool/limpiar_datos_test.dart --dart-define=FLUMI_DB="C:\ruta\flumi.sqlite"
//
// Notas:
// - Cierra la app antes de ejecutarlo.
// - Si pruebas en línea (Supabase), el sync volverá a descargar los likes,
//   visitas y matches que sigan existiendo en el servidor: ejecuta también
//   el SQL de tool/limpiar_remoto.sql en el editor SQL de Supabase.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

const _tablas = [
  'historial_likes',
  'visitas',
  'matches',
  'mensajes',
  'rechazos',
  'bloqueos',
  'reportes',
  'usos_diarios',
];

String _rutaPorDefecto() {
  final home =
      Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '.';
  return p.join(home, 'Documents', 'flumi.sqlite');
}

void main() {
  test('Limpieza de datos de interacción', () async {
    final definido = const String.fromEnvironment('FLUMI_DB');
    final ruta = definido.isNotEmpty ? definido : _rutaPorDefecto();

    stdout.writeln('BD objetivo: $ruta');
    final archivo = File(ruta);
    if (!archivo.existsSync()) {
      fail('No existe la BD en: $ruta\n'
          'Pasa la ruta correcta con --dart-define=FLUMI_DB="..."');
    }

    final db = sqlite3.open(ruta);
    var total = 0;
    for (final tabla in _tablas) {
      try {
        final n = db
            .select('SELECT COUNT(*) AS n FROM $tabla')
            .first['n'] as int;
        db.execute('DELETE FROM $tabla');
        total += n;
        stdout.writeln('  $tabla: eliminadas $n filas');
      } catch (_) {
        stdout.writeln('  $tabla: no existe, omitida');
      }
    }
    db.dispose();

    stdout.writeln('Total filas eliminadas: $total');
    if (total == 0) {
      stdout.writeln('No había datos de interacción que limpiar.');
    } else {
      stdout.writeln(
          'Listo. Abre la app; si usas Supabase y quieres empezar de cero, '
          'limpia también el servidor (tool/limpiar_remoto.sql).');
    }
  });
}