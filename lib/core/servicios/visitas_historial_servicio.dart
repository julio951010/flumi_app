import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../config/env.dart';
import '../base_datos_local/database.dart';
import 'connectivity_service.dart';
import 'estado_servidor_servicio.dart';
import 'sync_service.dart';

Future<String?> _obtenerUsuarioPropioId(AppDatabase db) async {
  final list = await (db.select(db.usuarios)
        ..where((u) => u.esPerfilPropio.equals(true))
        ..limit(1))
      .get();
  return list.isNotEmpty ? list.first.uuid : null;
}

/// Respuesta del RPC `registrar_me_gusta` (Fase 3): el servidor valida el
/// límite diario y crea el like (y el match si es recíproco).
class ResultadoMeGusta {
  final bool match;
  final bool likeado;
  final bool limite;

  const ResultadoMeGusta({
    required this.match,
    required this.likeado,
    required this.limite,
  });

  factory ResultadoMeGusta.desdeJson(Map<String, dynamic> json) {
    return ResultadoMeGusta(
      match: json['match'] == true,
      likeado: json['likeado'] == true,
      limite: json['limite'] == true,
    );
  }
}

class VisitasServicio with ChangeNotifier {
  final AppDatabase _db;
  final SyncService _sync;

  VisitasServicio(this._db, this._sync);

  Future<void> registrarVisita(String visitadoId) async {
    final visitanteId = await _obtenerUsuarioPropioId(_db);
    if (visitanteId == null || visitanteId == visitadoId) return;

    // Modo invisible: no se registra la visita (ni local ni remota), así
    // nadie puede ver que visité su perfil.
    final perfil = await (_db.select(_db.usuarios)
          ..where((u) => u.esPerfilPropio.equals(true)))
        .getSingleOrNull();
    if (perfil?.ocultarVisitas ?? false) return;

    // Debounce: reabrir el mismo perfil en <30 min no genera otra visita.
    final limite = DateTime.now().subtract(const Duration(minutes: 30));
    final reciente = await (_db.select(_db.visitas)
          ..where((v) =>
              v.visitanteId.equals(visitanteId) &
              v.visitadoId.equals(visitadoId) &
              v.timestamp.isBiggerThanValue(limite))
          ..limit(1))
        .getSingleOrNull();
    if (reciente != null) return;

    // Fase 3: online-first contra el RPC; sin conexión se queda local
    // pendiente para el siguiente sync.
    if (ConnectivityService.instancia.hayConexion && !kUsarServidorLocal) {
      try {
        await sb.Supabase.instance.client
            .rpc('registrar_visita', params: {'perfil_id': visitadoId});
      } catch (e) {
        EstadoServidorServicio.instancia.marcarFallo(e);
      }
      return;
    }

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

  Future<List<Visita>> obtenerVisitas({int? limite, bool sincronizar = true}) async {
    final visitadoId = await _obtenerUsuarioPropioId(_db);
    if (visitadoId == null) return [];

    // Online-first: refresca las visitas recibidas desde Supabase.
    // Con sincronizar=false se lee solo local (realtime ya escribió).
    if (sincronizar && ConnectivityService.instancia.hayConexion) {
      await _sync.sincronizarVisitas();
    }

    final query = _db.select(_db.visitas)
      ..where((v) => v.visitadoId.equals(visitadoId))
      ..orderBy([(v) => OrderingTerm.desc(v.timestamp)]);
    final filas = await query.get();

    // Visitas únicas: por cada visitante solo cuenta la más reciente, así la
    // bandeja y "¿Quién te vio?" notifican una sola vez por persona.
    final porVisitante = <String, Visita>{};
    for (final f in filas) {
      final prev = porVisitante[f.visitanteId];
      if (prev == null || prev.timestamp.isBefore(f.timestamp)) {
        porVisitante[f.visitanteId] = f;
      }
    }
    final unicas = porVisitante.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (limite != null && unicas.length > limite) {
      return unicas.sublist(0, limite);
    }
    return unicas;
  }

  /// Nº de visitas recibidas por cada visitante: 1 = primera visita,
  /// >1 = el usuario te ha visitado más de una vez.
  Future<Map<String, int>> contarPorVisitante() async {
    final visitadoId = await _obtenerUsuarioPropioId(_db);
    if (visitadoId == null) return {};

    final filas = await (_db.select(_db.visitas)
          ..where((v) => v.visitadoId.equals(visitadoId)))
        .get();
    final conteos = <String, int>{};
    for (final f in filas) {
      conteos[f.visitanteId] = (conteos[f.visitanteId] ?? 0) + 1;
    }
    return conteos;
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

  /// Registra un Me Gusta (o Superlike) en el servidor y devuelve la certeza
  /// del match. Devuelve null si no hay conexión (queda pendiente local).
  Future<ResultadoMeGusta?> registrarLike(
    String usuarioLikeadoId, {
    bool esSuper = false,
  }) async {
    final usuarioId = await _obtenerUsuarioPropioId(_db);
    if (usuarioId == null || usuarioId == usuarioLikeadoId) return null;

    if (ConnectivityService.instancia.hayConexion && !kUsarServidorLocal) {
      try {
        final resultado = await sb.Supabase.instance.client.rpc(
          'registrar_me_gusta',
          params: {'perfil_id': usuarioLikeadoId, 'es_super': esSuper},
        );
        if (resultado is Map) {
          return ResultadoMeGusta.desdeJson(
              Map<String, dynamic>.from(resultado));
        }
        return null;
      } catch (e) {
        EstadoServidorServicio.instancia.marcarFallo(e);
        return null;
      }
    }

    // Sin conexión: queda pendiente (el trigger de match correrá en el sync).
    // Se conserva esSuper para no perder el Superlike offline al sincronizar.
    final comp = HistorialLikesCompanion(
      uuid: Value(const Uuid().v4()),
      usuarioId: Value(usuarioId),
      usuarioLikeadoId: Value(usuarioLikeadoId),
      timestamp: Value(DateTime.now()),
      esSuper: Value(esSuper),
    );
    await _db.into(_db.historialLikes).insert(comp);
    unawaited(_sync.sincronizarHistorialLikes());
    return null;
  }

  Future<List<HistorialLike>> obtenerHistorial({int? limite, bool sincronizar = true}) async {
    final usuarioId = await _obtenerUsuarioPropioId(_db);
    if (usuarioId == null) return [];

    // Online-first: refresca los likes desde Supabase.
    if (sincronizar && ConnectivityService.instancia.hayConexion) {
      await _sync.sincronizarHistorialLikes();
    }

    final query = _db.select(_db.historialLikes)
      ..where((h) => h.usuarioId.equals(usuarioId))
      ..orderBy([(h) => OrderingTerm.desc(h.timestamp)]);
    if (limite != null) query.limit(limite);
    return query.get();
  }

  /// Ids de perfiles a los que YO les di like (se excluyen del feed).
  Future<Set<String>> obtenerIdsGustados() async {
    final usuarioId = await _obtenerUsuarioPropioId(_db);
    if (usuarioId == null) return {};
    if (ConnectivityService.instancia.hayConexion) {
      await _sync.sincronizarHistorialLikes();
    }
    final filas = await (_db.select(_db.historialLikes)
          ..where((h) => h.usuarioId.equals(usuarioId)))
        .get();
    return filas.map((h) => h.usuarioLikeadoId).toSet();
  }

  /// Perfiles que ME dieron like, más recientes primero (detecta matches).
  Future<List<HistorialLike>> obtenerLikesRecibidosDetalle({bool sincronizar = true}) async {
    final usuarioId = await _obtenerUsuarioPropioId(_db);
    if (usuarioId == null) return [];
    if (sincronizar && ConnectivityService.instancia.hayConexion) {
      await _sync.sincronizarHistorialLikes();
    }
    final query = _db.select(_db.historialLikes)
      ..where((h) => h.usuarioLikeadoId.equals(usuarioId))
      ..orderBy([(h) => OrderingTerm.desc(h.timestamp)]);
    return query.get();
  }

  /// Ids de perfiles que ME dieron like (detecta matches).
  Future<Set<String>> obtenerLikesRecibidos() async {
    final usuarioId = await _obtenerUsuarioPropioId(_db);
    if (usuarioId == null) return {};
    if (ConnectivityService.instancia.hayConexion) {
      await _sync.sincronizarHistorialLikes();
    }
    final filas = await (_db.select(_db.historialLikes)
          ..where((h) => h.usuarioLikeadoId.equals(usuarioId)))
        .get();
    return filas.map((h) => h.usuarioId).toSet();
  }

  /// Ids de perfiles que ME dieron un Superlike (recibidos).
  Future<Set<String>> obtenerIdsSuperRecibidos() async {
    final usuarioId = await _obtenerUsuarioPropioId(_db);
    if (usuarioId == null) return {};
    if (ConnectivityService.instancia.hayConexion) {
      await _sync.sincronizarHistorialLikes();
    }
    final filas = await (_db.select(_db.historialLikes)
          ..where((h) => h.usuarioLikeadoId.equals(usuarioId)))
        .get();
    return filas.where((h) => h.esSuper).map((h) => h.usuarioId).toSet();
  }
}