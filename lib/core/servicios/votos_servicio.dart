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

/// Registro de perfiles rechazados (Nope) con reciclaje:
///
/// * Nuevos primero; si no quedan suficientes nuevos entra el reciclaje:
///   - quedan algunos nuevos (< [minimoNuevosParaReciclar]): solo Nopes
///     con [edadMinimaReciclaje] cumplida (los más antiguos primero);
///   - no queda ningún perfil nuevo: cualquier Nope vuelve sin esperar,
///     reciente o viejo.
/// * Con [nopesParaExclusionPermanente] Nopes al mismo perfil se excluye
///   definitivamente, haya o no perfiles nuevos.
///
/// Cada Nope inserta una fila en la tabla [Rechazos] (múltiples filas por
/// par = conteo acumulado), persistida y sincronizada con Supabase.
class VotosServicio extends ChangeNotifier {
  /// Veces que hay que hacer Nope al mismo perfil para excluirlo para
  /// siempre, aunque ya sea reciclable por tiempo.
  static const int nopesParaExclusionPermanente = 3;

  /// Edad mínima de un Nope para poder reciclarlo. Más reciente = "muy
  /// reciente", no se recicla. Espejo del RPC `perfiles_cercanos`.
  static const Duration edadMinimaReciclaje = Duration(days: 3);

  /// Si quedan menos perfiles nuevos que esto, el mazo recicla los Nopes
  /// más antiguos (que ya cumplen [edadMinimaReciclaje]).
  static const int minimoNuevosParaReciclar = 5;

  final AppDatabase _db;
  final SyncService _sync;
  final Map<String, ({int conteo, DateTime ultimo})> _rechazos = {};
  bool _inicializado = false;

  VotosServicio(this._db, this._sync);

  bool get inicializado => _inicializado;

  /// Carga los rechazos del usuario actual desde la BD local, refrescando
  /// antes desde Supabase (online-first).
  Future<void> inicializar() async {
    if (_inicializado) return;
    final usuarioId = await _obtenerUsuarioPropioId(_db);
    if (usuarioId == null) return;
    if (ConnectivityService.instancia.hayConexion) {
      try {
        await _sync.sincronizarRechazos(usuarioId);
      } catch (_) {}
    }
    final filas = await (_db.select(_db.rechazos)
          ..where((r) => r.usuarioId.equals(usuarioId)))
        .get();
    _rechazos.clear();
    for (final f in filas) {
      final prev = _rechazos[f.rechazadoId];
      if (prev == null) {
        _rechazos[f.rechazadoId] = (conteo: 1, ultimo: f.timestamp);
      } else {
        _rechazos[f.rechazadoId] = (
          conteo: prev.conteo + 1,
          ultimo: f.timestamp.isAfter(prev.ultimo) ? f.timestamp : prev.ultimo,
        );
      }
    }
    _inicializado = true;
    notifyListeners();
  }

  /// Excluido AHORA del mazo: excluido definitivamente (3+ Nopes) o Nope
  /// demasiado reciente (aún no reciclable mientras queden nuevos).
  bool esRechazado(String uuid) {
    final r = _rechazos[uuid];
    if (r == null) return false;
    if (r.conteo >= nopesParaExclusionPermanente) return true;
    return DateTime.now().difference(r.ultimo) < edadMinimaReciclaje;
  }

  /// Excluido por siempre: acumuló [nopesParaExclusionPermanente] Nopes.
  /// Este criterio nunca se relaja, haya o no perfiles nuevos.
  bool esExcluidoPermanente(String uuid) =>
      (_rechazos[uuid]?.conteo ?? 0) >= nopesParaExclusionPermanente;

  /// Candidato a reciclaje por tiempo: ya pasó [edadMinimaReciclaje] desde
  /// el Nope y aún no acumuló [nopesParaExclusionPermanente].
  bool esReciclable(String uuid) {
    final r = _rechazos[uuid];
    if (r == null || r.conteo >= nopesParaExclusionPermanente) return false;
    return DateTime.now().difference(r.ultimo) >= edadMinimaReciclaje;
  }

  DateTime? ultimoRechazo(String uuid) => _rechazos[uuid]?.ultimo;

  /// Compone el mazo con la regla de reciclaje según la cantidad de perfiles
  /// nuevos que queden:
  ///
  /// * >= [minimoNuevosParaReciclar] nuevos → solo nuevos.
  /// * 1..[minimoNuevosParaReciclar)-1 nuevos → nuevos + reciclables por
  ///   tiempo ([esReciclable]), más antiguos primero.
  /// * 0 nuevos → todos los rechazados no permanentes, sin esperar la edad
  ///   mínima, más antiguos primero.
  List<Usuario> componerDeck(List<Usuario> entrada) {
    final disponibles =
        entrada.where((u) => !esExcluidoPermanente(u.uuid)).toList();
    final nuevos =
        disponibles.where((u) => !_rechazos.containsKey(u.uuid)).toList();
    if (nuevos.length >= minimoNuevosParaReciclar) return nuevos;
    final reciclables = disponibles
        .where((u) => _rechazos.containsKey(u.uuid))
        .toList()
      ..sort(
          (a, b) => ultimoRechazo(a.uuid)!.compareTo(ultimoRechazo(b.uuid)!));
    if (nuevos.isEmpty) return reciclables;
    return [...nuevos, ...reciclables.where((u) => esReciclable(u.uuid))];
  }

  Future<void> registrarRechazo(String uuid) async {
    final prev = _rechazos[uuid];
    _rechazos[uuid] = (conteo: (prev?.conteo ?? 0) + 1, ultimo: DateTime.now());
    final usuarioId = await _obtenerUsuarioPropioId(_db);
    if (usuarioId != null) {
      await _db.into(_db.rechazos).insert(
            RechazosCompanion(
              uuid: Value(const Uuid().v4()),
              usuarioId: Value(usuarioId),
              rechazadoId: Value(uuid),
              timestamp: Value(DateTime.now()),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      // Write-through: intenta subir el rechazo a Supabase de inmediato;
      // si falla queda pendienteDeSincronizar=true para el siguiente sync.
      unawaited(_sync.sincronizarRechazos(usuarioId));
    }
    notifyListeners();
  }

  /// Deshace un rechazo. Devuelve false si el cupo de Deshacer del plan
  /// está agotado (validado en el servidor por `registrar_deshacer`, Fase 6).
  /// Con [comoDeshacer] false el borrado es administrativo (p. ej. al dar
  /// like a alguien que habías rechazado) y no consume cupo.
  Future<bool> quitarRechazo(String uuid, {bool comoDeshacer = true}) async {
    final usuarioId = await _obtenerUsuarioPropioId(_db);
    if (usuarioId != null &&
        comoDeshacer &&
        ConnectivityService.instancia.hayConexion &&
        !kUsarServidorLocal) {
      try {
        final resultado = await sb.Supabase.instance.client
            .rpc('registrar_deshacer', params: {'perfil_id': uuid});
        if (resultado is Map && resultado['limite'] == true) {
          return false;
        }
      } catch (e) {
        EstadoServidorServicio.instancia.marcarFallo(e);
        // Sin válida: cae al borrado local best-effort.
      }
    }
    _rechazos.remove(uuid);
    if (usuarioId != null) {
      await (_db.delete(_db.rechazos)
            ..where((r) => r.usuarioId.equals(usuarioId) &
                r.rechazadoId.equals(uuid)))
          .go();
      // Best-effort: deshace el rechazo también en Supabase (si el RPC no
      // lo hizo ya).
      unawaited(_sync.borrarRechazoRemoto(usuarioId, uuid));
    }
    notifyListeners();
    return true;
  }
}

Future<String?> _obtenerUsuarioPropioId(AppDatabase db) async {
  final list = await (db.select(db.usuarios)
        ..where((u) => u.esPerfilPropio.equals(true))
        ..limit(1))
      .get();
  return list.isNotEmpty ? list.first.uuid : null;
}
