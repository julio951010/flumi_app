import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:sqlite3/wasm.dart';

QueryExecutor abrirConexion() => DatabaseConnection.delayed(_abrirWeb());

Future<DatabaseConnection> _abrirWeb() async {
  final sqlite = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
  final fs = await IndexedDbFileSystem.open(dbName: 'flumi');
  sqlite.registerVirtualFileSystem(fs, makeDefault: true);
  return DatabaseConnection(
    WasmDatabase(sqlite3: sqlite, path: 'flumi.sqlite', fileSystem: fs),
  );
}