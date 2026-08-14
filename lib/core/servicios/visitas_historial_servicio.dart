import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../base_datos_local/database.dart';
import 'connectivity_service.dart';
import 'sync_service.dart';

Future<String?> _obtenerUsuarioPropioId(AppDatabase db) async {
  final list = await (db.select(db.usuarios)
        ..where((u) => u.esPerfilPropio.equals(true))
        ..limit(1))
      .get();
  return list.isNotEmpty ? list.first.uuid : null;
}

class VisitasServicio with ChangeNotifier {
  final AppDatabase _db;
  final SyncService _sync;

  VisitasServicio(this._db, this._sync);

  Future<void> registrarVisita(String visitadoId) async {
    final visitanteId = await _obtenerUsuarioPropioId(_db);
    if (visitanteId == null || visitanteId == visitadoId) return;

    final comp = VisitasCompanion(
      uuid: Value(const Uuid().v4()),
      visitanteId: Value(visitanteId),
      visitadoId: Value(visitadoId),
      timestamp: Value(DateTime.now()),
    );
    await _db.into(_db.visitas).insert(comp);
    // Write-through: intenta subir la visita a Supabase de inmediato;
    // si falla queda pendienteDeSincronizar=true para el siguiente sync.
    unawaited(_sync.sincronizarVisitas());
  }

  Future<List<Visita>> obtenerVisitas({int? limite}) async {
    final visitadoId = await _obtenerUsuarioPropioId(_db);
    if (visitadoId == null) return [];

    // Online-first: refresca las visitas recibidas desde Supabase.
    if (ConnectivityService.instancia.hayConexion) {
      await _sync.sincronizarVisitas();
    }

    final query = _db.select(_db.visitas)
      ..where((v) => v.visitadoId.equals(visitadoId))
      ..orderBy([(v) => OrderingTerm.desc(v.timestamp)]);
    if (limite != null) query.limit(limite);
    return query.get();
  }

  Future<int> contarVisitas() async {
    final visitadoId = await _obtenerUsuarioPropioId(_db);
    if (visitadoId == null) return 0;

    // Online-first: refresca las visitas recibidas desde Supabase.
    if (ConnectivityService.instancia.hayConexion) {
      await _sync.sincronizarVisitas();
    }

    final list = await (_db.select(_db.visitas)
          ..where((v) => v.visitadoId.equals(visitadoId)))
        .get();
    return list.length;
  }
}

class HistorialLikesServicio with ChangeNotifier {
  final AppDatabase _db;
  final SyncService _sync;

  HistorialLikesServicio(this._db, this._sync);

  Future<void> registrarLike(String usuarioLikeadoId) async {
    final usuarioId = await _obtenerUsuarioPropioId(_db);
    if (usuarioId == null || usuarioId == usuarioLikeadoId) return;

    final comp = HistorialLikesCompanion(
      uuid: Value(const Uuid().v4()),
      usuarioId: Value(usuarioId),
      usuarioLikeadoId: Value(usuarioLikeadoId),
      timestamp: Value(DateTime.now()),
    );
    await _db.into(_db.historialLikes).insert(comp);
    // Write-through: intenta subir el like a Supabase de inmediato.
    unawaited(_sync.sincronizarHistorialLikes());
  }

  Future<List<HistorialLike>> obtenerHistorial({int? limite}) async {
    final usuarioId = await _obtenerUsuarioPropioId(_db);
    if (usuarioId == null) return [];

    // Online-first: refresca los likes desde Supabase.
    if (ConnectivityService.instancia.hayConexion) {
      await _sync.sincronizarHistorialLikes();
    }

    final query = _db.select(_db.historialLikes)
      ..where((h) => h.usuarioId.equals(usuarioId))
      ..orderBy([(h) => OrderingTerm.desc(h.timestamp)]);
    if (limite != null) query.limit(limite);
    return query.get();
  }
}