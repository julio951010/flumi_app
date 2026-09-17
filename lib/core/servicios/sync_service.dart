import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../config/env.dart';
import '../constantes/constantes.dart';
import '../base_datos_local/database.dart';
import '../utilidades/perfil_mapeo.dart';
import 'connectivity_service.dart';
import 'estado_servidor_servicio.dart';

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
        if (local != null && !_remotoTieneDatos(remoto)) {
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
    if (_sincronizandoMensajes) return;
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

    for (final mensaje in pendientes) {
      try {
        await _subirMensaje(mensaje);
        await (_db.update(_db.mensajes)
              ..where((m) => m.uuid.equals(mensaje.uuid)))
            .write(const MensajesCompanion(
          pendienteDeSincronizar: Value(false),
          estadoEnvio: Value('enviado'),
        ));
        EstadoServidorServicio.instancia.marcarExito();
      } catch (e) {
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
          .or('emisor_id.eq.$userId,receptor_id.eq.$userId');
      final filas =
          (remoto as List).map((f) => f as Map<String, dynamic>).toList();
      final pendientesLocales = (await (_db.select(_db.mensajes)
            ..where((m) => m.pendienteDeSincronizar.equals(true)))
          .get())
          .map((m) => m.uuid)
          .toSet();
      final borrados = await _leerMensajesBorrados();

      final companiones = <MensajesCompanion>[];
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
    } catch (_) {}
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
      final filas = (remoto as List).map((fila) {
        final f = fila as Map<String, dynamic>;
        return MatchesCompanion.insert(
          uuid: f['id'] as String,
          usuarioAId: f['usuario_a_id'] as String,
          usuarioBId: f['usuario_b_id'] as String,
          timestampMatch:
              PerfilMapeo.parsearFecha(f['timestamp_match']) ?? DateTime.now(),
          ultimoMensajePreview: const Value.absent(),
          ultimoMensajeTimestamp: const Value.absent(),
          leidoHasta: const Value.absent(),
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

      if (local != null) {
        await sb.Supabase.instance.client
            .from('suscripciones')
            .upsert(_suscripcionARemoto(local));
      }

      // Descargar la suscripciÃ³n remota para mantener coherencia local
      final remoto = await sb.Supabase.instance.client
          .from('suscripciones')
          .select()
          .eq('usuario_id', userIdFinal)
          .maybeSingle();
      if (remoto != null) {
        await _db.into(_db.suscripciones).insertOnConflictUpdate(
              _suscripcionDesdeRemoto(remoto),
            );
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
          return HistorialLikesCompanion.insert(
            uuid: f['id'] as String,
            usuarioId: f['usuario_id'] as String,
            usuarioLikeadoId: f['usuario_likeado_id'] as String,
            timestamp: Value(PerfilMapeo.parsearFecha(f['timestamp']) ?? DateTime.now()),
            pendienteDeSincronizar: const Value(false),
            leidoHasta: Value(leidoHastaMasReciente(
                leidosLocales[f['id']],
                PerfilMapeo.parsearFecha(f['leido_hasta']))),
            esSuper: Value((f['es_super'] as bool?) ?? false),
          );
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
        return HistorialLikesCompanion.insert(
          uuid: f['id'] as String,
          usuarioId: f['usuario_id'] as String,
          usuarioLikeadoId: f['usuario_likeado_id'] as String,
          timestamp: Value(PerfilMapeo.parsearFecha(f['timestamp']) ?? DateTime.now()),
          pendienteDeSincronizar: const Value(false),
          leidoHasta: Value(leidoHastaMasReciente(
              leidosLocales[f['id']],
              PerfilMapeo.parsearFecha(f['leido_hasta']))),
          esSuper: Value((f['es_super'] as bool?) ?? false),
        );
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
      }).toList();
      if (filas.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAllOnConflictUpdate(_db.rechazos, filas);
        });
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

  /// Borra el rechazo remoto (Deshacer). Best-effort: si falla, el siguiente
  /// sync de rechazos no lo reintenta (el rechazo ya no existe localmente).
  Future<void> borrarRechazoRemoto(String usuarioId, String rechazadoId) async {
    if (!ConnectivityService.instancia.hayConexion) return;
    if (kUsarServidorLocal) return;
    try {
      await sb.Supabase.instance.client
          .from('rechazos')
          .delete()
          .match({'usuario_id': usuarioId, 'rechazado_id': rechazadoId});
    } catch (_) {}
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
      };

  SuscripcionesCompanion _suscripcionDesdeRemoto(Map<String, dynamic> r) =>
      SuscripcionesCompanion.insert(
        usuarioId: r['usuario_id'] as String,
        plan: Value((r['plan'] as String?) ?? 'gratis'),
        inicio: Value(PerfilMapeo.parsearFecha(r['inicio']) ?? DateTime.now()),
        vence: Value(PerfilMapeo.parsearFecha(r['vence'])),
        activa: Value(PerfilMapeo.aBool(r['activa'], true)),
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

    await sb.Supabase.instance.client.from('messages').upsert(body);
  }

  Future<void> _subirMatch(Matche match) async {
    final body = {
      'id': match.uuid,
      'usuario_a_id': match.usuarioAId,
      'usuario_b_id': match.usuarioBId,
      'timestamp_match': match.timestampMatch.toUtc().toIso8601String(),
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
