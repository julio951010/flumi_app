import '../../core/base_datos_local/database.dart';

class PerfilRepositorio {
  final AppDatabase _db;

  PerfilRepositorio(this._db);

  Future<Usuario?> obtenerPerfilPropio() async {
    final props = await (_db.select(_db.usuarios)
          ..where((u) => u.esPerfilPropio.equals(true)))
        .get();
    if (props.isEmpty) return null;
    props.sort((a, b) => (a.creadoEn ?? DateTime(0)).compareTo(b.creadoEn ?? DateTime(0)));
    return props.first;
  }

  Future<Usuario?> obtenerPerfilPorUuid(String uuid) {
    return (_db.select(_db.usuarios)
          ..where((u) => u.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  Future<void> guardarOCambiarPerfil(UsuariosCompanion perfil) async {
    final uuid = perfil.uuid.present ? perfil.uuid.value : null;
    if (uuid == null) {
      throw ArgumentError('Se requiere un uuid para guardar el perfil.');
    }
    final existe =
        await (_db.select(_db.usuarios)
            ..where((u) => u.uuid.equals(uuid)))
        .getSingleOrNull();
    if (existe == null) {
      await _db.into(_db.usuarios).insert(perfil);
    } else {
      await (_db.update(_db.usuarios)
            ..where((u) => u.uuid.equals(uuid)))
          .write(perfil);
    }
  }
}
