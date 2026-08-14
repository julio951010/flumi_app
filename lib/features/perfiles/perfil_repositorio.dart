import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/base_datos_local/database.dart';
import '../../core/servicios/connectivity_service.dart';
import '../../core/servicios/sync_service.dart';

class PerfilRepositorio {
  final AppDatabase _db;
  final SyncService _sync;

  final ValueNotifier<Usuario?> perfilPropio = ValueNotifier(null);

  /// Última vez que se disparó un refresco remoto, para no lanzar un sync
  /// en cada lectura (varias pantallas llaman a obtenerPerfilPropio a la vez).
  DateTime? _ultimoRefrescoRemoto;

  PerfilRepositorio(this._db, this._sync);

  bool get _debeRefrescar {
    final ahora = DateTime.now();
    if (_ultimoRefrescoRemoto == null) return true;
    return ahora.difference(_ultimoRefrescoRemoto!) >
        const Duration(seconds: 20);
  }

  Future<Usuario?> obtenerPerfilPropio() async {
    // Online-first sin bloquear la UI: si hay red, dispara un refresco en
    // segundo plano (sube pendientes y descarga la fuente de verdad) y la
    // lectura local devuelve al instante. Sin red usa la caché local.
    if (ConnectivityService.instancia.hayConexion &&
        !_sync.estaSincronizando &&
        _debeRefrescar) {
      _ultimoRefrescoRemoto = DateTime.now();
      unawaited(_sync.sincronizarTodo(
        userId: _sync.userIdActual,
        alIniciarSesion: true,
      ));
    }
    final props = await (_db.select(_db.usuarios)
          ..where((u) => u.esPerfilPropio.equals(true)))
        .get();
    if (props.isEmpty) {
      perfilPropio.value = null;
      return null;
    }
    // Descendente: la fila más reciente corresponde a la cuenta que entró
    // por última vez; si por cualquier motivo hubiera varias, preferimos la
    // nueva (datos actuales) sobre la vieja (restos de otra cuenta).
    props.sort((a, b) => b.creadoEn.compareTo(a.creadoEn));
    final perfil = props.first;
    perfilPropio.value = perfil;
    return perfil;
  }

  Future<Usuario?> obtenerPerfilPorUuid(String uuid) async {
    // Online-first sin bloquear: refresca el perfil remoto en segundo plano.
    if (ConnectivityService.instancia.hayConexion &&
        !_sync.estaSincronizando &&
        _debeRefrescar) {
      _ultimoRefrescoRemoto = DateTime.now();
      unawaited(_sync.refrescarPerfilRemoto(uuid));
    }
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
    await obtenerPerfilPropio();
    // Subir a Supabase de inmediato (fire-and-forget) tras guardar localmente.
    _sync.sincronizarPerfil();
  }
}
