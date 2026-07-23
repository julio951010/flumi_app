import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Usuarios, Mensajes, Matches, Reportes, Bloqueos])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_abrirConexion());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _abrirConexion() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final archivo = File(p.join(dir.path, 'flumi.sqlite'));

      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();

      return NativeDatabase.createInBackground(archivo);
    });
  }
}
