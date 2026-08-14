import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

QueryExecutor abrirConexion() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final archivo = File(p.join(dir.path, 'flumi.sqlite'));

    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();

    return NativeDatabase.createInBackground(archivo);
  });
}