import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../config/env.dart';
import '../base_datos_local/database.dart';
import '../base_datos_local/tables.dart';
import 'connectivity_service.dart';

class SyncService {
  SyncService(this._db);

  final AppDatabase _db;

  bool _sincronizando = false;

  String? get _token => null;

  Future<void> sincronizarTodo({String? userId, bool alIniciarSesion = false}) async {
    if (kUsarModoMock) return;
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
      ]);
    } catch (e) {
      // Un fallo de red no debe bloquear el resto de la app.
      print('[sync] Error en sincronizarTodo: $e');
    } finally {
      _sincronizando = false;
    }
  }

  /// Sincroniza únicamente el perfil propio de inmediato.
  /// Se usa tras editar el perfil o cambiar ajustes de privacidad,
  /// para no depender únicamente de los disparadores de conectividad/auth.
  Future<void> sincronizarPerfil({String? userId}) async {
    if (kUsarModoMock) return;
    try {
      await _sincronizarPerfilPropio(userId);
    } catch (_) {}
  }

  /// Garantiza que exista un perfil propio local: lo descarga de Supabase
  /// o lo crea a partir del usuario autenticado. Devuelve true si existe.
  /// `userId` debe venir del evento de auth (nunca de auth.currentUser justo
  /// tras iniciar sesión: puede apuntar todavía al usuario anterior).
  Future<bool> asegurarPerfilPropio([String? userId]) async {
    if (kUsarModoMock) return false;
    try {
      await _sincronizarPerfilPropio(userId);
    } catch (_) {}
    return (await (_db.select(_db.usuarios)
              ..where((u) => u.esPerfilPropio.equals(true)))
            .getSingleOrNull()) !=
        null;
  }

  /// True mientras un sincronizado completo está en curso (evita tormentas
  /// de refrescos cuando muchas pantallas piden datos a la vez).
  bool get estaSincronizando => _sincronizando;

  /// Id del usuario autenticado actual (o 'local-dev' con servidor local).
  String? get userIdActual => _obtenerUserId();

  /// Refresca (o crea) en la BD local el perfil remoto de un usuario.
  /// Devuelve true si el servidor tenía datos y se guardaron.
  Future<bool> refrescarPerfilRemoto(String uuid) async {
    if (kUsarModoMock) return false;
    if (!ConnectivityService.instancia.hayConexion) return false;
    try {
      final remoto = await _fetchPerfil(uuid);
      if (remoto == null) return false;
      // Si este perfil es el propio y tiene cambios locales sin subir, la
      // descarga remota podría revertirlos con datos viejos: el local manda.
      final conPendientes = await (_db.select(_db.usuarios)
            ..where((u) =>
                u.uuid.equals(uuid) &
                u.esPerfilPropio.equals(true) &
                u.pendienteDeSincronizar.equals(true)))
          .getSingleOrNull();
      if (conPendientes != null) return false;
      await _db.into(_db.usuarios).insertOnConflictUpdate(
            _mapearPerfilRemoto(remoto, uuid == userIdActual).copyWith(
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
  // Supabase (fuente de verdad) y solo nos quedamos con la caché local si el
  // servidor no devuelve datos. Nunca sobrescribimos datos locales buenos con
  // un perfil vacío.
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

    // Subir primero los cambios pendientes para dejar el servidor al día.
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
      // La subida falló (RLS, CHECK, tipos de columna, red...). No borramos
      // la marca pendiente para reintentar más tarde, pero lo registramos
      // para poder diagnosticar por qué el perfil no llega a Supabase.
      print('[sync] Error al subir el perfil propio: $e');
    }
      }
    }

    // En el login cargamos desde Supabase; si hay perfil remoto lo usamos,
    // si no (sin red / sin perfil en servidor) conservamos la caché local.
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
        // Si la caché local tiene cambios pendientes que aún no se subieron
        // (p. ej. fotos recién editadas/eliminadas), NO la sobreescribimos
        // con el remoto: el servidor podría traer datos viejos y revertiría
        // el cambio del usuario. El upload ya se intentó arriba; si falló,
        // la marca pendiente se conserva y el cambio se reintentará.
        if (local != null && local.pendienteDeSincronizar) {
          return;
        }
        // Re-chequeo justo antes de sobrescribir: la descarga remota pudo
        // haber arrancado ANTES de que el usuario guardara un cambio, y al
        // terminar (red lenta) traería datos viejos que revertirían la edición
        // local recién escrita. Si en este instante hay pendientes, el cambio
        // local manda y se preserva (el upload fire-and-forget de la edición
        // ya está subiéndolo).
        final reciente = await (_db.select(_db.usuarios)
              ..where((u) =>
                  u.esPerfilPropio.equals(true) &
                  u.pendienteDeSincronizar.equals(true)))
            .getSingleOrNull();
        if (reciente != null) {
          return;
        }
        // Si ya tenemos caché local, NO la sobreescribimos con un perfil
        // vacío del servidor (p. ej. porque la subida falló silenciosamente).
        // Usamos el servidor solo cuando este trae datos; si no, conservamos
        // la caché local para no perder la información del usuario.
        if (local != null && !_remotoTieneDatos(remoto)) {
          return;
        }
        try {
          await _db.into(_db.usuarios).insertOnConflictUpdate(
                _mapearPerfilRemoto(remoto, true).copyWith(
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
              _mapearPerfilRemoto(respaldo, true).copyWith(
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
            _mapearPerfilRemoto(remoto, true).copyWith(
              pendienteDeSincronizar: const Value(true),
            ),
          );
    }
  }

  // ------------------------------------------------------------
  // Mensajes
  // ------------------------------------------------------------
  /// Sube de inmediato los mensajes pendientes (write-through tras enviar).
  Future<void> sincronizarMensajesPendientes() async {
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
      } catch (_) {
        final intentos = mensaje.intentosDeSincronizacion + 1;
        await (_db.update(_db.mensajes)
              ..where((m) => m.uuid.equals(mensaje.uuid)))
            .write(MensajesCompanion(
          intentosDeSincronizacion: Value(intentos),
          estadoEnvio: Value(intentos >= 5 ? 'fallido' : mensaje.estadoEnvio),
        ));
      }
    }
  }

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

      // Descargar la suscripción remota para mantener coherencia local
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
  // Usos diarios (límites por plan)
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

      if (local != null) {
        await sb.Supabase.instance.client
            .from('usos_diarios')
            .upsert(_usosDiariosARemoto(local));
      }

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
      }
    } catch (_) {}
  }

  // ------------------------------------------------------------
  // Visitas (quién visitó a quién)
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
            timestamp: Value(_parsearFecha(f['timestamp']) ?? DateTime.now()),
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

      // Descargar las visitas recibidas para "quien te vio"
      final remoto = await sb.Supabase.instance.client
          .from('visitas')
          .select()
          .eq('visitado_id', userIdResuelto);
      final filas = (remoto as List).map((fila) {
        final f = fila as Map<String, dynamic>;
        return VisitasCompanion.insert(
          uuid: f['id'] as String,
          visitanteId: f['visitante_id'] as String,
          visitadoId: f['visitado_id'] as String,
          timestamp: Value(_parsearFecha(f['timestamp']) ?? DateTime.now()),
          pendienteDeSincronizar: const Value(false),
        );
      }).toList();
      if (filas.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAllOnConflictUpdate(_db.visitas, filas);
        });
      }
    } catch (_) {}
  }

  // ------------------------------------------------------------
  // Historial de likes
  // ------------------------------------------------------------
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
        final filas = lista.map((fila) {
          final f = fila as Map<String, dynamic>;
          return HistorialLikesCompanion.insert(
            uuid: f['id'] as String,
            usuarioId: f['usuario_id'] as String,
            usuarioLikeadoId: f['usuario_likeado_id'] as String,
            timestamp: Value(_parsearFecha(f['timestamp']) ?? DateTime.now()),
            pendienteDeSincronizar: const Value(false),
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
          .eq('usuario_id', userIdResuelto);
      final filas = (remoto as List).map((fila) {
        final f = fila as Map<String, dynamic>;
        return HistorialLikesCompanion.insert(
          uuid: f['id'] as String,
          usuarioId: f['usuario_id'] as String,
          usuarioLikeadoId: f['usuario_likeado_id'] as String,
          timestamp: Value(_parsearFecha(f['timestamp']) ?? DateTime.now()),
          pendienteDeSincronizar: const Value(false),
        );
      }).toList();
      if (filas.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAllOnConflictUpdate(_db.historialLikes, filas);
        });
      }
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

  String _getAuthHeader() {
    final prefs = _localPrefs();
    return prefs != null ? 'Bearer $prefs' : '';
  }

  String? _localPrefs() {
    return null;
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
    return remoto as Map<String, dynamic>?;
  }

  // Perfil local de respaldo a partir del usuario autenticado, por si la
  // descarga remota falla o el perfil remoto aún no existe.
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

  // Indica si el perfil remoto trae datos de perfil (no está vacío).
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

  // Mapea el perfil remoto (Supabase o servidor local) al companion local.
  UsuariosCompanion _mapearPerfilRemoto(
    Map<String, dynamic> p,
    bool esPropio,
  ) {
    final fechaNacRaw = p['fecha_nacimiento'] as String?;
    final fechaNac =
        fechaNacRaw != null ? _parsearFecha(fechaNacRaw) : null;
    final edadRemota = p['edad'];
    final edad = (edadRemota is int && edadRemota > 0)
        ? edadRemota
        : (fechaNac != null
            ? _calcularEdad(fechaNac.toIso8601String())
            : 18);

    return UsuariosCompanion.insert(
      uuid: p['id'] as String,
      nombre: (p['nombre'] as String?) ?? '',
      edad: edad,
      genero: (p['genero'] as String?) ?? 'otro',
      buscaGenero: (p['busca_genero'] as String?) ?? 'otro',
      biografia: Value((p['biografia'] as String?) ?? ''),
      queBusca: Value((p['que_busca'] as String?) ?? ''),
      preferenciaEdadMin: Value(_aInt(p['preferencia_edad_min'], 18)),
      preferenciaEdadMax: Value(_aInt(p['preferencia_edad_max'], 99)),
      fechaNacimiento: Value(fechaNac),
      ciudad: Value((p['ciudad'] as String?) ?? ''),
      ubicacionLat: Value(_aDouble(p['ubicacion_lat'], 0.0)),
      ubicacionLon: Value(_aDouble(p['ubicacion_lon'], 0.0)),
      ultimaConexion: Value(_parsearFecha(p['ultima_conexion'])),
      ocultarEnLinea: Value(_aBool(p['ocultar_en_linea'], false)),
      ocultarEdad: Value(_aBool(p['ocultar_edad'], false)),
      verificadoStatus: Value(_aBool(p['verificado_status'], false)),
      scorePopularidad: Value(_aInt(p['score_popularidad'], 0)),
      perfilCompletado: Value(_aBool(p['perfil_completado'], false)),
      orientacionSexual: Value((p['orientacion_sexual'] as String?) ?? ''),
      situacionSentimental:
          Value((p['situacion_sentimental'] as String?) ?? ''),
      intereses: Value(_aListaString(p['intereses'])),
      altura: Value((p['altura'] as String?) ?? ''),
      educacion: Value((p['educacion'] as String?) ?? ''),
      trabajo: Value((p['trabajo'] as String?) ?? ''),
      profesion: Value((p['profesion'] as String?) ?? ''),
      preferenciaRelacion: Value((p['preferencia_relacion'] as String?) ?? ''),
      bebe: Value((p['bebe'] as String?) ?? ''),
      fuma: Value((p['fuma'] as String?) ?? ''),
      hijos: Value((p['hijos'] as String?) ?? ''),
      personalidad: Value((p['personalidad'] as String?) ?? ''),
      signoZodiaco: Value((p['signo_zodiaco'] as String?) ?? ''),
      mascotas: Value((p['mascotas'] as String?) ?? ''),
      religion: Value((p['religion'] as String?) ?? ''),
      idiomas: Value((p['idiomas'] as String?) ?? ''),
      tatuajes: Value((p['tatuajes'] as String?) ?? ''),
      preguntasPerfil: Value(_aPreguntas(p['preguntas_perfil'])),
      fotoVerificacion: Value((p['foto_verificacion'] as String?) ?? ''),
      fotosUrls: Value(_aListaString(p['fotos_urls'])),
      creadoEn: Value(_parsearFecha(p['creado_en']) ?? DateTime.now()),
      esPerfilPropio: Value(esPropio),
      pendienteDeSincronizar: const Value(false),
    );
  }

  // Convierte el perfil local en el mapa que se sube al servidor.
  // 'genero' y 'busca_genero' se normalizan a minúsculas porque la UI los
  // guarda capitalizados ('Mujer', 'No binario') y el CHECK constraint de
  // Supabase admite solo ('hombre','mujer','otro','mujer trans',
  // 'hombre trans','no binario','género fluido').
  Map<String, dynamic> _perfilARemoto(Usuario perfil) {
    return {
      'nombre': perfil.nombre,
      'biografia': perfil.biografia,
      'genero': perfil.genero.toLowerCase(),
      'busca_genero': perfil.buscaGenero.toLowerCase(),
      'que_busca': perfil.queBusca,
      'preferencia_edad_min': perfil.preferenciaEdadMin,
      'preferencia_edad_max': perfil.preferenciaEdadMax,
      'fecha_nacimiento': perfil.fechaNacimiento != null
          ? perfil.fechaNacimiento!.toIso8601String().substring(0, 10)
          : null,
      'ciudad': perfil.ciudad,
      'ubicacion_lat': perfil.ubicacionLat,
      'ubicacion_lon': perfil.ubicacionLon,
      'ultima_conexion': perfil.ultimaConexion?.toIso8601String(),
      'ocultar_en_linea': perfil.ocultarEnLinea,
      'ocultar_edad': perfil.ocultarEdad,
      'perfil_completado': perfil.perfilCompletado,
      'orientacion_sexual': perfil.orientacionSexual,
      'situacion_sentimental': perfil.situacionSentimental,
      'intereses': perfil.intereses,
      'altura': perfil.altura,
      'educacion': perfil.educacion,
      'trabajo': perfil.trabajo,
      'profesion': perfil.profesion,
      'preferencia_relacion': perfil.preferenciaRelacion,
      'bebe': perfil.bebe,
      'fuma': perfil.fuma,
      'hijos': perfil.hijos,
      'personalidad': perfil.personalidad,
      'signo_zodiaco': perfil.signoZodiaco,
      'mascotas': perfil.mascotas,
      'religion': perfil.religion,
      'idiomas': perfil.idiomas,
      'tatuajes': perfil.tatuajes,
      'preguntas_perfil':
          perfil.preguntasPerfil.map((e) => e.toJson()).toList(),
      'foto_verificacion': perfil.fotoVerificacion,
      'fotos_urls': perfil.fotosUrls,
      'edad': perfil.edad,
    };
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
        inicio: Value(_parsearFecha(r['inicio']) ?? DateTime.now()),
        vence: Value(_parsearFecha(r['vence'])),
        activa: Value(_aBool(r['activa'], true)),
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
        fecha: _parsearFecha(r['fecha']) ?? DateTime.now(),
        meGustasUsados: Value(_aInt(r['me_gustas_usados'], 0)),
        deshacerUsados: Value(_aInt(r['deshacer_usados'], 0)),
        superlikesUsados: Value(_aInt(r['superlikes_usados'], 0)),
        boostsUsados: Value(_aInt(r['boosts_usados'], 0)),
        vistasCercaUsadas: Value(_aInt(r['vistas_cerca_usadas'], 0)),
      );

  Future<void> _subirPerfil(Usuario perfil) async {
    final body = _perfilARemoto(perfil);

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
      'timestamp': mensaje.timestamp.toIso8601String(),
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
      'timestamp_match': match.timestampMatch.toIso8601String(),
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

  // ------------------------------------------------------------
  // Feed de cercanía
  // ------------------------------------------------------------
  Future<void> sincronizarFeedCercano({
    required double lat,
    required double lon,
    int radioMetros = 20000,
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
        return _mapearPerfilRemoto(f, false);
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
        });
    final filas = (resultado as List).map((fila) {
      return _mapearPerfilRemoto(fila as Map<String, dynamic>, false);
    }).toList();
    if (filas.isNotEmpty) {
      await _db.batch((batch) {
        batch.insertAllOnConflictUpdate(_db.usuarios, filas);
      });
    }
  }

  // ------------------------------------------------------------
  // Utilidades de parseo
  // ------------------------------------------------------------
  DateTime? _parsearFecha(dynamic valor) {
    if (valor == null) return null;
    if (valor is DateTime) return valor;
    if (valor is String) return DateTime.tryParse(valor);
    return null;
  }

  int _aInt(dynamic valor, int defecto) {
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();
    if (valor is String) return int.tryParse(valor) ?? defecto;
    return defecto;
  }

  double _aDouble(dynamic valor, double defecto) {
    if (valor is double) return valor;
    if (valor is int) return valor.toDouble();
    if (valor is num) return valor.toDouble();
    if (valor is String) return double.tryParse(valor) ?? defecto;
    return defecto;
  }

  bool _aBool(dynamic valor, bool defecto) {
    if (valor is bool) return valor;
    if (valor is String) return valor.toLowerCase() == 'true';
    return defecto;
  }

  List<String> _aListaString(dynamic valor) {
    if (valor == null) return [];
    if (valor is List) return valor.map((e) => e.toString()).toList();
    if (valor is String && valor.isNotEmpty) {
      try {
        final decodificado = jsonDecode(valor);
        if (decodificado is List) {
          return decodificado.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  List<PreguntaRespuesta> _aPreguntas(dynamic valor) {
    if (valor == null) return [];
    dynamic lista = valor;
    if (valor is String && valor.isNotEmpty) {
      try {
        lista = jsonDecode(valor);
      } catch (_) {
        return [];
      }
    }
    if (lista is! List) return [];
    return lista.whereType<Map>().map((m) {
      final mapa = Map<String, dynamic>.from(m);
      return PreguntaRespuesta(
        pregunta: (mapa['pregunta'] ?? '').toString(),
        respuesta: (mapa['respuesta'] ?? '').toString(),
      );
    }).toList();
  }

  int _calcularEdad(String fechaNacimientoIso) {
    final nacimiento = DateTime.parse(fechaNacimientoIso);
    final hoy = DateTime.now();
    var edad = hoy.year - nacimiento.year;
    if (hoy.month < nacimiento.month ||
        (hoy.month == nacimiento.month && hoy.day < nacimiento.day)) {
      edad--;
    }
    return edad;
  }
}
