import '../../core/base_datos_local/database.dart';

class PerfilRepositorio {
  final AppDatabase _db;

  PerfilRepositorio(this._db);

  Future<Usuario?> obtenerPerfilPropio() {
    return (_db.select(_db.usuarios)
          ..where((u) => u.esPerfilPropio.equals(true)))
        .getSingleOrNull();
  }

  Future<Usuario?> obtenerPerfilPorUuid(String uuid) {
    return (_db.select(_db.usuarios)
          ..where((u) => u.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  Future<void> guardarOCambiarPerfil(UsuariosCompanion perfil) {
    return _db.into(_db.usuarios).insertOnConflictUpdate(perfil);
  }
}
