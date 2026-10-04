import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../config/env.dart';
import '../constantes/constantes.dart';
import '../base_datos_local/database.dart';
import '../utilidades/perfil_mapeo.dart';
import '../utilidades/notificacion_navegador.dart';
import 'connectivity_service.dart';
import 'estado_servidor_servicio.dart';
import 'preferencias_notificaciones_servicio.dart';

class SyncService {
  SyncService(this._db);

  final AppDatabase _db;

  bool _sincronizando = false;

  /// Tolerancia de reloj entre dispositivos para el corte de mensajes de una
  /// conversación borrada: un mensaje del otro usuario podría llevar un
  /// timestamp unos segundos detrás del momento en que yo borré. Se resta
  /// este margen al corte para no ocultar nunca mensajes nuevos por skew.
  static const _toleranciaBorrado = Duration(minutes: 1);

  Future<void> sincronizarTodo({String? userId, bool alIniciarSesion = false}) async {
    if (_sincronizando) return;

    _sincronizando = true;
    try {
      // El perfil primero (es la base del resto), luego el resto en paralelo
      // para que login y arranque no esperen 8 idas y vueltas en cadena.
      await _sincronizarPerfilPropio(userId, alIniciarSesion);
      await Future.wait([
        sincronizarSuscripciones(userId),
        sincronizarUsosDiarios(userId),
        sincronizarMensajesPendientes(),
        sincronizarMatchesPendientes(),
        sincronizarReportesPendientes(),
        sincronizarBloqueosPendientes(),
        sincronizarVisitas(userId),
        sincronizarHistorialLikes(userId),
        sincronizarRechazos(userId),
        sincronizarConversacionesBorradas(userId),
        sincronizarConversacionesLeidas(userId),
        _sincronizarFeedCercanoDesdePerfilPropio(),
      ]);
    } catch (e) {
      // Un fallo de red no debe bloquear el resto de la app.
      print('[sync] Error en sincronizarTodo: $e');
      EstadoServidorServicio.instancia.marcarFallo(e);
    } finally {
      _sincronizando = false;
    }
  }

  /// Sincroniza Ãºnicamente el perfil propio de inmediato.
  /// Se usa tras editar el perfil o cambiar ajustes de privacidad,
  /// para no depender Ãºnicamente de los disparadores de conectividad/auth.
  Future<void> sincronizarPerfil({String? userId}) async {
    try {
      await _sincronizarPerfilPropio(userId);
    } catch (_) {}
  }

  /// Garantiza que exista un perfil propio local: lo descarga de Supabase
  /// o lo crea a partir del usuario autenticado. Devuelve true si existe.
  /// `userId` debe venir del evento de auth (nunca de auth.currentUser justo
  /// tras iniciar sesiÃ³n: puede apuntar todavÃ­a al usuario anterior).
  Future<bool> asegurarPerfilPropio([String? userId]) async {
    try {
      await _sincronizarPerfilPropio(userId);
    } catch (_) {}
    return (await (_db.select(_db.usuarios)
              ..where((u) => u.esPerfilPropio.equals(true)))
            .getSingleOrNull()) !=
        null;
  }

  /// True mientras un sincronizado completo estÃ¡ en curso (evita tormentas
  /// de refrescos cuando muchas pantallas piden datos a la vez).
  bool get estaSincronizando => _sincronizando;

  /// Id del usuario autenticado actual (o 'local-dev' con servidor local).
  String? get userIdActual => _obtenerUserId();

  /// Refresca (o crea) en la BD local el perfil remoto de un usuario.
  /// Devuelve true si el servidor tenÃ­a datos y se guardaron.
  Future<bool> refrescarPerfilRemoto(String uuid) async {
    if (!ConnectivityService.instancia.hayConexion) return false;
    try {
      final remoto = await _fetchPerfil(uuid);
      if (remoto == null) return false;
      // Si este perfil es el propio y tiene cambios locales sin subir, la
      // descarga remota podrÃ­a revertirlos con datos viejos: el local manda.
      final conPendientes = await (_db.select(_db.usuarios)
            ..where((u) =>
                u.uuid.equals(uuid) &
                u.esPerfilPropio.equals(true) &
                u.pendienteDeSincronizar.equals(true)))
          .getSingleOrNull();
      if (conPendientes != null) return false;
      await _db.into(_db.usuarios).insertOnConflictUpdate(
            PerfilMapeo.perfilRemotoACompanion(remoto, esPropio: uuid == userIdActual)
                .copyWith(
              pendienteDeSincronizar: const Value(false),
            ),
          );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------
  // Perfil propio
  // ------------------------------------------------------------
  // alIniciarSesion: en el login siempre intentamos cargar el perfil desde
  // Supabase (fuente de verdad) y solo nos quedamos con la cachÃ© local si el
  // servidor no devuelve datos. Nunca sobrescribimos datos locales buenos con
  // un perfil vacÃ­o.
  Future<void> _sincronizarPerfilPropio([String? userId, bool alIniciarSesion = false]) async {
    final id = userId ?? _obtenerUserId();
    if (id == null) return;

    // Limpieza: si en la BD local quedaron perfiles propios de OTRAS cuentas
    // (p. ej. por logins previos con otra cuenta), se descartan para que solo
    // exista el del usuario autenticado y el getSingleOrNull posterior no
    // lance MultipleResultException.
    await (_db.delete(_db.usuarios)
          ..where((u) =>
              u.esPerfilPropio.equals(true) & u.uuid.equals(id).not()))
        .go();

    final local = await (_db.select(_db.usuarios)
          ..where((u) => u.esPerfilPropio.equals(true)))
        .getSingleOrNull();

    // Subir primero los cambios pendientes para dejar el servidor al dÃ­a.
    if (local != null) {
      final pendientes = await (_db.select(_db.usuarios)
            ..where((u) =>
                u.esPerfilPropio.equals(true) &
                u.pendienteDeSincronizar.equals(true)))
          .getSingleOrNull();
      if (pendientes != null) {
    try {
      await _subirPerfil(pendientes);
      await (_db.update(_db.usuarios)
            ..where((u) => u.uuid.equals(pendientes.uuid)))
          .write(UsuariosCompanion(
        pendienteDeSincronizar: const Value(false),
        ultimaSincronizacionTimestamp: Value(DateTime.now()),
      ));
    } catch (e) {
      // La subida fallÃ³ (RLS, CHECK, tipos de columna, red...). No borramos
      // la marca pendiente para reintentar mÃ¡s tarde, pero lo registramos
      // para poder diagnosticar por quÃ© el perfil no llega a Supabase.
      print('[sync] Error al subir el perfil propio: $e');
    }
      }
    }

    // En el login cargamos desde Supabase; si hay perfil remoto lo usamos,
    // si no (sin red / sin perfil en servidor) conservamos la cachÃ© local.
    if (alIniciarSesion) {
      Map<String, dynamic>? remoto;
      try {
        if (ConnectivityService.instancia.hayConexion) {
          remoto = await _fetchPerfil(id);
        }
      } catch (_) {
        remoto = null;
      }
      if (remoto != null) {
        // Si la cachÃ© local tiene cambios pendientes que aÃºn no se subieron
        // (p. ej. fotos reciÃ©n editadas/eliminadas), NO la sobreescribimos
        // con el remoto: el servidor podrÃ­a traer datos viejos y revertirÃ­a
        // el cambio del usuario. El upload ya se intentÃ³ arriba; si fallÃ³,
        // la marca pendiente se conserva y el cambio se reintentarÃ¡.
        if (local != null && local.pendienteDeSincronizar) {
          return;
        }
        // Re-chequeo justo antes de sobrescribir: la descarga remota pudo
        // haber arrancado ANTES de que el usuario guardara un cambio, y al
        // terminar (red lenta) traerÃ­a datos viejos que revertirÃ­an la ediciÃ³n
        // local reciÃ©n escrita. Si en este instante hay pendientes, el cambio
        // local manda y se preserva (el upload fire-and-forget de la ediciÃ³n
        // ya estÃ¡ subiÃ©ndolo).
        final reciente = await (_db.select(_db.usuarios)
              ..where((u) =>
                  u.esPerfilPropio.equals(true) &
                  u.pendienteDeSincronizar.equals(true)))
            .getSingleOrNull();
        if (reciente != null) {
          return;
        }
        // Si ya tenemos cachÃ© local, NO la sobreescribimos con un perfil
        // vacÃ­o del servidor (p. ej. porque la subida fallÃ³ silenciosamente).
        // Usamos el servidor solo cuando este trae datos; si no, conservamos
        // la cachÃ© local para no perder la informaciÃ³n del usuario.
        // TAMBIÃ‰N protegemos: si el local ya tiene perfilCompletado=true,
        // no lo rebajamos con un remoto que tenga perfil_completado=false.
        if (local != null &&
            (!_remotoTieneDatos(remoto) ||
                (local.perfilCompletado && remoto['perfil_completado'] != true))) {
          return;
        }
        try {
          await _db.into(_db.usuarios).insertOnConflictUpdate(
                PerfilMapeo.perfilRemotoACompanion(remoto, esPropio: true).copyWith(
                  pendienteDeSincronizar: const Value(false),
                ),
              );
        } catch (_) {}
        return;
      }
      // Sin datos remotos: mantenemos el local (si existe) o creamos respaldo.
      if (local != null) return;
      final respaldo = _perfilDesdeAuth(id);
      try {
        await _db.into(_db.usuarios).insertOnConflictUpdate(
              PerfilMapeo.perfilRemotoACompanion(respaldo, esPropio: true).copyWith(
                pendienteDeSincronizar: const Value(true),
              ),
            );
      } catch (_) {}
      return;
    }

    // Resto de sincronizaciones (p. ej. tras editar): solo descargamos si no
    // hay perfil local.
    if (local == null) {
      Map<String, dynamic>? remoto;
      try {
        if (ConnectivityService.instancia.hayConexion) {
          remoto = await _fetchPerfil(id);
        }
      } catch (_) {
        remoto = null;
      }
      remoto ??= _perfilDesdeAuth(id);
      await _db.into(_db.usuarios).insertOnConflictUpdate(
            PerfilMapeo.perfilRemotoACompanion(remoto, esPropio: true).copyWith(
              pendienteDeSincronizar: const Value(true),
            ),
          );
    }
  }

  // ------------------------------------------------------------
  // Mensajes
  // ------------------------------------------------------------
  /// Tombstones de mensajes borrados (persisten en prefs): la descarga del
  /// historial los salta para que un borrado offline no resucite al
  /// sincronizar.
  static const _prefsBorrados = 'flumi_mensajes_borrados';
  static const _maxBorrados = 500;

  static Future<void> recordarMensajeBorrado(String uuid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lista = prefs.getStringList(_prefsBorrados) ?? <String>[];
      lista.remove(uuid);
      lista.add(uuid);
      while (lista.length > _maxBorrados) {
        lista.removeAt(0);
      }
      await prefs.setStringList(_prefsBorrados, lista);
    } catch (_) {}
  }

  static Future<Set<String>> _leerMensajesBorrados() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_prefsBorrados)?.toSet() ?? <String>{};
    } catch (_) {
      return <String>{};
    }
  }

  /// Sube de inmediato los mensajes pendientes (write-through tras enviar) y
  /// descarga del servidor el historial completo (los mensajes que el
  /// Realtime pudo perder mientras estuvo caído/cerrado).
  Future<void> sincronizarMensajesPendientes() async {
    if (_sincronizandoMensajes) {
      debugPrint('[Sync] sincronizarMensajesPendientes: omitido (ya en curso)');
      return;
    }
    _sincronizandoMensajes = true;
    try {
      await _subirMensajesPendientes();
      await _descargarMensajesRemotos();
    } finally {
      _sincronizandoMensajes = false;
    }
  }

  bool _sincronizandoMensajes = false;

  Future<void> _subirMensajesPendientes() async {
    final pendientes = await (_db.select(_db.mensajes)
          ..where((m) => m.pendienteDeSincronizar.equals(true))
          ..orderBy([(m) => OrderingTerm.asc(m.timestamp)]))
        .get();
    debugPrint('[Sync] _subirMensajesPendientes: ${pendientes.length} pendientes');

    for (final mensaje in pendientes) {
      try {
        debugPrint('[Sync] subiendo mensaje: uuid=${mensaje.uuid}');
        await _subirMensaje(mensaje);
        await (_db.update(_db.mensajes)
              ..where((m) => m.uuid.equals(mensaje.uuid)))
            .write(const MensajesCompanion(
          pendienteDeSincronizar: Value(false),
          estadoEnvio: Value('enviado'),
        ));
        EstadoServidorServicio.instancia.marcarExito();
      } catch (e, st) {
        debugPrint('[Sync] ERROR subiendo mensaje uuid=${mensaje.uuid}: $e\n$st');
        final intentos = mensaje.intentosDeSincronizacion + 1;
        await (_db.update(_db.mensajes)
              ..where((m) => m.uuid.equals(mensaje.uuid)))
            .write(MensajesCompanion(
          intentosDeSincronizacion: Value(intentos),
          estadoEnvio: Value(intentos >= 5 ? 'fallido' : mensaje.estadoEnvio),
        ));
        if (ConnectivityService.instancia.hayConexion) {
          EstadoServidorServicio.instancia.marcarFallo(e);
        }
      }
    }
  }

  /// Descarga del servidor el historial completo de mensajes (fuente de
  /// verdad). Si el Realtime perdió eventos (suscripción caída, app cerrada,
  /// gap al recrear los streams...), aquí se recuperan. Los mensajes locales
  /// que aún no se han subido no se sobrescriben (gana el local pendiente).
  Future<void> _descargarMensajesRemotos() async {
    if (kUsarServidorLocal) return;
    final userId = _obtenerUserId();
    if (userId == null) return;
    try {
      final remoto = await sb.Supabase.instance.client
          .from('messages')
          .select()
          .or('emisor_id.eq.$userId,receptor_id.eq.$userId')
          .timeout(const Duration(seconds: 10));
      final filas =
          (remoto as List).map((f) => f as Map<String, dynamic>).toList();
      final pendientesLocales = (await (_db.select(_db.mensajes)
            ..where((m) => m.pendienteDeSincronizar.equals(true)))
          .get())
          .map((m) => m.uuid)
          .toSet();
      // Para no re-notificar: lo que ya estaba en local (Realtime lo avisó
      // en su momento) no vuelve a sonar al bajar por sync.
      final existentesLocales = (await (_db.select(_db.mensajes)
            ..where((m) => m.emisorId.equals(userId) | m.receptorId.equals(userId)))
          .get())
          .map((m) => m.uuid)
          .toSet();
      final borrados = await _leerMensajesBorrados();

      final companiones = <MensajesCompanion>[];
      // Entrantes genuinamente nuevos (para el popup por remitente).
      final nuevosEntrantes = <MapEntry<String, DateTime>>[];
      // Cortes de borrado: el historial anterior al borrado de una
      // conversación no se vuelve a descargar del servidor, aunque la
      // conversación esté reactivada (solo renace con los mensajes nuevos).
      final borradas = await _db.select(_db.conversacionesEliminadas).get();
      final cortes = {
        for (final b in borradas) b.otroUsuarioId: b.eliminadoEn
      };
      for (final f in filas) {
        final id = f['id'] as String?;
        if (id == null ||
            pendientesLocales.contains(id) ||
            borrados.contains(id)) {
          continue;
        }
        final emisor = f['emisor_id'] as String? ?? '';
        final timestamp =
            PerfilMapeo.parsearFecha(f['timestamp']) ?? DateTime.now();
        final otroId = emisor == userId
            ? (f['receptor_id'] as String? ?? '')
            : emisor;
        final corte = cortes[otroId];
        // Estricto sin tolerancia: el historial anterior al borrado nunca se
        // vuelve a descargar. La tolerancia de reloj solo se aplica al
        // mostrarlo (un mensaje nuevo con skew no se oculta de la vista).
        if (corte != null && !timestamp.isAfter(corte)) {
          continue;
        }
        companiones.add(MensajesCompanion.insert(
          uuid: id,
          emisorId: emisor,
          receptorId: f['receptor_id'] as String? ?? '',
          contenido: f['contenido'] as String? ?? '',
          timestamp: timestamp,
          pendienteDeSincronizar: const Value(false),
          estadoEnvio: Value(emisor == userId ? 'enviado' : 'entregado'),
        ));
        final receptor = f['receptor_id'] as String? ?? '';
        if (receptor == userId &&
            emisor != userId &&
            !existentesLocales.contains(id)) {
          nuevosEntrantes.add(MapEntry(emisor, timestamp));
        }
      }
      if (companiones.isNotEmpty) {
        await _db.batch(
            (batch) => batch.insertAllOnConflictUpdate(_db.mensajes, companiones));
        // Los mensajes que llegaron por sync (no por Realtime) también
        // reactivan la conversación si el usuario la había borrado: si hay
        // un mensaje más nuevo que el borrado, se quita el tombstone.
        await _limpiarTombstonesObsoletos();
      }
      // Purga física del historial anterior a los cortes de borrado (filas
      // que quedaron de builds anteriores o reinsertadas por Realtime antes
      // del corte): sin ella, al reactivar la conversación reaparecerían los
      // mensajes que el usuario borró. Se excluyen los pendientes (aún no
      // subidos) y se aplica la tolerancia de reloj.
      for (final entry in cortes.entries) {
        await (_db.delete(_db.mensajes)
              ..where((m) =>
                  (((m.emisorId.equals(userId) &
                              m.receptorId.equals(entry.key)) |
                          (m.emisorId.equals(entry.key) &
                              m.receptorId.equals(userId))) &
                      m.timestamp.isBiggerThanValue(entry.value
                          .subtract(_toleranciaBorrado))
                          .not()) &
                      m.pendienteDeSincronizar.equals(false)))
              .go();
      }
      final idsRemotos = filas.map((f) => f['id'] as String).toSet();
      final locales = await (_db.select(_db.mensajes)
            ..where((m) => m.pendienteDeSincronizar.equals(false) &
                (m.emisorId.equals(userId) | m.receptorId.equals(userId))))
          .get();
      final aBorrar = locales
          .where((m) => !idsRemotos.contains(m.uuid))
          .map((m) => m.uuid)
          .toList();
      if (aBorrar.isNotEmpty) {
        await (_db.delete(_db.mensajes)
              ..where((m) => m.uuid.isIn(aBorrar)))
            .go();
      }
      // Popup por remitente de lo recuperado offline → online. La campana NO
      // se toca (mensajes van al badge de Chats, que se actualiza por watch).
      await _notificarMensajesDescargados(userId, nuevosEntrantes);
    } catch (_) {}
  }

  /// Avisos locales por mensajes recuperados del sync (offline → online):
  /// un popup por remitente ("Tienes un nuevo mensaje de X"). Con los mismos
  /// guards que el Realtime (bloqueo, ya-leído, prefs, borrado ya filtrado).
  Future<void> _notificarMensajesDescargados(
      String userId, List<MapEntry<String, DateTime>> nuevos) async {
    if (nuevos.isEmpty) return;
    final porEmisor = <String, DateTime>{};
    for (final e in nuevos) {
      final prev = porEmisor[e.key];
      if (prev == null || e.value.isAfter(prev)) porEmisor[e.key] = e.value;
    }
    final prefs = PreferenciasNotificacionesServicio.instancia;
    await prefs.asegurarCargada();
    if (!prefs.mensajes) return;
    for (final entry in porEmisor.entries) {
      final emisor = entry.key;
      try {
        final bloqueado = await (_db.select(_db.bloqueos)
              ..where((b) =>
                  b.bloqueadorId.equals(userId) & b.bloqueadoId.equals(emisor))
              ..limit(1))
            .getSingleOrNull();
        if (bloqueado != null) continue;
        if (await _mensajeDescargadoYaLeido(userId, emisor, entry.value)) {
          continue;
        }
        final u = await (_db.select(_db.usuarios)
              ..where((u) => u.uuid.equals(emisor))
              ..limit(1))
            .getSingleOrNull();
        final nombre = cuentasOficialesFlumi[emisor] ?? u?.nombre ?? 'Alguien';
        final fotos = u?.fotosUrls ?? const <String>[];
        await notificarNavegador('Flumi', 'Tienes un nuevo mensaje de $nombre',
            fotoUrl: fotos.isNotEmpty ? fotos.first : null,
            categoria: 'mensajes');
      } catch (_) {}
    }
  }

  /// True si el mensaje ya estaba leído (corte de lectura posterior): no es
  /// novedad aunque venga del sync.
  Future<bool> _mensajeDescargadoYaLeido(
      String userId, String emisor, DateTime timestamp) async {
    final match = await (_db.select(_db.matches)
          ..where((m) =>
              (m.usuarioAId.equals(userId) & m.usuarioBId.equals(emisor)) |
              (m.usuarioAId.equals(emisor) & m.usuarioBId.equals(userId)))
          ..limit(1))
        .getSingleOrNull();
    final leidoMatch = match?.leidoHasta;
    if (leidoMatch != null && !timestamp.isAfter(leidoMatch)) return true;
    final like = await (_db.select(_db.historialLikes)
          ..where((h) =>
              h.usuarioId.equals(emisor) & h.usuarioLikeadoId.equals(userId))
          ..limit(1))
        .getSingleOrNull();
    final leidoLike = like?.leidoHasta;
    if (leidoLike != null && !timestamp.isAfter(leidoLike)) return true;
    final conv = await (_db.select(_db.conversacionesLeidas)
          ..where((c) => c.otroUsuarioId.equals(emisor))
          ..limit(1))
        .getSingleOrNull();
    return conv != null && !timestamp.isAfter(conv.leidoHasta);
  }

  // ------------------------------------------------------------
  // Matches
  // ------------------------------------------------------------
  // Matches
  // ------------------------------------------------------------
  Future<void> sincronizarMatchesPendientes() async {
    final pendientes = await (_db.select(_db.matches)
          ..where((m) => m.pendienteDeSincronizar.equals(true)))
        .get();

    for (final match in pendientes) {
      try {
        await _subirMatch(match);
        await (_db.update(_db.matches)
              ..where((m) => m.uuid.equals(match.uuid)))
            .write(const MatchesCompanion(pendienteDeSincronizar: Value(false)));
      } catch (_) {}
    }

    final userIdResuelto = _obtenerUserId();
    if (userIdResuelto == null || kUsarServidorLocal) return;
    try {
      // Descargar los matches del usuario y purgar los huérfanos locales
      // (p. ej. tras limpiar el remoto con tool/limpiar_remoto.sql).
      final remoto = await sb.Supabase.instance.client
          .from('matches')
          .select()
          .or('usuario_a_id.eq.$userIdResuelto,usuario_b_id.eq.$userIdResuelto');
      // Marcadores por participante (leido_hasta_a/b): cada uno solo escribe
      // el suyo (el trigger no_pisar_leido_ajeno lo garantiza en remoto).
      // - leidoHasta (local) = MI marcador → badge de no leídos. Solo se
      //   fusiona con mi propia columna remota: el marcador del otro YA NO
      //   puede borrar mis no leídos (antes, con una sola columna compartida
      //   + máximo, cuando el otro leía se me apagaba el badge).
      // - leidoHastaOtro (local) = SU marcador → ticks ✓✓ de mis enviados.
      final leidosLocales = {
        for (final m
            in await (_db.select(_db.matches)).get())
          m.uuid: m
      };
      final filas = (remoto as List).map((fila) {
        final f = fila as Map<String, dynamic>;
        final soyA = f['usuario_a_id'] == userIdResuelto;
        final miRemoto = PerfilMapeo.parsearFecha(
                soyA ? f['leido_hasta_a'] : f['leido_hasta_b']) ??
            PerfilMapeo.parsearFecha(f['leido_hasta']);
        final suRemoto = PerfilMapeo.parsearFecha(
                soyA ? f['leido_hasta_b'] : f['leido_hasta_a']) ??
            PerfilMapeo.parsearFecha(f['leido_hasta']);
        final local = leidosLocales[f['id']];
        return MatchesCompanion.insert(
          uuid: f['id'] as String,
          usuarioAId: f['usuario_a_id'] as String,
          usuarioBId: f['usuario_b_id'] as String,
          timestampMatch:
              PerfilMapeo.parsearFecha(f['timestamp_match']) ?? DateTime.now(),
          ultimoMensajePreview: const Value.absent(),
          ultimoMensajeTimestamp: const Value.absent(),
          leidoHasta:
              Value(leidoHastaMasReciente(local?.leidoHasta, miRemoto)),
          leidoHastaOtro:
              Value(leidoHastaMasReciente(local?.leidoHastaOtro, suRemoto)),
        );
      }).toList();
      if (filas.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAllOnConflictUpdate(_db.matches, filas);
        });
      }
      await _purgarMatchesHuerfanos(filas.map((f) => f.uuid.value).toSet());
    } catch (_) {}
  }

  /// Borra de la BD local los matches ya sincronizados que el remoto ya no
  /// tiene (p. ej. tras limpiar con `tool/limpiar_remoto.sql`).
  Future<void> _purgarMatchesHuerfanos(Set<String> idsRemotos) async {
    final locales = await (_db.select(_db.matches)
          ..where((m) => m.pendienteDeSincronizar.equals(false)))
        .get();
    final aBorrar = locales
        .where((m) => !idsRemotos.contains(m.uuid))
        .map((m) => m.uuid)
        .toList();
    if (aBorrar.isNotEmpty) {
      await (_db.delete(_db.matches)..where((m) => m.uuid.isIn(aBorrar))).go();
    }
  }

  // ------------------------------------------------------------
  // Reportes
  // ------------------------------------------------------------
  Future<void> sincronizarReportesPendientes() async {
    final pendientes = await (_db.select(_db.reportes)
          ..where((r) => r.pendienteDeSincronizar.equals(true)))
        .get();

    for (final reporte in pendientes) {
      try {
        await _subirReporte(reporte);
        await (_db.update(_db.reportes)
              ..where((r) => r.uuid.equals(reporte.uuid)))
            .write(const ReportesCompanion(pendienteDeSincronizar: Value(false)));
      } catch (_) {}
    }
  }

  // ------------------------------------------------------------
  // Bloqueos
  // ------------------------------------------------------------
  Future<void> sincronizarBloqueosPendientes() async {
    final pendientes = await (_db.select(_db.bloqueos)
          ..where((b) => b.pendienteDeSincronizar.equals(true)))
        .get();

    for (final bloqueo in pendientes) {
      try {
        await _subirBloqueo(bloqueo);
        await (_db.update(_db.bloqueos)
              ..where((b) => b.uuid.equals(bloqueo.uuid)))
            .write(const BloqueosCompanion(pendienteDeSincronizar: Value(false)));
      } catch (_) {}
    }
  }

  // ------------------------------------------------------------
  // Suscripciones (plan del usuario)
  // ------------------------------------------------------------
  Future<void> sincronizarSuscripciones([String? userId]) async {
    final userIdFinal = userId ?? _obtenerUserId();
    if (userIdFinal == null) return;

    try {
      final local = await (_db.select(_db.suscripciones)
            ..where((s) => s.usuarioId.equals(userIdFinal)))
          .getSingleOrNull();

      if (kUsarServidorLocal) {
        if (local != null) {
          final token = await LocalTokenStore.obtenerToken();
          if (token == null) return;
          await http.put(
            Uri.parse('$kServidorLocalUrl/api/subscription'),
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer $token'
            },
            body: jsonEncode(_suscripcionARemoto(local)),
          );
        }
        return;
      }

      // El servidor es la fuente de verdad (RLS SELECT-only para el usuario;
      // toda escritura pasa por RPCs). Nunca se sube lo local: un espejo
      // rancio revertiría cancelaciones y aprobaciones del servidor.
      final remoto = await sb.Supabase.instance.client
          .from('suscripciones')
          .select()
          .eq('usuario_id', userIdFinal)
          .maybeSingle();
      if (remoto != null) {
        await _db.into(_db.suscripciones).insertOnConflictUpdate(
              _suscripcionDesdeRemoto(remoto),
            );
      } else if (local != null) {
        // Sin fila remota (cuenta nueva o limpieza): no hay suscripción.
        await (_db.delete(_db.suscripciones)
              ..where((s) => s.usuarioId.equals(userIdFinal)))
            .go();
      }
    } catch (_) {}
  }

  // ------------------------------------------------------------
  // Usos diarios (lÃ­mites por plan)
  // ------------------------------------------------------------
  Future<void> sincronizarUsosDiarios([String? userId]) async {
    final userIdResuelto = userId ?? _obtenerUserId();
    if (userIdResuelto == null) return;

    final hoy = DateTime.now();
    final inicioDia = DateTime(hoy.year, hoy.month, hoy.day);

    try {
      final local = await (_db.select(_db.usosDiarios)
            ..where((u) =>
                u.usuarioId.equals(userIdResuelto) & u.fecha.equals(inicioDia)))
          .getSingleOrNull();

      if (kUsarServidorLocal) {
        if (local != null) {
          final token = await LocalTokenStore.obtenerToken();
          if (token == null) return;
          await http.put(
            Uri.parse('$kServidorLocalUrl/api/usages'),
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer $token'
            },
            body: jsonEncode(_usosDiariosARemoto(local)),
          );
        }
        return;
      }

      // El servidor es la fuente de verdad del cupo diario (lo valida el RPC
      // registrar_me_gusta). El contador local es solo un espejo: nunca se
      // sube (un espejo rancio re-infectaría el remoto tras una limpieza).
      final remoto = await sb.Supabase.instance.client
          .from('usos_diarios')
          .select()
          .eq('usuario_id', userIdResuelto)
          .eq('fecha', inicioDia.toIso8601String().substring(0, 10))
          .maybeSingle();
      if (remoto != null) {
        await _db.into(_db.usosDiarios).insertOnConflictUpdate(
              _usosDiariosDesdeRemoto(remoto),
            );
      } else if (local != null) {
        // Sin registro remoto hoy (p. ej. tras limpiar el remoto de
        // pruebas): el espejo local no debe bloquear por usos fantasma.
        await _db.into(_db.usosDiarios).insertOnConflictUpdate(
              UsosDiariosCompanion(
                usuarioId: Value(userIdResuelto),
                fecha: Value(inicioDia),
                meGustasUsados: const Value(0),
                deshacerUsados: const Value(0),
                superlikesUsados: const Value(0),
                boostsUsados: const Value(0),
                vistasCercaUsadas: const Value(0),
              ),
            );
      }
    } catch (_) {}
  }

  // ------------------------------------------------------------
  // Visitas (quiÃ©n visitÃ³ a quiÃ©n)
  // ------------------------------------------------------------
  Future<void> sincronizarVisitas([String? userId]) async {
    final userIdResuelto = userId ?? _obtenerUserId();
    if (userIdResuelto == null) return;

    try {
      final pendientes = await (_db.select(_db.visitas)
            ..where((v) => v.pendienteDeSincronizar.equals(true)))
          .get();

      for (final visita in pendientes) {
        try {
          await _subirVisita(visita);
          await (_db.update(_db.visitas)
                ..where((v) => v.uuid.equals(visita.uuid)))
              .write(const VisitasCompanion(
                  pendienteDeSincronizar: Value(false)));
        } catch (_) {}
      }

      if (kUsarServidorLocal) {
        final token = await LocalTokenStore.obtenerToken();
        if (token == null) return;
        final res = await http.get(
          Uri.parse('$kServidorLocalUrl/api/visits?recibidas=1'),
          headers: {'authorization': 'Bearer $token'},
        );
        if (res.statusCode != 200) return;
        final lista = jsonDecode(res.body) as List;
        final filas = lista.map((fila) {
          final f = fila as Map<String, dynamic>;
          return VisitasCompanion.insert(
            uuid: f['id'] as String,
            visitanteId: f['visitante_id'] as String,
            visitadoId: f['visitado_id'] as String,
            timestamp: Value(PerfilMapeo.parsearFecha(f['timestamp']) ?? DateTime.now()),
            pendienteDeSincronizar: const Value(false),
          );
        }).toList();
        if (filas.isNotEmpty) {
          await _db.batch((batch) {
            batch.insertAllOnConflictUpdate(_db.visitas, filas);
          });
        }
        return;
      }

      // Descargar las visitas recibidas y propias para "quien te vio"
      final remoto = await sb.Supabase.instance.client
          .from('visitas')
          .select()
          .or('visitante_id.eq.$userIdResuelto,visitado_id.eq.$userIdResuelto');
      final filas = (remoto as List).map((fila) {
        final f = fila as Map<String, dynamic>;
        return VisitasCompanion.insert(
          uuid: f['id'] as String,
          visitanteId: f['visitante_id'] as String,
          visitadoId: f['visitado_id'] as String,
          timestamp: Value(PerfilMapeo.parsearFecha(f['timestamp']) ?? DateTime.now()),
          pendienteDeSincronizar: const Value(false),
        );
      }).toList();
      if (filas.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAllOnConflictUpdate(_db.visitas, filas);
        });
      }
      await _purgarVisitasHuerfanas(filas.map((f) => f.uuid.value).toSet());
      EstadoServidorServicio.instancia.marcarExito();
    } catch (e) {
      EstadoServidorServicio.instancia.marcarFallo(e);
    }
  }

  /// Borra de la BD local las visitas ya sincronizadas que el remoto ya no
  /// tiene (p. ej. tras limpiar con `tool/limpiar_remoto.sql`).
  Future<void> _purgarVisitasHuerfanas(Set<String> idsRemotos) async {
    final locales = await (_db.select(_db.visitas)
          ..where((v) => v.pendienteDeSincronizar.equals(false)))
        .get();
    final aBorrar = locales
        .where((v) => !idsRemotos.contains(v.uuid))
        .map((v) => v.uuid)
        .toList();
    if (aBorrar.isNotEmpty) {
      await (_db.delete(_db.visitas)..where((v) => v.uuid.isIn(aBorrar))).go();
    }
  }

  // ------------------------------------------------------------
  // Historial de likes
  // ------------------------------------------------------------

  /// Fusiona el corte de lectura local con el remoto: `leido_hasta` solo
  /// avanza (nunca retrocede), así el "leído" nunca se pierde al re-descargar
  /// filas que el remoto tiene más viejas o vacías (p. ej. la dirección de
  /// like-only que RLS impide escribir en remoto).
  static DateTime? leidoHastaMasReciente(DateTime? local, DateTime? remoto) {
    if (local == null) return remoto;
    if (remoto == null || local.isAfter(remoto)) return local;
    return remoto;
  }

  // ------------------------------------------------------------
  // Likes deshechos por Nope (tombstones)
  // ------------------------------------------------------------
  /// Pares "usuarioId|likeadoId" de Me Gustas que el usuario deshizo con un
  /// Nope: la descarga los salta para que un unlike offline no resucite al
  /// sincronizar, y el borrado remoto se reintenta en cada sync. Al volver
  /// a dar Me Gusta se olvida el tombstone (ver registrarLike).
  static const _prefsLikesBorrados = 'flumi_likes_borrados';
  static const _maxLikesBorrados = 500;

  static Future<void> recordarLikeBorrado(
      String usuarioId, String likeadoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clave = '$usuarioId|$likeadoId';
      final lista = prefs.getStringList(_prefsLikesBorrados) ?? <String>[];
      lista.remove(clave);
      lista.add(clave);
      while (lista.length > _maxLikesBorrados) {
        lista.removeAt(0);
      }
      await prefs.setStringList(_prefsLikesBorrados, lista);
    } catch (_) {}
  }

  static Future<Set<String>> _leerLikesBorrados() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_prefsLikesBorrados)?.toSet() ?? <String>{};
    } catch (_) {
      return <String>{};
    }
  }

  static Future<void> olvidarLikeBorrado(
      String usuarioId, String likeadoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lista = prefs.getStringList(_prefsLikesBorrados) ?? <String>[];
      lista.remove('$usuarioId|$likeadoId');
      await prefs.setStringList(_prefsLikesBorrados, lista);
    } catch (_) {}
  }

  Future<void> sincronizarHistorialLikes([String? userId]) async {
    final userIdResuelto = userId ?? _obtenerUserId();
    if (userIdResuelto == null) return;

    try {
      final pendientes = await (_db.select(_db.historialLikes)
            ..where((h) => h.pendienteDeSincronizar.equals(true)))
          .get();

      for (final like in pendientes) {
        try {
          await _subirHistorialLike(like);
          await (_db.update(_db.historialLikes)
                ..where((h) => h.uuid.equals(like.uuid)))
              .write(const HistorialLikesCompanion(
                  pendienteDeSincronizar: Value(false)));
        } catch (_) {}
      }

      // Reintenta borrados de likes pendientes (unlike offline) antes de
      // descargar, para no resucitarlos.
      for (final clave in (await _leerLikesBorrados()).toList()) {
        final partes = clave.split('|');
        if (partes.length != 2) continue;
        if (kUsarServidorLocal) continue;
        if (!ConnectivityService.instancia.hayConexion) break;
        try {
          await sb.Supabase.instance.client
              .from('historial_likes')
              .delete()
              .match(
                  {'usuario_id': partes[0], 'usuario_likeado_id': partes[1]})
              .timeout(const Duration(seconds: 6));
          await olvidarLikeBorrado(partes[0], partes[1]);
        } catch (_) {}
      }
      final likesBorrados = await _leerLikesBorrados();

      if (kUsarServidorLocal) {
        final token = await LocalTokenStore.obtenerToken();
        if (token == null) return;
        final res = await http.get(
          Uri.parse('$kServidorLocalUrl/api/likes'),
          headers: {'authorization': 'Bearer $token'},
        );
        if (res.statusCode != 200) return;
        final lista = jsonDecode(res.body) as List;
        final leidosLocales = {
          for (final l in await _db.select(_db.historialLikes).get())
            l.uuid: l.leidoHasta
        };
        final filas = lista.map((fila) {
          final f = fila as Map<String, dynamic>;
          // Igual que en la rama Supabase: el remoto de filas ajenas es el
          // marcador del otro y no se fusiona con mi estado local.
          final esPropia = f['usuario_id'] == userIdResuelto;
          return HistorialLikesCompanion.insert(
            uuid: f['id'] as String,
            usuarioId: f['usuario_id'] as String,
            usuarioLikeadoId: f['usuario_likeado_id'] as String,
            timestamp: Value(PerfilMapeo.parsearFecha(f['timestamp']) ?? DateTime.now()),
            pendienteDeSincronizar: const Value(false),
            leidoHasta: Value(esPropia
                ? leidoHastaMasReciente(leidosLocales[f['id']],
                    PerfilMapeo.parsearFecha(f['leido_hasta']))
                : leidosLocales[f['id']]),
            esSuper: Value((f['es_super'] as bool?) ?? false),
          );
        }).where((c) {
          // Salta Me Gustas deshechos por Nope (tombstone): solo filas
          // propias, las recibidas no se tocan.
          final esPropia = c.usuarioId.value == userIdResuelto;
          return !esPropia ||
              !likesBorrados
                  .contains('${c.usuarioId.value}|${c.usuarioLikeadoId.value}');
        }).toList();
        if (filas.isNotEmpty) {
          await _db.batch((batch) {
            batch.insertAllOnConflictUpdate(_db.historialLikes, filas);
          });
        }
        return;
      }

      final remoto = await sb.Supabase.instance.client
          .from('historial_likes')
          .select()
          .or(
              'usuario_id.eq.$userIdResuelto,usuario_likeado_id.eq.$userIdResuelto');
      final leidosLocales = {
        for (final l in await _db.select(_db.historialLikes).get())
          l.uuid: l.leidoHasta
      };
      final filas = (remoto as List).map((fila) {
        final f = fila as Map<String, dynamic>;
        // El leido_hasta remoto de una fila AJENA es el marcador del otro
        // (cada uno solo puede actualizar sus propias filas por RLS): NO se
        // fusiona, o sus lecturas borrarían mis no leídos. Solo las filas
        // propias mezclan remoto con local.
        final esPropia = f['usuario_id'] == userIdResuelto;
        return HistorialLikesCompanion.insert(
          uuid: f['id'] as String,
          usuarioId: f['usuario_id'] as String,
          usuarioLikeadoId: f['usuario_likeado_id'] as String,
          timestamp: Value(PerfilMapeo.parsearFecha(f['timestamp']) ?? DateTime.now()),
          pendienteDeSincronizar: const Value(false),
          leidoHasta: Value(esPropia
              ? leidoHastaMasReciente(leidosLocales[f['id']],
                  PerfilMapeo.parsearFecha(f['leido_hasta']))
              : leidosLocales[f['id']]),
          esSuper: Value((f['es_super'] as bool?) ?? false),
        );
      }).where((c) {
        final esPropia = c.usuarioId.value == userIdResuelto;
        return !esPropia ||
            !likesBorrados
                .contains('${c.usuarioId.value}|${c.usuarioLikeadoId.value}');
      }).toList();
      if (filas.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAllOnConflictUpdate(_db.historialLikes, filas);
        });
      }
      await _purgarLikesHuerfanos(filas.map((f) => f.uuid.value).toSet());
      EstadoServidorServicio.instancia.marcarExito();
    } catch (e) {
      EstadoServidorServicio.instancia.marcarFallo(e);
    }
  }

  /// Borra de la BD local los likes ya sincronizados que el remoto ya no
  /// tiene (p. ej. tras limpiar con `tool/limpiar_remoto.sql`).
  Future<void> _purgarLikesHuerfanos(Set<String> idsRemotos) async {
    final locales = await (_db.select(_db.historialLikes)
          ..where((h) => h.pendienteDeSincronizar.equals(false)))
        .get();
    final aBorrar = locales
        .where((h) => !idsRemotos.contains(h.uuid))
        .map((h) => h.uuid)
        .toList();
    if (aBorrar.isNotEmpty) {
      await (_db.delete(_db.historialLikes)
            ..where((h) => h.uuid.isIn(aBorrar)))
          .go();
    }
  }

  // ------------------------------------------------------------
  // Conversaciones borradas (tombstones remotos)
  // ------------------------------------------------------------
  /// Baja del servidor los marcadores de conversaciones borradas SOLO propias
  /// y recrea los tombstones locales (p. ej. tras reinstalar la app, donde
  /// la tabla local se perdió pero el servidor aún recuerda el borrado).
  /// Es aditivo a propósito: la verdad para la UI es el tombstone local.
  /// Los marcadores obsoletos (la conversación retomó actividad: hay un
  /// mensaje local más nuevo que el borrado) se ignoran y se limpian.
  Future<void> sincronizarConversacionesBorradas([String? userId]) async {
    if (kUsarServidorLocal) return;
    final userIdResuelto = userId ?? _obtenerUserId();
    if (userIdResuelto == null) return;
    try {
      // Un borrado deja de estar vigente en cuanto la conversación retoma
      // actividad: si ya existe un mensaje local más nuevo que el borrado,
      // el tombstone es basura y se elimina (local y remoto). Esto evita
      // que el siguiente sync vuelva a ocultar la conversación después de
      // que cualquiera de los dos vuelva a escribir.
      await _limpiarTombstonesObsoletos();

      final remoto = await sb.Supabase.instance.client
          .from(tablaConversacionesBorradas)
          .select()
          .eq('usuario_id', userIdResuelto);
      final filas = remoto as List;
      final companions = <ConversacionesEliminadasCompanion>[];
      for (final f in filas) {
        final m = f as Map<String, dynamic>;
        final otroUsuarioId = m['otro_usuario_id'] as String?;
        if (otroUsuarioId == null) continue;
        final borradoEn = PerfilMapeo.parsearFecha(m['borrado_en']);
        // Marcador viejo de una conversación que ya volvió a tener
        // actividad: no se vuelve a ocultar aunque el servidor aún lo tenga
        // (p. ej. porque la eliminación remota del marcador falló o quedó
        // una carrera con el sync).
        if (borradoEn != null &&
            await _conversacionTieneMensajeMasNuevo(
                otroUsuarioId, borradoEn)) {
          continue;
        }
        companions.add(ConversacionesEliminadasCompanion(
          otroUsuarioId: Value(otroUsuarioId),
        ));
      }
      if (companions.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAllOnConflictUpdate(
              _db.conversacionesEliminadas, companions);
        });
      }
      // Re-subir los tombstones locales vigentes (upsert idempotente): cubre
      // los borrados hechos sin conexión, cuyo marcador no llegó a subirse
      // en el momento. Si es un INSERT nuevo y el otro también borró, el
      // trigger del servidor limpia los mensajes del par. Las conversaciones
      // reactivadas ya no se suben (el marcador se elimina en la reactivación).
      // La limpieza se repite justo antes de subir: cierra la carrera en la
      // que una reactivación (realtime o sync concurrente) acaba de marcar el
      // tombstone y la subida lo resucitaría en el servidor.
      await _limpiarTombstonesObsoletos();
      final locales = await _db.select(_db.conversacionesEliminadas).get();
      final vigentes = locales.where((t) => !t.reactivada).toList();
      if (vigentes.isNotEmpty) {
        await sb.Supabase.instance.client
            .from(tablaConversacionesBorradas)
            .upsert(vigentes
                .map((t) => {
                      'usuario_id': userIdResuelto,
                      'otro_usuario_id': t.otroUsuarioId,
                      'borrado_en': t.eliminadoEn.toUtc().toIso8601String(),
                    })
                .toList());
      }
    } catch (_) {}
  }

  /// Sincroniza los marcadores de lectura de conversaciones (oficiales,
  /// like-only, sin match): descarga leido_hasta remoto y fusiona con local
  /// tomando el máximo (el leído más reciente gana). Sube los locales pendientes
  /// (write-through ya los intenta, pero esto cubre fallos de red).
  Future<void> sincronizarConversacionesLeidas([String? userId]) async {
    if (kUsarServidorLocal) return;
    final userIdResuelto = userId ?? _obtenerUserId();
    if (userIdResuelto == null) return;
    try {
      final remoto = await sb.Supabase.instance.client
          .from('conversaciones_leidas')
          .select()
          .eq('usuario_id', userIdResuelto);
      final leidosLocales = {
        for (final l in await _db.select(_db.conversacionesLeidas).get())
          l.otroUsuarioId: l.leidoHasta
      };
      final filas = (remoto as List).map((fila) {
        final f = fila as Map<String, dynamic>;
        final otroId = f['otro_usuario_id'] as String?;
        if (otroId == null) return null;
        final remotoTs = PerfilMapeo.parsearFecha(f['leido_hasta']);
        final localTs = leidosLocales[otroId];
        final merged = leidoHastaMasReciente(localTs, remotoTs);
        return merged != null
            ? ConversacionesLeidasCompanion(
                otroUsuarioId: Value(otroId),
                leidoHasta: Value(merged),
              )
            : null;
      }).whereType<ConversacionesLeidasCompanion>().toList();
      if (filas.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAllOnConflictUpdate(_db.conversacionesLeidas, filas);
        });
      }
    } catch (_) {}
  }

  /// ¿Existe un mensaje local entre yo y [otroUsuarioId] más nuevo que
  /// [momento]? Si sí, el borrado de esa conversación ya no está vigente.
  /// Con tolerancia de reloj hacia lo "reciente": un mensaje nuevo cuyo
  /// timestamp quedó unos segundos detrás del corte por skew entre
  /// dispositivos sí reactiva la conversación (sesgo: mostrar la
  /// conversación antes que ocultarla).
  Future<bool> _conversacionTieneMensajeMasNuevo(
      String otroUsuarioId, DateTime momento) async {
    final yo = _obtenerUserId();
    if (yo == null) return false;
    final filas = await (_db.select(_db.mensajes)
          ..where((m) =>
              ((m.emisorId.equals(yo) &
                          m.receptorId.equals(otroUsuarioId)) |
                      (m.emisorId.equals(otroUsuarioId) &
                          m.receptorId.equals(yo))) &
                  m.timestamp
                      .isBiggerThanValue(momento.subtract(_toleranciaBorrado)))
          ..limit(1))
        .get();
    return filas.isNotEmpty;
  }

  /// Marca como reactivados los tombstones obsoletos (conversación retomada:
  /// hay un mensaje local más nuevo que el borrado) y borra su marcador remoto
  /// propio. La fila se conserva como corte: el historial anterior al borrado
  /// no vuelve a descargarse ni a mostrarse. Tampoco se vuelve a ocultar la
  /// conversación, y el marcador no puede disparar el trigger de limpieza si
  /// el otro usuario borra la conversación de nuevo.
  Future<void> _limpiarTombstonesObsoletos() async {
    final tombstones = await _db.select(_db.conversacionesEliminadas).get();
    for (final t in tombstones) {
      if (t.reactivada) continue;
      if (!await _conversacionTieneMensajeMasNuevo(
          t.otroUsuarioId, t.eliminadoEn)) {
        continue;
      }
      await (_db.update(_db.conversacionesEliminadas)
            ..where((x) => x.otroUsuarioId.equals(t.otroUsuarioId)))
          .write(const ConversacionesEliminadasCompanion(
        reactivada: Value(true),
      ));
      if (kUsarServidorLocal || !ConnectivityService.instancia.hayConexion) {
        continue;
      }
      final yo = _obtenerUserId();
      if (yo == null) continue;
      try {
        await sb.Supabase.instance.client
            .from(tablaConversacionesBorradas)
            .delete()
            .eq('usuario_id', yo)
            .eq('otro_usuario_id', t.otroUsuarioId)
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
  }

  // ------------------------------------------------------------
  // Rechazos (Nope)
  // ------------------------------------------------------------
  Future<void> sincronizarRechazos([String? userId]) async {
    final userIdResuelto = userId ?? _obtenerUserId();
    if (userIdResuelto == null) return;

    try {
      final pendientes = await (_db.select(_db.rechazos)
            ..where((r) => r.pendienteDeSincronizar.equals(true)))
          .get();

      for (final rechazo in pendientes) {
        try {
          await _subirRechazo(rechazo);
          await (_db.update(_db.rechazos)
                ..where((r) => r.uuid.equals(rechazo.uuid)))
              .write(const RechazosCompanion(
                  pendienteDeSincronizar: Value(false)));
        } catch (_) {}
      }

      if (kUsarServidorLocal) return;

      // Reintenta deshacer pendientes antes de descargar, para no resucitarlos.
      await _reintentarDeshacerRechazos();
      final deshechos = await _leerDeshacerRechazos();
      final deshechosIds = deshechos
          .map((c) => c.split('|'))
          .where((p) => p.length == 2 && p[0] == userIdResuelto)
          .map((p) => p[1])
          .toSet();

      final remoto = await sb.Supabase.instance.client
          .from('rechazos')
          .select()
          .eq('usuario_id', userIdResuelto);
      final filas = (remoto as List).map((fila) {
        final f = fila as Map<String, dynamic>;
        return RechazosCompanion.insert(
          uuid: f['id'] as String,
          usuarioId: f['usuario_id'] as String,
          rechazadoId: f['rechazado_id'] as String,
          timestamp: Value(PerfilMapeo.parsearFecha(f['timestamp']) ?? DateTime.now()),
          pendienteDeSincronizar: const Value(false),
        );
      }).where((c) => !deshechosIds.contains(c.rechazadoId.value)).toList();
      if (filas.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAllOnConflictUpdate(_db.rechazos, filas);
        });
      }
      // Fallback: si el trigger del servidor (trg_romper_match_por_rechazo)
      // no borró el match remoto (p. ej. upsert hizo UPDATE en vez de INSERT),
      // al sincronizar los rejections aquí borramos los matches locales
      // correspondientes. userIdResuelto = yo; rechazadoId = el otro.
      final rechazadosIds = filas.map((f) => f.rechazadoId.value).toSet();
      if (rechazadosIds.isNotEmpty) {
        await (_db.delete(_db.matches)
              ..where((m) =>
                  (m.usuarioAId.equals(userIdResuelto) &
                      m.usuarioBId.isIn(rechazadosIds)) |
                  (m.usuarioAId.isIn(rechazadosIds) &
                      m.usuarioBId.equals(userIdResuelto))))
            .go();
      }
      await _purgarRechazosHuerfanos(filas.map((f) => f.uuid.value).toSet());
      EstadoServidorServicio.instancia.marcarExito();
    } catch (e) {
      EstadoServidorServicio.instancia.marcarFallo(e);
    }
  }

  /// Borra de la BD local los rechazos ya sincronizados que el remoto ya no
  /// tiene (p. ej. tras limpiar con `tool/limpiar_remoto.sql`).
  Future<void> _purgarRechazosHuerfanos(Set<String> idsRemotos) async {
    final locales = await (_db.select(_db.rechazos)
          ..where((r) => r.pendienteDeSincronizar.equals(false)))
        .get();
    final aBorrar = locales
        .where((r) => !idsRemotos.contains(r.uuid))
        .map((r) => r.uuid)
        .toList();
    if (aBorrar.isNotEmpty) {
      await (_db.delete(_db.rechazos)..where((r) => r.uuid.isIn(aBorrar))).go();
    }
  }

  /// Tombstones de deshacer (persisten en prefs): si el borrado remoto falla
  /// (offline o error), se reintenta en cada sincronizarRechazos y la descarga
  /// no resucita esas filas en local hasta que el servidor las borra.
  static const _prefsDeshacerRechazos = 'flumi_rechazos_deshacer';

  static Future<Set<String>> _leerDeshacerRechazos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_prefsDeshacerRechazos)?.toSet() ?? <String>{};
    } catch (_) {
      return <String>{};
    }
  }

  static Future<void> _recordarDeshacerRechazo(String usuarioId, String rechazadoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lista = prefs.getStringList(_prefsDeshacerRechazos) ?? <String>[];
      final clave = '$usuarioId|$rechazadoId';
      if (!lista.contains(clave)) {
        lista.add(clave);
        if (lista.length > 200) lista.removeAt(0);
        await prefs.setStringList(_prefsDeshacerRechazos, lista);
      }
    } catch (_) {}
  }

  static Future<void> _olvidarDeshacerRechazo(String usuarioId, String rechazadoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lista = prefs.getStringList(_prefsDeshacerRechazos) ?? <String>[];
      lista.remove('$usuarioId|$rechazadoId');
      await prefs.setStringList(_prefsDeshacerRechazos, lista);
    } catch (_) {}
  }

  Future<void> _reintentarDeshacerRechazos() async {
    final pendientes = await _leerDeshacerRechazos();
    for (final clave in pendientes) {
      final partes = clave.split('|');
      if (partes.length != 2) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final lista = prefs.getStringList(_prefsDeshacerRechazos) ?? <String>[];
          lista.remove(clave);
          await prefs.setStringList(_prefsDeshacerRechazos, lista);
        } catch (_) {}
        continue;
      }
      try {
        await sb.Supabase.instance.client
            .from('rechazos')
            .delete()
            .match({'usuario_id': partes[0], 'rechazado_id': partes[1]});
        await _olvidarDeshacerRechazo(partes[0], partes[1]);
      } catch (_) {}
    }
  }

  /// Borra el rechazo remoto (Deshacer). Si falla u offline, guarda tombstone
  /// y lo reintenta en el siguiente sync (antes la falla divergía para siempre).
  Future<void> borrarRechazoRemoto(String usuarioId, String rechazadoId) async {
    if (kUsarServidorLocal) return;
    if (!ConnectivityService.instancia.hayConexion) {
      await _recordarDeshacerRechazo(usuarioId, rechazadoId);
      return;
    }
    try {
      await sb.Supabase.instance.client
          .from('rechazos')
          .delete()
          .match({'usuario_id': usuarioId, 'rechazado_id': rechazadoId});
      await _olvidarDeshacerRechazo(usuarioId, rechazadoId);
    } catch (_) {
      await _recordarDeshacerRechazo(usuarioId, rechazadoId);
    }
  }

  // ------------------------------------------------------------
  // Helpers de red
  // ------------------------------------------------------------
  String? _obtenerUserId() {
    if (kUsarServidorLocal) {
      return 'local-dev';
    }
    return sb.Supabase.instance.client.auth.currentUser?.id;
  }

  Future<Map<String, dynamic>?> _fetchPerfil(String userId) async {
    if (kUsarServidorLocal) {
      final token = await LocalTokenStore.obtenerToken();
      if (token == null) return null;
      final res = await http.get(
        Uri.parse('$kServidorLocalUrl/api/profiles/$userId'),
        headers: {'authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return null;
    }

    final remoto = await sb.Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return remoto;
  }

  // Perfil local de respaldo a partir del usuario autenticado, por si la
  // descarga remota falla o el perfil remoto aÃºn no existe.
  Map<String, dynamic> _perfilDesdeAuth(String userId) {
    final authUser = sb.Supabase.instance.client.auth.currentUser;
    final nombre = (authUser?.userMetadata?['nombre'] as String?) ??
        (authUser?.email?.split('@').first ?? '');
    return {
      'id': userId,
      'nombre': nombre,
      'email': authUser?.email,
    };
  }

  // Indica si el perfil remoto trae datos de perfil (no estÃ¡ vacÃ­o).
  bool _remotoTieneDatos(Map<String, dynamic> r) {
    String s(dynamic v) => (v ?? '').toString();
    bool listaLlena(dynamic v) => v is List && v.isNotEmpty;
    return s(r['biografia']).isNotEmpty ||
        s(r['ciudad']).isNotEmpty ||
        s(r['altura']).isNotEmpty ||
        s(r['trabajo']).isNotEmpty ||
        s(r['genero']).isNotEmpty && s(r['genero']) != 'otro' ||
        listaLlena(r['intereses']) ||
        listaLlena(r['fotos_urls']) ||
        r['perfil_completado'] == true;
  }

  Map<String, dynamic> _suscripcionARemoto(Suscripcione s) => {
        'usuario_id': s.usuarioId,
        'plan': s.plan,
        'inicio': s.inicio.toIso8601String(),
        'vence': s.vence?.toIso8601String(),
        'activa': s.activa,
        'plan_reserva': s.planReserva,
        'vence_reserva': s.venceReserva?.toIso8601String(),
        'inicio_reserva': s.inicioReserva?.toIso8601String(),
      };

  SuscripcionesCompanion _suscripcionDesdeRemoto(Map<String, dynamic> r) =>
      SuscripcionesCompanion.insert(
        usuarioId: r['usuario_id'] as String,
        plan: Value((r['plan'] as String?) ?? 'gratis'),
        inicio: Value(PerfilMapeo.parsearFecha(r['inicio']) ?? DateTime.now()),
        vence: Value(PerfilMapeo.parsearFecha(r['vence'])),
        activa: Value(PerfilMapeo.aBool(r['activa'], true)),
        planReserva: Value(r['plan_reserva'] as String?),
        venceReserva: Value(PerfilMapeo.parsearFecha(r['vence_reserva'])),
        inicioReserva: Value(PerfilMapeo.parsearFecha(r['inicio_reserva'])),
      );

  Map<String, dynamic> _usosDiariosARemoto(UsosDiario u) => {
        'usuario_id': u.usuarioId,
        'fecha': u.fecha.toIso8601String().substring(0, 10),
        'me_gustas_usados': u.meGustasUsados,
        'deshacer_usados': u.deshacerUsados,
        'superlikes_usados': u.superlikesUsados,
        'boosts_usados': u.boostsUsados,
        'vistas_cerca_usadas': u.vistasCercaUsadas,
      };

  UsosDiariosCompanion _usosDiariosDesdeRemoto(Map<String, dynamic> r) =>
      UsosDiariosCompanion.insert(
        usuarioId: r['usuario_id'] as String,
        fecha: PerfilMapeo.parsearFecha(r['fecha']) ?? DateTime.now(),
        meGustasUsados: Value(PerfilMapeo.aInt(r['me_gustas_usados'], 0)),
        deshacerUsados: Value(PerfilMapeo.aInt(r['deshacer_usados'], 0)),
        superlikesUsados: Value(PerfilMapeo.aInt(r['superlikes_usados'], 0)),
        boostsUsados: Value(PerfilMapeo.aInt(r['boosts_usados'], 0)),
        vistasCercaUsadas: Value(PerfilMapeo.aInt(r['vistas_cerca_usadas'], 0)),
      );

  Future<void> _subirPerfil(Usuario perfil) async {
    final body = PerfilMapeo.perfilARemoto(perfil);

    if (kUsarServidorLocal) {
      final token = await LocalTokenStore.obtenerToken();
      if (token == null) return;
      await http.put(
        Uri.parse('$kServidorLocalUrl/api/profiles/${perfil.uuid}'),
        headers: {
          'content-type': 'application/json',
          'authorization': 'Bearer $token'
        },
        body: jsonEncode(body),
      );
      return;
    }

    await sb.Supabase.instance.client.from('profiles').upsert({
      'id': perfil.uuid,
      ...body,
    });
  }

  Future<void> _subirMensaje(Mensaje mensaje) async {
    final body = {
      'id': mensaje.uuid,
      'emisor_id': mensaje.emisorId,
      'receptor_id': mensaje.receptorId,
      'contenido': mensaje.contenido,
      // UTC explícito: sin él, Postgres interpreta el timestamp con la zona
      // del servidor y al re-descargar el mensaje se desplaza horas
      // (desordena la conversación y rompe el cálculo de "visto").
      'timestamp': mensaje.timestamp.toUtc().toIso8601String(),
      'estado_envio': 'enviado',
    };
    debugPrint('[Sync] _subirMensaje upsert: ${jsonEncode(body)}');

    if (kUsarServidorLocal) {
      final token = await LocalTokenStore.obtenerToken();
      if (token == null) return;
      await http.post(
        Uri.parse('$kServidorLocalUrl/api/messages'),
        headers: {
          'content-type': 'application/json',
          'authorization': 'Bearer $token'
        },
        body: jsonEncode(body),
      );
      return;
    }

    await sb.Supabase.instance.client
        .from('messages')
        .upsert(body)
        .timeout(const Duration(seconds: 10));
  }

  Future<void> _subirMatch(Matche match) async {
    final body = {
      'id': match.uuid,
      'usuario_a_id': match.usuarioAId,
      'usuario_b_id': match.usuarioBId,
      // NO incluir timestamp_match: el servidor lo pone con default now()
      // al crear (trigger try_crear_match). Si ya existe, no lo tocamos.
    };

    if (kUsarServidorLocal) {
      final token = await LocalTokenStore.obtenerToken();
      if (token == null) return;
      await http.post(
        Uri.parse('$kServidorLocalUrl/api/matches'),
        headers: {
          'content-type': 'application/json',
          'authorization': 'Bearer $token'
        },
        body: jsonEncode(body),
      );
      return;
    }

    await sb.Supabase.instance.client.from('matches').upsert(body);
  }

  Future<void> _subirReporte(Reporte reporte) async {
    final body = {
      'id': reporte.uuid,
      'reportante_id': reporte.reportanteId,
      'reportado_id': reporte.reportadoId,
      'motivo': reporte.motivo,
      'detalle': reporte.detalle,
      'timestamp': reporte.timestamp.toIso8601String(),
    };

    if (kUsarServidorLocal) {
      final token = await LocalTokenStore.obtenerToken();
      if (token == null) return;
      await http.post(
        Uri.parse('$kServidorLocalUrl/api/reports'),
        headers: {
          'content-type': 'application/json',
          'authorization': 'Bearer $token'
        },
        body: jsonEncode(body),
      );
      return;
    }

    await sb.Supabase.instance.client.from('reports').upsert(body);
  }

  Future<void> _subirBloqueo(Bloqueo bloqueo) async {
    final body = {
      'id': bloqueo.uuid,
      'bloqueador_id': bloqueo.bloqueadorId,
      'bloqueado_id': bloqueo.bloqueadoId,
      'timestamp': bloqueo.timestamp.toIso8601String(),
    };

    if (kUsarServidorLocal) {
      final token = await LocalTokenStore.obtenerToken();
      if (token == null) return;
      await http.post(
        Uri.parse('$kServidorLocalUrl/api/blocks'),
        headers: {
          'content-type': 'application/json',
          'authorization': 'Bearer $token'
        },
        body: jsonEncode(body),
      );
      return;
    }

    await sb.Supabase.instance.client.from('blocks').upsert(body);
  }

  Future<void> _subirVisita(Visita visita) async {
    final body = {
      'id': visita.uuid,
      'visitante_id': visita.visitanteId,
      'visitado_id': visita.visitadoId,
      'timestamp': visita.timestamp.toIso8601String(),
    };

    if (kUsarServidorLocal) {
      final token = await LocalTokenStore.obtenerToken();
      if (token == null) return;
      await http.post(
        Uri.parse('$kServidorLocalUrl/api/visits'),
        headers: {
          'content-type': 'application/json',
          'authorization': 'Bearer $token'
        },
        body: jsonEncode(body),
      );
      return;
    }

    await sb.Supabase.instance.client.from('visitas').upsert(body);
  }

  Future<void> _subirHistorialLike(HistorialLike like) async {
    final body = {
      'id': like.uuid,
      'usuario_id': like.usuarioId,
      'usuario_likeado_id': like.usuarioLikeadoId,
      'timestamp': like.timestamp.toIso8601String(),
      'es_super': like.esSuper,
    };

    if (kUsarServidorLocal) {
      final token = await LocalTokenStore.obtenerToken();
      if (token == null) return;
      await http.post(
        Uri.parse('$kServidorLocalUrl/api/likes'),
        headers: {
          'content-type': 'application/json',
          'authorization': 'Bearer $token'
        },
        body: jsonEncode(body),
      );
      return;
    }

    await sb.Supabase.instance.client.from('historial_likes').upsert(body);
  }

  Future<void> _subirRechazo(Rechazo rechazo) async {
    if (kUsarServidorLocal) return;

    final body = {
      'id': rechazo.uuid,
      'usuario_id': rechazo.usuarioId,
      'rechazado_id': rechazo.rechazadoId,
      'timestamp': rechazo.timestamp.toIso8601String(),
    };
    await sb.Supabase.instance.client.from('rechazos').upsert(body);
  }

  // ------------------------------------------------------------
  // Feed de cercanÃ­a
  // ------------------------------------------------------------
  /// Lee la ubicaciÃ³n ya guardada del perfil propio (local) y, si es
  /// vÃ¡lida, sincroniza el feed de perfiles cercanos con esas coordenadas.
  /// Si el perfil aÃºn no tiene ubicaciÃ³n (0,0 â€” nunca la estableciÃ³), no
  /// hace nada: no tiene sentido pedir "cercanos" sin saber dÃ³nde estÃ¡.
  Future<void> _sincronizarFeedCercanoDesdePerfilPropio() async {
    final propio = await (_db.select(_db.usuarios)
          ..where((u) => u.esPerfilPropio.equals(true)))
        .getSingleOrNull();
    if (propio == null) return;
    if (propio.ubicacionLat == 0 && propio.ubicacionLon == 0) return;
    await sincronizarFeedCercano(
      lat: propio.ubicacionLat,
      lon: propio.ubicacionLon,
      radioMetros: feedRadioMetrosDefault,
    );
  }

  Future<void> sincronizarFeedCercano({
    required double lat,
    required double lon,
    int radioMetros = 20000,
    Map<String, dynamic> filtros = const <String, dynamic>{},
    int desde = 0,
    int cuantos = 500,
  }) async {
    if (!ConnectivityService.instancia.hayConexion) return;

    if (kUsarServidorLocal) {
      final token = await LocalTokenStore.obtenerToken();
      if (token == null) return;
      final res = await http.get(
        Uri.parse('$kServidorLocalUrl/api/profiles'),
        headers: {'authorization': 'Bearer $token'},
      );
      if (res.statusCode != 200) return;
      final lista = jsonDecode(res.body) as List;
      if (lista.isEmpty) return;
      final filas = lista.map((fila) {
        final f = fila as Map<String, dynamic>;
        return PerfilMapeo.perfilRemotoACompanion(f, esPropio: false);
      }).toList();
      await _db.batch((batch) {
        batch.insertAllOnConflictUpdate(_db.usuarios, filas);
      });
      return;
    }

    final resultado = await sb.Supabase.instance.client.rpc('perfiles_cercanos',
        params: {
          'lat': lat,
          'lon': lon,
          'radio_metros': radioMetros,
          'filtros': filtros,
          'desde': desde,
          'cuantos': cuantos,
        });
    final filas = (resultado as List).map((fila) {
      return PerfilMapeo.perfilRemotoACompanion(
        fila as Map<String, dynamic>,
        esPropio: false,
      );
    }).toList();
    if (filas.isNotEmpty) {
      await _db.batch((batch) {
        batch.insertAllOnConflictUpdate(_db.usuarios, filas);
      });
    }
  }

  /// Consulta el feed directamente al backend (RPC `perfiles_cercanos` o API
  /// local) y devuelve los perfiles como filas locales [Usuario], sin
  /// persistirlos. Fase 2: filtros y paginación en el servidor.
  Future<List<Usuario>> consultarFeedRemoto({
    required double lat,
    required double lon,
    int radioMetros = feedRadioMetrosDefault,
    Map<String, dynamic> filtros = const <String, dynamic>{},
    int desde = 0,
    int cuantos = 10,
  }) async {
    if (!ConnectivityService.instancia.hayConexion) return const [];

    try {
      if (kUsarServidorLocal) {
        final token = await LocalTokenStore.obtenerToken();
        if (token == null) return const [];
        final res = await http.get(
          Uri.parse('$kServidorLocalUrl/api/profiles'),
          headers: {'authorization': 'Bearer $token'},
        );
        if (res.statusCode != 200) return const [];
        final lista = jsonDecode(res.body) as List;
        return lista.map((fila) {
          final f = fila as Map<String, dynamic>;
          return PerfilMapeo.perfilRemotoAUsuario(f, esPropio: false);
        }).toList();
      }

      final resultado = await sb.Supabase.instance.client.rpc(
          'perfiles_cercanos',
          params: {
            'lat': lat,
            'lon': lon,
            'radio_metros': radioMetros,
            'filtros': filtros,
            'desde': desde,
            'cuantos': cuantos,
          });
      return (resultado as List).map((fila) {
        return PerfilMapeo.perfilRemotoAUsuario(
          fila as Map<String, dynamic>,
          esPropio: false,
        );
      }).toList();
    } catch (e) {
      EstadoServidorServicio.instancia.marcarFallo(e);
      return const [];
    }
  }

  // ------------------------------------------------------------
  // Filtros de búsqueda -> JSON del RPC perfiles_cercanos
  // ------------------------------------------------------------
  /// Convierte los filtros de la UI (FiltrosEncuentros) en el JSON que espera
  /// el RPC `perfiles_cercanos`, para que el servidor descarte los perfiles
  /// que no cumplen antes de sincronizarlos a la BD local.
  static Map<String, dynamic> filtrosARpcJson({
    List<String> generos = const [],
    double edadMin = 18,
    double edadMax = 99,
    bool enLineaAhora = false,
    bool perfilesVerificados = false,
    String ciudad = '',
    bool ampliar = false,
    String orden = 'distancia',
  }) {
    return <String, dynamic>{
      'ampliar': ampliar,
      'orden': orden,
      'edad_min': edadMin.round(),
      'edad_max': edadMax.round(),
      'en_linea': enLineaAhora,
      'verificado': perfilesVerificados,
      if (generos.isNotEmpty) 'generos': generos,
      if (ciudad.trim().isNotEmpty) 'ciudad': ciudad.trim(),
    };
  }
}
