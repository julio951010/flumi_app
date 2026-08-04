import 'dart:async';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../config/env.dart';
import '../../core/api/mock_data.dart';
import '../../core/base_datos_local/database.dart';
import '../../core/constantes/constantes.dart';
import '../../core/servicios/connectivity_service.dart';

class PerfilChat {
  final Usuario usuario;
  final bool esMatch;
  final bool esMeGusta;
  final DateTime timestamp;

  const PerfilChat({
    required this.usuario,
    required this.esMatch,
    required this.timestamp,
    this.esMeGusta = false,
  });
}

class ResumenConversacion {
  final String otroUsuarioId;
  final String nombre;
  final int? edad;
  final bool verificado;
  final String ultimoMensaje;
  final bool ultimoEsMio;
  final DateTime timestamp;
  final int noLeidos;
  final bool online;
  final bool esMeGusta;
  final bool esMatch;

  const ResumenConversacion({
    required this.otroUsuarioId,
    required this.nombre,
    required this.ultimoMensaje,
    required this.ultimoEsMio,
    required this.timestamp,
    required this.noLeidos,
    this.edad,
    this.verificado = false,
    this.online = false,
    this.esMeGusta = false,
    this.esMatch = false,
  });
}

class ChatRepositorio {
  final AppDatabase _db;
  StreamSubscription? _realtimeSub;
  StreamSubscription? _connectivitySub;

  ChatRepositorio(this._db);

  Stream<List<ResumenConversacion>> observarConversaciones(String miId) {
    late final StreamController<List<ResumenConversacion>> ctrl;
    StreamSubscription? subMsgs;
    StreamSubscription? subMatches;

    Future<void> recalcular() async {
      if (ctrl.isClosed) return;
      final msgs = await (_db.select(_db.mensajes)
            ..where((m) =>
                m.emisorId.equals(miId) | m.receptorId.equals(miId))
            ..orderBy([(m) => OrderingTerm.desc(m.timestamp)]))
          .get();
      final matches = await _db.select(_db.matches).get();
      final usuarios = await _db.select(_db.usuarios).get();
      ctrl.add(_resumir(miId, msgs, matches, usuarios));
    }

    ctrl = StreamController<List<ResumenConversacion>>(
      onListen: () {
        subMsgs = (_db.select(_db.mensajes)
              ..where((m) =>
                  m.emisorId.equals(miId) | m.receptorId.equals(miId)))
            .watch()
            .listen((_) => recalcular());
        subMatches = _db.select(_db.matches).watch().listen((_) => recalcular());
        recalcular();
      },
      onCancel: () {
        subMsgs?.cancel();
        subMsgs = null;
        subMatches?.cancel();
        subMatches = null;
      },
    );
    return ctrl.stream;
  }

  Stream<List<PerfilChat>> observarPerfiles(String miId) {
    late final StreamController<List<PerfilChat>> ctrl;
    StreamSubscription? subMatches;
    StreamSubscription? subUsuarios;

    Future<void> recalcular() async {
      if (ctrl.isClosed) return;
      final matches = await _db.select(_db.matches).get();
      final usuarios = await _db.select(_db.usuarios).get();
      final mapa = {for (final u in usuarios) u.uuid: u};
      final misLikes = {
        for (final l in GeneradorMock.obtenerMisLikes()) l.usuarioId
      };

      final result = <PerfilChat>[];
      final vistos = <String>{};

      final delUsuario = matches
          .where((m) => m.usuarioAId == miId || m.usuarioBId == miId)
          .toList()
        ..sort((a, b) => b.timestampMatch.compareTo(a.timestampMatch));
      for (final m in delUsuario) {
        final otro = m.usuarioAId == miId ? m.usuarioBId : m.usuarioAId;
        final u = mapa[otro];
        if (u == null || !vistos.add(otro)) continue;
        result.add(PerfilChat(
          usuario: u,
          esMatch: true,
          timestamp: m.timestampMatch,
          esMeGusta: misLikes.contains(otro),
        ));
      }

      for (final like in GeneradorMock.obtenerLikesRecibidos()) {
        final u = mapa[like.usuarioId];
        if (u == null || !vistos.add(like.usuarioId)) continue;
        result.add(PerfilChat(
          usuario: u,
          esMatch: false,
          timestamp: like.timestamp,
          esMeGusta: misLikes.contains(like.usuarioId),
        ));
      }

      ctrl.add(result);
    }

    ctrl = StreamController<List<PerfilChat>>(
      onListen: () {
        subMatches =
            _db.select(_db.matches).watch().listen((_) => recalcular());
        subUsuarios =
            _db.select(_db.usuarios).watch().listen((_) => recalcular());
        recalcular();
      },
      onCancel: () {
        subMatches?.cancel();
        subMatches = null;
        subUsuarios?.cancel();
        subUsuarios = null;
      },
    );
    return ctrl.stream;
  }

  List<ResumenConversacion> _resumir(
      String miId, List<Mensaje> msgs, List<Matche> matches, List<Usuario> usuarios) {
    final nombres = {for (final u in usuarios) u.uuid: u.nombre};
    final edades = {for (final u in usuarios) u.uuid: u.edad};
    final verificados = {for (final u in usuarios) u.uuid: u.verificadoStatus};
    final onlinePorUsuario = {
      for (final u in usuarios) u.uuid: u.ultimaSincronizacionTimestamp != null
    };
    final misLikes = {
      for (final l in GeneradorMock.obtenerMisLikes()) l.usuarioId
    };
    final porOtro = <String, List<Mensaje>>{};
    final tiemposMatch = <String, DateTime>{};
    final leidosHasta = <String, DateTime>{};

    for (final match in matches) {
      final otro = match.usuarioAId == miId ? match.usuarioBId : match.usuarioAId;
      if (otro == miId || otro.isEmpty) continue;
      tiemposMatch.putIfAbsent(otro, () => match.timestampMatch);
      final leido = match.leidoHasta;
      if (leido != null) leidosHasta.putIfAbsent(otro, () => leido);
    }

    for (final m in msgs) {
      final otro = m.emisorId == miId ? m.receptorId : m.emisorId;
      if (otro.isEmpty) continue;
      porOtro.putIfAbsent(otro, () => []).add(m);
    }

    final resumenes = <ResumenConversacion>[];
    for (final entry in porOtro.entries) {
      final otro = entry.key;
      final conv = entry.value..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final ultimo = conv.last;
      resumenes.add(ResumenConversacion(
        otroUsuarioId: otro,
        nombre: nombres[otro] ?? 'Usuario',
        edad: edades[otro],
        verificado: verificados[otro] ?? false,
        ultimoMensaje: ultimo.contenido,
        ultimoEsMio: ultimo.emisorId == miId,
        timestamp: ultimo.timestamp,
        noLeidos: _noLeidos(miId, conv, leidosHasta[otro]),
        online: onlinePorUsuario[otro] ?? false,
        esMeGusta: misLikes.contains(otro),
        esMatch: tiemposMatch.containsKey(otro),
      ));
    }

    for (final match in tiemposMatch.entries) {
      if (porOtro.containsKey(match.key)) continue;
      resumenes.add(ResumenConversacion(
        otroUsuarioId: match.key,
        nombre: nombres[match.key] ?? 'Usuario',
        edad: edades[match.key],
        verificado: verificados[match.key] ?? false,
        ultimoMensaje: 'Has hecho match. ¡Salúdale!',
        ultimoEsMio: false,
        timestamp: match.value,
        noLeidos: 0,
        esMeGusta: misLikes.contains(match.key),
        esMatch: true,
      ));
    }

    resumenes.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return resumenes;
  }

  int _noLeidos(String miId, List<Mensaje> conv, DateTime? leidoHasta) {
    final leido = leidoHasta;
    if (leido != null) {
      return conv
          .where((m) => m.emisorId != miId && m.timestamp.isAfter(leido))
          .length;
    }
    DateTime? ultimoMio;
    for (final m in conv) {
      if (m.emisorId == miId) ultimoMio = m.timestamp;
    }
    final ultimo = ultimoMio;
    if (ultimo == null) {
      return conv.where((m) => m.emisorId != miId).length;
    }
    return conv
        .where((m) => m.emisorId != miId && m.timestamp.isAfter(ultimo))
        .length;
  }

  Future<void> marcarConversacionLeida(
      String otroUsuarioId, String miId) async {
    (_db.update(_db.matches)
          ..where((m) =>
              (m.usuarioAId.equals(miId) &
                  m.usuarioBId.equals(otroUsuarioId)) |
              (m.usuarioAId.equals(otroUsuarioId) &
                  m.usuarioBId.equals(miId)))
          ..write(MatchesCompanion(
            leidoHasta: Value(DateTime.now()),
          )));
  }


  Future<Usuario?> obtenerUsuario(String id) async {
    final filas = await (_db.select(_db.usuarios)
          ..where((u) => u.uuid.equals(id)))
        .get();
    return filas.isEmpty ? null : filas.first;
  }

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
    if (kUsarServidorLocal) return;
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
