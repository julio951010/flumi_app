import 'dart:async';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/base_datos_local/database.dart';
import '../../core/constantes/constantes.dart';
import '../../core/servicios/connectivity_service.dart';

class ChatRepositorio {
  final AppDatabase _db;
  StreamSubscription? _realtimeSub;
  StreamSubscription? _connectivitySub;

  ChatRepositorio(this._db);

  Future<List<Mensaje>> obtenerConversacion(String otroUsuarioId, String miId) {
    return (_db.select(_db.mensajes)
          ..where((m) =>
              (m.emisorId.equals(miId) & m.receptorId.equals(otroUsuarioId)) |
              (m.emisorId.equals(otroUsuarioId) & m.receptorId.equals(miId)))
          ..orderBy([(m) => OrderingTerm.asc(m.timestamp)]))
        .get();
  }

  Stream<List<Mensaje>> observarConversacion(String otroUsuarioId, String miId) {
    return (_db.select(_db.mensajes)
          ..where((m) =>
              (m.emisorId.equals(miId) & m.receptorId.equals(otroUsuarioId)) |
              (m.emisorId.equals(otroUsuarioId) & m.receptorId.equals(miId)))
          ..orderBy([(m) => OrderingTerm.asc(m.timestamp)]))
        .watch();
  }

  Future<void> enviarMensaje({
    required String emisorId,
    required String receptorId,
    required String contenido,
  }) async {
    final uuid = const Uuid().v4();
    await _db.into(_db.mensajes).insert(MensajesCompanion.insert(
      uuid: uuid,
      emisorId: emisorId,
      receptorId: receptorId,
      contenido: contenido,
      timestamp: DateTime.now(),
    ));
  }

  void suscribirseARealtime(String userId) {
    _realtimeSub?.cancel();
    if (!ConnectivityService.instancia.hayConexion) {
      _realtimeSub = null;
      _escucharReconexion(userId);
      return;
    }

    _realtimeSub = Supabase.instance.client
        .from(tablaMessages)
        .stream(primaryKey: ['id'])
        .handleError((_) {})
        .listen((cambios) async {
      for (final cambio in cambios) {
        final dbId = cambio['id'] as String?;
        if (dbId == null) continue;
        final local = await (_db.select(_db.mensajes)
              ..where((m) => m.uuid.equals(dbId)))
            .getSingleOrNull();
        if (local == null) {
          await _db.into(_db.mensajes).insertOnConflictUpdate(
            MensajesCompanion.insert(
              uuid: dbId,
              emisorId: cambio['emisor_id'] as String,
              receptorId: cambio['receptor_id'] as String,
              contenido: cambio['contenido'] as String,
              timestamp: DateTime.parse(cambio['timestamp'] as String),
            ),
          );
        }
      }
    });
  }

  void _escucharReconexion(String userId) {
    _connectivitySub?.cancel();
    _connectivitySub =
        ConnectivityService.instancia.stream.listen((estado) {
      if (estado == EstadoConexion.conectado) {
        _connectivitySub?.cancel();
        _connectivitySub = null;
        suscribirseARealtime(userId);
      }
    });
  }

  void cancelarRealtime() {
    _realtimeSub?.cancel();
    _realtimeSub = null;
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }
}
