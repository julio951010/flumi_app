import 'package:drift/drift.dart';
import '../../core/base_datos_local/database.dart';

class MatchesRepositorio {
  final AppDatabase _db;

  MatchesRepositorio(this._db);

  Future<List<Matche>> obtenerMatches() {
    return (_db.select(_db.matches)
          ..orderBy([(m) => OrderingTerm.desc(m.timestampMatch)]))
        .get();
  }

  Stream<List<Matche>> observarMatches() {
    return (_db.select(_db.matches)
          ..orderBy([(m) => OrderingTerm.desc(m.timestampMatch)]))
        .watch();
  }
}
