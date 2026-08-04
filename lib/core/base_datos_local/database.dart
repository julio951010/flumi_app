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
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.addColumn(usuarios, usuarios.perfilCompletado);
      }
      if (from < 3) {
        await m.addColumn(usuarios, usuarios.queBusca);
      }
      if (from < 4) {
        await m.addColumn(usuarios, usuarios.orientacionSexual);
        await m.addColumn(usuarios, usuarios.situacionSentimental);
        await m.addColumn(usuarios, usuarios.intereses);
        await m.addColumn(usuarios, usuarios.altura);
        await m.addColumn(usuarios, usuarios.educacion);
        await m.addColumn(usuarios, usuarios.trabajo);
        await m.addColumn(usuarios, usuarios.bebe);
        await m.addColumn(usuarios, usuarios.fuma);
        await m.addColumn(usuarios, usuarios.hijos);
        await m.addColumn(usuarios, usuarios.personalidad);
        await m.addColumn(usuarios, usuarios.signoZodiaco);
        await m.addColumn(usuarios, usuarios.mascotas);
        await m.addColumn(usuarios, usuarios.religion);
        await m.addColumn(usuarios, usuarios.fotoVerificacion);
      }
      if (from < 5) {
        await m.addColumn(matches, matches.leidoHasta);
      }
      if (from < 6) {
        await m.addColumn(usuarios, usuarios.fechaNacimiento);
        await m.addColumn(usuarios, usuarios.ciudad);
      }
    },
  );

  static QueryExecutor _abrirConexion() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final archivo = File(p.join(dir.path, 'flumi.sqlite'));

      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();

      return NativeDatabase.createInBackground(archivo);
    });
  }
}
