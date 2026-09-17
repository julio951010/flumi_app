import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../config/env.dart';
import '../../core/base_datos_local/database.dart';
import '../../core/constantes/constantes.dart';
import '../../core/servicios/connectivity_service.dart';
import '../../core/servicios/notificacion_local_servicio.dart';
import '../../core/servicios/sync_service.dart';
import '../../core/utilidades/notificacion_navegador.dart';
import '../../core/utilidades/perfil_mapeo.dart';

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
  final String? fotoUrl;
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
    this.fotoUrl,
    this.online = false,
    this.esMeGusta = false,
    this.esMatch = false,
  });
}

class ChatRepositorio {
  /// Ventana de frescura de `ultima_conexion` para considerar en línea.
  static const _umbralEnLinea = Duration(minutes: 2);
  /// Tolerancia de reloj entre dispositivos para el corte de mensajes de una
  /// conversación borrada: un mensaje del otro usuario podría llevar un
  /// timestamp unos segundos detrás del momento en que yo borré. Se resta
  /// este margen al corte para no ocultar nunca mensajes nuevos por skew.
  static const _toleranciaBorrado = Duration(minutes: 1);

  /// true si el usuario está en línea según su última conexión remota y sus
  /// ajustes de privacidad (ocultar_en_linea).
  static bool estaEnLinea(Usuario u) {
    final ultima = u.ultimaConexion;
    if (u.ocultarEnLinea || ultima == null) return false;
    return DateTime.now().difference(ultima).abs() < _umbralEnLinea;
  }
  final AppDatabase _db;
  final SyncService? _sync;
  StreamSubscription? _realtimeSub;
  StreamSubscription? _realtimeMatchesSub;
  StreamSubscription? _realtimeProfilesSub;
  StreamSubscription? _connectivitySub;
  String? _userId;

  /// Presencia: latido de `ultima_conexion` y refresco periódico de la de los
  /// contactos (matches/likes), para que el indicador de en línea sea real.
  Timer? _presenciaTimer;
  String? _presenciaMiId;
  bool _presenciaEnCurso = false;

  /// Número de pantallas/servicios que han pedido la suscripción Realtime.
  /// La suscripción se cancela de verdad solo cuando llega a cero; así,
  /// cerrar una pantalla de chat no apaga el Realtime app-wide (que lo
  /// mantiene _NavegacionPrincipalState).
  int _suscripcionesRealtime = 0;

  // Indicador de escribiendo: un canal broadcast por conversación (clave
  // "a#b" ordenada). Un único canal global mezclaba salas al abrir varios
  // chats en la sesión.
  final Map<String, RealtimeChannel> _canalesEscribiendo = {};
  final Map<String, StreamController<bool>> _escribiendoCtrls = {};

  ChatRepositorio(this._db, [this._sync]);

  Stream<List<ResumenConversacion>> observarConversaciones(String miId) {
    late final StreamController<List<ResumenConversacion>> ctrl;
    StreamSubscription? subMsgs;
    StreamSubscription? subMatches;
    StreamSubscription? subUsuarios;
    StreamSubscription? subEliminadas;
    StreamSubscription? subLeidas;

    Future<void> recalcular() async {
      if (ctrl.isClosed) return;
      final msgs = await (_db.select(_db.mensajes)
            ..where((m) =>
                m.emisorId.equals(miId) | m.receptorId.equals(miId))
            ..orderBy([(m) => OrderingTerm.desc(m.timestamp)]))
          .get();
      final matches = await _db.select(_db.matches).get();
      final usuarios = await _db.select(_db.usuarios).get();
      ctrl.add(await _resumir(miId, msgs, matches, usuarios));
    }

    ctrl = StreamController<List<ResumenConversacion>>(
      onListen: () {
        subMsgs = (_db.select(_db.mensajes)
              ..where((m) =>
                  m.emisorId.equals(miId) | m.receptorId.equals(miId)))
            .watch()
            .listen((_) => recalcular());
        subMatches = _db.select(_db.matches).watch().listen((_) => recalcular());
        subUsuarios =
            _db.select(_db.usuarios).watch().listen((_) => recalcular());
        // Borrar/reactivar una conversación (tombstones) también recalcula.
        subEliminadas = _db
            .select(_db.conversacionesEliminadas)
            .watch()
            .listen((_) => recalcular());
        // Marcar como leída (conversacionesLeidas) también recalcula el badge.
        subLeidas = _db
            .select(_db.conversacionesLeidas)
            .watch()
            .listen((_) => recalcular());
        recalcular();
      },
      onCancel: () {
        subMsgs?.cancel();
        subMsgs = null;
        subMatches?.cancel();
        subMatches = null;
        subUsuarios?.cancel();
        subUsuarios = null;
        subEliminadas?.cancel();
        subEliminadas = null;
        subLeidas?.cancel();
        subLeidas = null;
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
      final recibidos = await (_db.select(_db.historialLikes)
            ..where((h) => h.usuarioLikeadoId.equals(miId))
            ..orderBy([(h) => OrderingTerm.desc(h.timestamp)]))
          .get();
      final misLikes = {
        for (final l in await (_db.select(_db.historialLikes)
              ..where((h) => h.usuarioId.equals(miId)))
            .get())
          l.usuarioLikeadoId
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

      for (final like in recibidos) {
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

  Future<List<ResumenConversacion>> _resumir(
      String miId, List<Mensaje> msgs, List<Matche> matches, List<Usuario> usuarios) async {
    final nombres = {for (final u in usuarios) u.uuid: u.nombre};
    final edades = {for (final u in usuarios) u.uuid: u.edad};
    final verificados = {for (final u in usuarios) u.uuid: u.verificadoStatus};
    final fotos = {
      for (final u in usuarios)
        u.uuid: u.fotosUrls.isNotEmpty ? u.fotosUrls.first : null
    };
    final onlinePorUsuario = {
      for (final u in usuarios) u.uuid: estaEnLinea(u)
    };
    final misLikes = {
      for (final l in await (_db.select(_db.historialLikes)
            ..where((h) => h.usuarioId.equals(miId)))
          .get())
        l.usuarioLikeadoId
    };
    // Likes recibidos: su leido_hasta respalda el badge de no leídos de las
    // conversaciones like-only (sin match), donde no hay fila en matches.
    final likesRecibidos = await (_db.select(_db.historialLikes)
          ..where((h) => h.usuarioLikeadoId.equals(miId)))
        .get();
    final porOtro = <String, List<Mensaje>>{};
    final tiemposMatch = <String, DateTime>{};
    final leidosHasta = <String, DateTime>{};
    // Conversaciones borradas solo para mí: quedan ocultas de la lista
    // aunque mensajes y match sigan en local (los re-descarga el sync).
    // Al retomar actividad (reactivada) vuelven a la lista, pero el corte
    // eliminadoEn sigue descartando el historial anterior al borrado.
    final cortesBorrado = <String, DateTime>{};
    final ocultas = <String>{};
    for (final t in await _db.select(_db.conversacionesEliminadas).get()) {
      cortesBorrado[t.otroUsuarioId] = t.eliminadoEn;
      if (!t.reactivada) ocultas.add(t.otroUsuarioId);
    }

    for (final match in matches) {
      final otro = match.usuarioAId == miId ? match.usuarioBId : match.usuarioAId;
      if (otro == miId || otro.isEmpty) continue;
      tiemposMatch.putIfAbsent(otro, () => match.timestampMatch);
      final leido = match.leidoHasta;
      if (leido != null) leidosHasta.putIfAbsent(otro, () => leido);
    }
    // Respaldo like-only (solo si el match no definió leído).
    for (final like in likesRecibidos) {
      final leido = like.leidoHasta;
      if (leido != null) leidosHasta.putIfAbsent(like.usuarioId, () => leido);
    }
    // Marcador local de lectura por conversación: tiene prioridad porque es la
    // fuente de verdad del estado de lectura del usuario en este dispositivo
    // (e incluye cuentas oficiales sin match ni like).
    for (final r in await _db.select(_db.conversacionesLeidas).get()) {
      leidosHasta[r.otroUsuarioId] = r.leidoHasta;
    }

    for (final m in msgs) {
      final otro = m.emisorId == miId ? m.receptorId : m.emisorId;
      if (otro.isEmpty) continue;
      // Historial anterior al borrado de la conversación: se descarta aunque
      // la conversación haya retomado actividad.
      final corte = cortesBorrado[otro];
      if (corte != null &&
          !m.timestamp.isAfter(corte.subtract(_toleranciaBorrado))) {
        continue;
      }
      porOtro.putIfAbsent(otro, () => []).add(m);
    }

    final resumenes = <ResumenConversacion>[];
    for (final entry in porOtro.entries) {
      final otro = entry.key;
      if (ocultas.contains(otro)) continue;
      final conv = entry.value..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final ultimo = conv.last;
      resumenes.add(ResumenConversacion(
        otroUsuarioId: otro,
        nombre: cuentasOficialesFlumi[otro] ?? nombres[otro] ?? 'Usuario',
        edad: edades[otro],
        verificado: verificados[otro] ?? false,
        fotoUrl: fotosOficialesFlumi[otro] ?? fotos[otro],
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
      if (ocultas.contains(match.key)) continue;
      resumenes.add(ResumenConversacion(
        otroUsuarioId: match.key,
        nombre: cuentasOficialesFlumi[match.key] ?? nombres[match.key] ?? 'Usuario',
        edad: edades[match.key],
        verificado: verificados[match.key] ?? false,
        fotoUrl: fotosOficialesFlumi[match.key] ?? fotos[match.key],
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
    final ahora = DateTime.now();
    // Primero local (la UI refleja el leído al instante); el remoto se
    // propaga sin bloquear la lectura ni depender de la red.
    await (_db.update(_db.matches)
          ..where((m) =>
              (m.usuarioAId.equals(miId) &
                  m.usuarioBId.equals(otroUsuarioId)) |
              (m.usuarioAId.equals(otroUsuarioId) &
                  m.usuarioBId.equals(miId))))
        .write(MatchesCompanion(
          leidoHasta: Value(ahora),
        ));
    // Conversaciones like-only (quien me dio like sin match todavía): el
    // leído también se guarda en historial_likes para que el badge de no
    // leídos de la lista de Conversaciones funcione sin match. Se escriben
    // las dos direcciones por si la conversación existe en cualquiera de
    // los dos sentidos.
    await (_db.update(_db.historialLikes)
          ..where((h) =>
              h.usuarioId.equals(miId) & h.usuarioLikeadoId.equals(otroUsuarioId)))
        .write(HistorialLikesCompanion(leidoHasta: Value(ahora)));
    await (_db.update(_db.historialLikes)
          ..where((h) =>
              h.usuarioId.equals(otroUsuarioId) & h.usuarioLikeadoId.equals(miId)))
        .write(HistorialLikesCompanion(leidoHasta: Value(ahora)));
    // Marcador local de lectura por conversación (fuente de verdad para el
    // badge de no leídos y el estado "visto"). Cubre también las cuentas
    // oficiales, que no tienen fila en matches ni historial_likes.
    await _db.into(_db.conversacionesLeidas).insertOnConflictUpdate(
        ConversacionesLeidasCompanion(
            otroUsuarioId: Value(otroUsuarioId), leidoHasta: Value(ahora)));
    if (!kUsarServidorLocal && ConnectivityService.instancia.hayConexion) {
      try {
        await Supabase.instance.client
            .from(tablaMatches)
            .update({'leido_hasta': ahora.toUtc().toIso8601String()})
            .or(
                '(usuario_a_id.eq.$miId,usuario_b_id.eq.$otroUsuarioId),(usuario_a_id.eq.$otroUsuarioId,usuario_b_id.eq.$miId)')
            .timeout(const Duration(seconds: 5));
        // El like propio también guarda leído (like-only). RLS solo permite
        // tocar el like propio (usuario_gestiona_sus_likes).
        await Supabase.instance.client
            .from('historial_likes')
            .update({'leido_hasta': ahora.toUtc().toIso8601String()})
            .eq('usuario_id', miId)
            .eq('usuario_likeado_id', otroUsuarioId)
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
  }


  /// Marca como leídas todas las conversaciones (popup "Marcar todos como
  /// leídos" de la pestaña Chats).
  Future<void> marcarTodasConversacionesLeidas(String miId) async {
    final socios = <String>{};
    // Socios desde matches.
    final matches = await (_db.select(_db.matches)
          ..where((m) =>
              m.usuarioAId.equals(miId) | m.usuarioBId.equals(miId)))
        .get();
    for (final m in matches) {
      socios.add(m.usuarioAId == miId ? m.usuarioBId : m.usuarioAId);
    }
    // Like-only (solo me dieron like, sin match).
    final likes = await (_db.select(_db.historialLikes)
          ..where((h) => h.usuarioLikeadoId.equals(miId)))
        .get();
    for (final like in likes) {
      socios.add(like.usuarioId);
    }
    // Cualquier conversación que exista solo por mensajes (sin match ni like).
    final mensajes = await (_db.select(_db.mensajes)
          ..where((m) => m.emisorId.equals(miId) | m.receptorId.equals(miId)))
        .get();
    for (final m in mensajes) {
      final otro = m.emisorId == miId ? m.receptorId : m.emisorId;
      if (otro.isNotEmpty) socios.add(otro);
    }
    // Cuentas oficiales (sin match ni like).
    socios.addAll(cuentasOficialesFlumi.keys);
    for (final otroId in socios) {
      await marcarConversacionLeida(otroId, miId);
    }
  }

  Future<Usuario?> obtenerUsuario(String id) async {
    final filas = await (_db.select(_db.usuarios)
          ..where((u) => u.uuid.equals(id)))
        .get();
    return filas.isEmpty ? null : filas.first;
  }

  /// El perfil del usuario en vivo (cambios de presencia incluidos), para
  /// que el header del chat refleje el indicador en línea sin recargar.
  Stream<Usuario?> observarUsuario(String id) {
    return (_db.select(_db.usuarios)
          ..where((u) => u.uuid.equals(id)))
        .watch()
        .map((filas) => filas.isEmpty ? null : filas.first);
  }

  /// Corte de mensajes de una conversación que el usuario borró solo para él
  /// (null si nunca la borró). Se mantiene aunque la conversación se haya
  /// reactivado: el historial anterior al borrado nunca vuelve a mostrarse.
  Future<DateTime?> _corteBorrado(String otroUsuarioId) async {
    final fila = await (_db.select(_db.conversacionesEliminadas)
          ..where((t) => t.otroUsuarioId.equals(otroUsuarioId)))
        .getSingleOrNull();
    return fila?.eliminadoEn;
  }

  Future<List<Mensaje>> obtenerConversacion(
      String otroUsuarioId, String miId) async {
    final corte = await _corteBorrado(otroUsuarioId);
    return (_db.select(_db.mensajes)
          ..where((m) =>
              ((m.emisorId.equals(miId) &
                          m.receptorId.equals(otroUsuarioId)) |
                      (m.emisorId.equals(otroUsuarioId) &
                          m.receptorId.equals(miId))) &
                  (corte == null
                          ? const Constant(true)
                          : m.timestamp.isBiggerThanValue(
                              corte.subtract(_toleranciaBorrado))))
          ..orderBy([(m) => OrderingTerm.asc(m.timestamp)]))
        .get();
  }

  Stream<List<Mensaje>> observarConversacion(
      String otroUsuarioId, String miId) {
    return Stream.fromFuture(_corteBorrado(otroUsuarioId)).asyncExpand(
      (corte) => (_db.select(_db.mensajes)
            ..where((m) =>
                ((m.emisorId.equals(miId) &
                            m.receptorId.equals(otroUsuarioId)) |
                        (m.emisorId.equals(otroUsuarioId) &
                            m.receptorId.equals(miId))) &
                    (corte == null
                        ? const Constant(true)
                        : m.timestamp.isBiggerThanValue(
                            corte.subtract(_toleranciaBorrado))))
            ..orderBy([(m) => OrderingTerm.asc(m.timestamp)]))
          .watch(),
    );
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
    // Escribir yo reactiva la conversación si la había borrado solo para mí.
    await _reactivarConversacion(receptorId, emisorId);
    // Write-through: intenta subir el mensaje a Supabase de inmediato;
    // si falla queda pendiente para el siguiente sync.
    unawaited(_sync?.sincronizarMensajesPendientes());

    // Notificación inteligente: local si foreground, push si background
    unawaited(NotificacionLocalServicio.instancia.notificarInteligente(
      titulo: 'Nuevo mensaje',
      cuerpo: contenido,
      usuarioIdDestino: receptorId,
      categoria: 'mensajes',
    ));
  }

  Future<void> borrarConversacion(String otroUsuarioId, String miId) async {
    // Borrar la conversación SOLO para mí (estilo WhatsApp): el match y los
    // mensajes siguen en el servidor y en el otro cliente. El "tombstone"
    // local (conversaciones_eliminadas) oculta la conversación de mi lista
    // aunque el siguiente sync re-descargue mensajes y match.
    await _db.into(_db.conversacionesEliminadas).insertOnConflictUpdate(
          ConversacionesEliminadasCompanion(
            otroUsuarioId: Value(otroUsuarioId),
            eliminadoEn: Value(DateTime.now()),
            reactivada: const Value(false),
          ),
        );
    // Marcador remoto: si el otro también borra la conversación, el servidor
    // elimina físicamente los mensajes del par (no queda basura guardada
    // para siempre). Si el otro NO borra, el marcador solo sirve para
    // mantener el borrado tras una reinstalación.
    unawaited(_subirMarcadorBorrado(miId, otroUsuarioId));
    // Borrar los mensajes de mi copia local: la conversación desaparece de
    // la lista. Si el otro escribe, la conversación vuelve, pero el corte
    // (eliminadoEn) impide que reaparezca el historial anterior al borrado.
    await (_db.delete(_db.mensajes)
          ..where((m) =>
              (m.emisorId.equals(miId) & m.receptorId.equals(otroUsuarioId)) |
              (m.emisorId.equals(otroUsuarioId) & m.receptorId.equals(miId))))
        .go();
  }

  /// Sube el marcador "borré la conversación con X" (best-effort). RLS:
  /// solo puedo escribir mi propia fila (usuario_id = yo).
  Future<void> _subirMarcadorBorrado(
      String miId, String otroUsuarioId) async {
    if (kUsarServidorLocal || !ConnectivityService.instancia.hayConexion) {
      return;
    }
    try {
      await Supabase.instance.client
          .from(tablaConversacionesBorradas)
          .upsert({
            'usuario_id': miId,
            'otro_usuario_id': otroUsuarioId,
            'borrado_en': DateTime.now().toUtc().toIso8601String(),
          })
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  /// Reactiva una conversación borrada solo para mí: la conversación vuelve a
  /// la lista cuando cualquiera de los dos escribe de nuevo, pero el corte
  /// (eliminadoEn) permanece: el historial anterior al borrado no reaparece.
  /// También borra el marcador remoto propio (el borrado dejó de estar
  /// vigente) para que no reaparezca en el siguiente sync.
  Future<void> _reactivarConversacion(
      String otroUsuarioId, String miId) async {
    final fila = await (_db.select(_db.conversacionesEliminadas)
          ..where((t) => t.otroUsuarioId.equals(otroUsuarioId)))
        .getSingleOrNull();
    if (fila == null) return;
    if (!fila.reactivada) {
      // Purga física del historial anterior al borrado: filas re-descargadas
      // por builds viejos, reinsertadas por Realtime (p. ej. un edit de un
      // mensaje viejo) o que quedaron de antes del corte. Se excluyen los
      // pendientes (aún no subidos: son mensajes nuevos, no historial
      // borrado). Con tolerancia de reloj: un mensaje nuevo con skew no se
      // borra por error.
      await (_db.delete(_db.mensajes)
            ..where((m) =>
                (((m.emisorId.equals(miId) &
                            m.receptorId.equals(otroUsuarioId)) |
                        (m.emisorId.equals(otroUsuarioId) &
                            m.receptorId.equals(miId))) &
                    m.timestamp.isBiggerThanValue(fila.eliminadoEn
                        .subtract(_toleranciaBorrado))
                        .not()) &
                    m.pendienteDeSincronizar.equals(false)))
          .go();
      await (_db.update(_db.conversacionesEliminadas)
            ..where((t) => t.otroUsuarioId.equals(otroUsuarioId)))
          .write(const ConversacionesEliminadasCompanion(
        reactivada: Value(true),
      ));
    }
    if (kUsarServidorLocal || !ConnectivityService.instancia.hayConexion) {
      return;
    }
    try {
      await Supabase.instance.client
          .from(tablaConversacionesBorradas)
          .delete()
          .eq('usuario_id', miId)
          .eq('otro_usuario_id', otroUsuarioId)
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  /// Hasta qué mensaje (timestamp) el otro usuario ha leído la conversación.
  /// Cambia en vivo por Realtime cuando el otro marca leído.
  Stream<DateTime?> observarLeidoHasta(String otroUsuarioId, String miId) {
    return (_db.select(_db.matches)
          ..where((m) =>
              (m.usuarioAId.equals(miId) & m.usuarioBId.equals(otroUsuarioId)) |
              (m.usuarioAId.equals(otroUsuarioId) & m.usuarioBId.equals(miId))))
        .watch()
        .map((filas) => filas.isEmpty ? null : filas.first.leidoHasta);
  }

  Future<void> editarMensaje({
    required String uuid,
    required String contenido,
  }) async {
    await (_db.update(_db.mensajes)
          ..where((m) => m.uuid.equals(uuid)))
        .write(MensajesCompanion(
          contenido: Value(contenido),
          pendienteDeSincronizar: const Value(true),
          estadoEnvio: const Value('enviando'),
          intentosDeSincronizacion: const Value(0),
        ));
    unawaited(_sync?.sincronizarMensajesPendientes());
  }

  Future<void> eliminarMensaje({required String uuid}) async {
    await SyncService.recordarMensajeBorrado(uuid);
    await (_db.delete(_db.mensajes)..where((m) => m.uuid.equals(uuid))).go();
    // Best-effort: si la red está, se borra en el servidor; si no, el purge
    // de sincronizarMensajesPendientes convergerá al faltar en el remoto.
    if (!kUsarServidorLocal && ConnectivityService.instancia.hayConexion) {
      try {
        await Supabase.instance.client
            .from(tablaMessages)
            .delete()
            .eq('id', uuid)
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
  }

  Future<void> reintentarMensaje({required String uuid}) async {
    await (_db.update(_db.mensajes)
          ..where((m) => m.uuid.equals(uuid)))
        .write(const MensajesCompanion(
          pendienteDeSincronizar: Value(true),
          estadoEnvio: Value('enviando'),
          intentosDeSincronizacion: Value(0),
        ));
    unawaited(_sync?.sincronizarMensajesPendientes());
  }

  Future<void> reportarUsuario({
    required String miId,
    required String otroId,
    required String motivo,
  }) async {
    await _db.into(_db.reportes).insert(ReportesCompanion.insert(
      uuid: const Uuid().v4(),
      reportanteId: miId,
      reportadoId: otroId,
      motivo: motivo,
      timestamp: DateTime.now(),
    ));
    unawaited(_sync?.sincronizarReportesPendientes());
  }

  Future<void> bloquearUsuario({
    required String miId,
    required String otroId,
  }) async {
    await _db.into(_db.bloqueos).insert(BloqueosCompanion.insert(
      uuid: const Uuid().v4(),
      bloqueadorId: miId,
      bloqueadoId: otroId,
      timestamp: DateTime.now(),
    ));
    await borrarConversacion(otroId, miId);
    unawaited(_sync?.sincronizarBloqueosPendientes());
  }

  // ------------------------------------------------------------
  // Indicador de escribiendo (canal Realtime broadcast, sin tabla remota)
  // ------------------------------------------------------------
  String _claveConversacion(String a, String b) {
    final l = [a, b]..sort();
    return '${l[0]}#${l[1]}';
  }

  /// El otro usuario está escribiendo (bool). Se emite en vivo mientras la
  /// pantalla de chat esté abierta. Cada conversación tiene su canal.
  Stream<bool> observarEscribiendo(String otroUsuarioId, String miId) {
    final clave = _claveConversacion(otroUsuarioId, miId);
    final ctrl = _escribiendoCtrls.putIfAbsent(
      clave,
      () => StreamController<bool>.broadcast(),
    );
    if (kUsarServidorLocal || !ConnectivityService.instancia.hayConexion) {
      return ctrl.stream;
    }
    _canalesEscribiendo.putIfAbsent(clave, () {
      return Supabase.instance.client
          .channel('tip-$clave')
          .onBroadcast(event: 'escribiendo', callback: (payload) {
            final datos = payload['payload'] as Map?;
            if (datos == null) return;
            if (datos['usuario'] == miId) return;
            final c = _escribiendoCtrls[clave];
            if (c == null || c.isClosed) return;
            c.add(datos['escribiendo'] == true);
          })
          .subscribe();
    });
    return ctrl.stream;
  }

  void enviarEscribiendo({
    required String miId,
    required String otroUsuarioId,
    required bool escribiendo,
  }) {
    if (kUsarServidorLocal) return;
    final clave = _claveConversacion(otroUsuarioId, miId);
    final canal = _canalesEscribiendo.putIfAbsent(
      clave,
      () => Supabase.instance.client
          .channel('tip-$clave')
          .onBroadcast(event: 'escribiendo', callback: (_) {})
          .subscribe(),
    );
    canal.sendBroadcastMessage(event: 'escribiendo', payload: {
      'usuario': miId,
      'escribiendo': escribiendo,
    });
  }

  /// Libera el canal de escribiendo de una conversación (al cerrar su chat).
  void cerrarEscribiendo(String otroUsuarioId, String miId) {
    final clave = _claveConversacion(otroUsuarioId, miId);
    final canal = _canalesEscribiendo.remove(clave);
    final ctrl = _escribiendoCtrls.remove(clave);
    try {
      ctrl?.close();
    } catch (_) {}
    if (canal != null) {
      try {
        Supabase.instance.client.removeChannel(canal);
      } catch (_) {}
    }
  }

  void suscribirseARealtime(String userId) {
    _userId = userId;
    _suscripcionesRealtime++;
    _conectarRealtime();
  }

  /// (Re)crea las suscripciones a Realtime. Con refcount: solo vuelven a
  /// abrirse si alguien sigue suscrito (desde el arranque de la app o la
  /// reconexión de red), sin duplicarlas por cada pantalla abierta.
  void _conectarRealtime() {
    if (_suscripcionesRealtime == 0) return;
    _realtimeSub?.cancel();
    _realtimeSub = null;
    _realtimeMatchesSub?.cancel();
    _realtimeMatchesSub = null;
    _realtimeProfilesSub?.cancel();
    _realtimeProfilesSub = null;
    if (kUsarServidorLocal) return;
    final userId = _userId;
    if (userId == null) return;
    if (!ConnectivityService.instancia.hayConexion) {
      _escucharReconexion(userId);
      return;
    }

    // RLS (mensajes_visibles_solo_para_participantes) filtra en Realtime:
    // solo llegan los mensajes en los que soy emisor o receptor.
    _realtimeSub = Supabase.instance.client
        .from(tablaMessages)
        .stream(primaryKey: ['id'])
        .handleError((_) {})
        .listen((cambios) async {
      for (final cambio in cambios) {
        await _aplicarMensajeRemoto(cambio);
      }
    });

    // Fase 4: nuevos matches (los crea el trigger del like recíproco) y
    // cambios de leido_hasta/preview llegan en vivo a la BD local.
    // RLS (matches_visibles_solo_para_participantes) hace el filtro.
    _realtimeMatchesSub = Supabase.instance.client
        .from(tablaMatches)
        .stream(primaryKey: ['id'])
        .handleError((_) {})
        .listen((cambios) async {
      for (final cambio in cambios) {
        await _aplicarMatchRemoto(cambio);
      }
    });

    // Presencia en vivo: los latidos de ultima_conexion de otros usuarios
    // llegan por Realtime (profiles está publicado) y actualizan el
    // indicador de en línea sin esperar al sondeo de 30 s.
    _realtimeProfilesSub = Supabase.instance.client
        .from(tablaProfiles)
        .stream(primaryKey: ['id'])
        .handleError((_) {})
        .listen((cambios) async {
      for (final cambio in cambios) {
        await _aplicarPresenciaRemota(cambio);
      }
    });
  }

  Future<void> _aplicarMensajeRemoto(Map<String, dynamic> cambio) async {
    final dbId = cambio['id'] as String?;
    if (dbId == null) return;
    final emisorId = cambio['emisor_id'] as String?;
    final receptorId = cambio['receptor_id'] as String?;
    final miId = _userId;
    final local = await (_db.select(_db.mensajes)
          ..where((m) => m.uuid.equals(dbId)))
        .getSingleOrNull();
    // Evento DELETE (el otro usuario borró un mensaje o toda la conversación):
    // el payload solo trae la PK; quitar el mensaje local.
    if (emisorId == null || receptorId == null) {
      await (_db.delete(_db.mensajes)
            ..where((m) => m.uuid.equals(dbId)))
          .go();
      return;
    }
    // Un mensaje local pendiente de subir (p. ej. un edit recién guardado)
    // no se sobrescribe con el remoto: gana el local hasta que suba.
    if (local?.pendienteDeSincronizar ?? false) return;
    await _db.into(_db.mensajes).insertOnConflictUpdate(
          MensajesCompanion.insert(
            uuid: dbId,
            emisorId: emisorId,
            receptorId: receptorId,
            contenido: cambio['contenido'] as String? ?? '',
            timestamp: DateTime.parse(cambio['timestamp'] as String),
            pendienteDeSincronizar: const Value(false),
            estadoEnvio: Value(emisorId == miId ? 'enviado' : 'entregado'),
          ),
        );
    // Aviso del navegador solo cuando el mensaje es NUEVO para mí y el
    // remitente es otra persona (si ya existía es un echo o un edit).
    if (local == null &&
        miId != null &&
        receptorId == miId &&
        emisorId != miId) {
      // Anti-replay: al recargar o reconectar, Realtime puede re-entregar
      // eventos antiguos (mensajes ya leídos o de conversaciones borradas
      // que yo purgué de local). No son novedad: se descartan del aviso y
      // de la reactivación (la purga/filtros de corte ya se ocupan de ellos).
      final timestamp = DateTime.parse(cambio['timestamp'] as String);
      final corte = await _corteBorrado(emisorId);
      if (corte != null &&
          !timestamp.isAfter(corte.subtract(_toleranciaBorrado))) {
        return;
      }
      if (await _mensajeYaLeido(emisorId, timestamp)) return;
      // El otro me escribió de nuevo: la conversación vuelve a la lista
      // aunque yo la hubiera borrado solo para mí (estilo WhatsApp). No se
      // reactiva si lo tengo bloqueado.
      final bloqueado = await (_db.select(_db.bloqueos)
            ..where((b) =>
                b.bloqueadorId.equals(miId) & b.bloqueadoId.equals(emisorId))
            ..limit(1))
          .getSingleOrNull();
      if (bloqueado == null) {
        await _reactivarConversacion(emisorId, miId);
      }
      unawaited(
          _notificarMensajeNuevo(emisorId, cambio['contenido'] as String? ?? ''));
    }
  }

  /// True si el mensaje es anterior a mi corte de lectura de esa conversación
  /// (match o like-only): ya lo leí, no es una novedad.
  Future<bool> _mensajeYaLeido(String otroId, DateTime timestamp) async {
    final miId = _userId;
    if (miId == null) return false;
    final match = await (_db.select(_db.matches)
          ..where((m) =>
              (m.usuarioAId.equals(miId) & m.usuarioBId.equals(otroId)) |
              (m.usuarioAId.equals(otroId) & m.usuarioBId.equals(miId)))
          ..limit(1))
        .getSingleOrNull();
    final leidoMatch = match?.leidoHasta;
    if (leidoMatch != null && !timestamp.isAfter(leidoMatch)) return true;
    final like = await (_db.select(_db.historialLikes)
          ..where((h) =>
              h.usuarioId.equals(otroId) & h.usuarioLikeadoId.equals(miId))
          ..limit(1))
        .getSingleOrNull();
    final leidoLike = like?.leidoHasta;
    return leidoLike != null && !timestamp.isAfter(leidoLike);
  }

  /// Aplica un cambio de presencia remoto (ultima_conexion/ocultar_en_linea)
  /// a un usuario que ya tengo en la BD local. Solo toca esas dos columnas.
  Future<void> _aplicarPresenciaRemota(Map<String, dynamic> cambio) async {
    final id = cambio['id'] as String?;
    if (id == null || id == _presenciaMiId) return;
    final local = await (_db.select(_db.usuarios)
          ..where((u) => u.uuid.equals(id))
          ..limit(1))
        .getSingleOrNull();
    if (local == null) return;
    await (_db.update(_db.usuarios)
          ..where((u) => u.uuid.equals(id)))
        .write(UsuariosCompanion(
      ultimaConexion:
          Value(PerfilMapeo.parsearFecha(cambio['ultima_conexion'])),
      ocultarEnLinea: Value(PerfilMapeo.aBool(
          cambio['ocultar_en_linea'], local.ocultarEnLinea)),
    ));
  }

  Future<void> _notificarMensajeNuevo(String emisorId, String contenido) async {
    final u = await (_db.select(_db.usuarios)
          ..where((u) => u.uuid.equals(emisorId))
          ..limit(1))
        .getSingleOrNull();
    final nombre = cuentasOficialesFlumi[emisorId] ?? u?.nombre ?? 'Alguien';
    await notificarNavegador('Flumi', 'Nuevo mensaje de $nombre: $contenido');
  }

  Future<void> _aplicarMatchRemoto(Map<String, dynamic> cambio) async {
    final dbId = cambio['id'] as String?;
    final a = cambio['usuario_a_id'] as String?;
    final b = cambio['usuario_b_id'] as String?;
    if (dbId == null) return;
    // Evento DELETE (el otro usuario borró la conversación): el payload solo
    // trae la PK; quitar el match local para que desaparezca de la lista.
    if (a == null || b == null) {
      await (_db.delete(_db.matches)
            ..where((m) => m.uuid.equals(dbId)))
          .go();
      return;
    }
    final timestamp = cambio['timestamp_match'] as String?;
    final preview = cambio['ultimo_mensaje_preview'] as String?;
    final ultimoTs =
        cambio['ultimo_mensaje_timestamp'] as String?;
    final leido = cambio['leido_hasta'] as String?;
    final previo = await (_db.select(_db.matches)
          ..where((m) => m.uuid.equals(dbId))
          ..limit(1))
        .getSingleOrNull();
    await _db.into(_db.matches).insertOnConflictUpdate(
      MatchesCompanion.insert(
        uuid: dbId,
        usuarioAId: a,
        usuarioBId: b,
        timestampMatch:
            timestamp != null ? DateTime.parse(timestamp) : DateTime.now(),
        pendienteDeSincronizar: const Value(false),
        ultimoMensajePreview: Value(preview),
        ultimoMensajeTimestamp:
            Value(ultimoTs != null ? DateTime.parse(ultimoTs) : null),
        leidoHasta: Value(SyncService.leidoHastaMasReciente(
          previo?.leidoHasta,
          leido != null ? DateTime.parse(leido) : null,
        )),
      ),
    );
  }

  void _escucharReconexion(String userId) {
    _connectivitySub?.cancel();
    _connectivitySub =
        ConnectivityService.instancia.stream.listen((estado) {
      if (estado == EstadoConexion.conectado) {
        _connectivitySub?.cancel();
        _connectivitySub = null;
        _conectarRealtime();
      }
    });
  }

  // ------------------------------------------------------------
  // Presencia (ultima_conexion)
  // ------------------------------------------------------------
  /// Inicia el latido de presencia: sube `ultima_conexion` y refresca la de
  /// los contactos cada 30 s, además de recuperar mensajes que el Realtime
  /// pudiera haber perdido. Idempotente (un solo timer app-wide).
  void iniciarPresencia(String miId) {
    _presenciaMiId = miId;
    if (kUsarServidorLocal) return;
    _presenciaTimer ??= Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_latidoPresencia()),
    );
    unawaited(_latidoPresencia());
  }

  Future<void> _latidoPresencia() async {
    if (_presenciaEnCurso || kUsarServidorLocal) return;
    if (!ConnectivityService.instancia.hayConexion) return;
    final miId = _presenciaMiId;
    if (miId == null) return;
    _presenciaEnCurso = true;
    try {
      try {
        await Supabase.instance.client
            .from(tablaProfiles)
            .update({'ultima_conexion': DateTime.now().toUtc().toIso8601String()})
            .eq('id', miId)
            .timeout(const Duration(seconds: 8));
      } catch (_) {}
      await _refrescarPresenciaDeConversaciones(miId);
      // Recupera mensajes que el Realtime pudo perder (el historial completo
      // se descarga en sincronizarMensajesPendientes).
      unawaited(_sync?.sincronizarMensajesPendientes());
    } finally {
      _presenciaEnCurso = false;
    }
  }

  /// Actualiza `ultima_conexion`/`ocultar_en_linea` de mis matches y likes
  /// desde el servidor (solo esas columnas, sin tocar el resto del perfil).
  Future<void> _refrescarPresenciaDeConversaciones(String miId) async {
    try {
      final matches = await (_db.select(_db.matches)
            ..where((m) =>
                m.usuarioAId.equals(miId) | m.usuarioBId.equals(miId)))
          .get();
      final likes = await (_db.select(_db.historialLikes)
            ..where((h) => h.usuarioLikeadoId.equals(miId)))
          .get();
      final ids = <String>{
        for (final m in matches)
          m.usuarioAId == miId ? m.usuarioBId : m.usuarioAId,
        for (final l in likes) l.usuarioId,
      }..remove(miId);
      if (ids.isEmpty) return;

      final remoto = await Supabase.instance.client
          .from(tablaProfiles)
          .select('id,ultima_conexion,ocultar_en_linea')
          .inFilter('id', ids.toList())
          .timeout(const Duration(seconds: 8));
      final filas = (remoto as List).map((f) => f as Map<String, dynamic>);
      await _db.batch((batch) {
        for (final f in filas) {
          final id = f['id'] as String?;
          if (id == null) continue;
          batch.update(_db.usuarios, UsuariosCompanion(
            uuid: Value(id),
            ultimaConexion:
                Value(PerfilMapeo.parsearFecha(f['ultima_conexion'])),
            ocultarEnLinea:
                Value(PerfilMapeo.aBool(f['ocultar_en_linea'], false)),
          ));
        }
      });
    } catch (_) {}
  }

  void cancelarRealtime() {
    if (_suscripcionesRealtime > 0) _suscripcionesRealtime--;
    if (_suscripcionesRealtime > 0) return;
    _realtimeSub?.cancel();
    _realtimeSub = null;
    _realtimeMatchesSub?.cancel();
    _realtimeMatchesSub = null;
    _realtimeProfilesSub?.cancel();
    _realtimeProfilesSub = null;
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _presenciaTimer?.cancel();
    _presenciaTimer = null;
    for (final clave in _canalesEscribiendo.keys.toList()) {
      try {
        Supabase.instance.client.removeChannel(_canalesEscribiendo[clave]!);
      } catch (_) {}
    }
    _canalesEscribiendo.clear();
    for (final ctrl in _escribiendoCtrls.values) {
      try {
        ctrl.close();
      } catch (_) {}
    }
    _escribiendoCtrls.clear();
  }
}
