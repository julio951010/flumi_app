import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../base_datos_local/database.dart';
import 'connectivity_service.dart';

/// Sincroniza en 3 niveles de prioridad, mismo espíritu que el SyncService
/// de Closi: mensajes/matches primero (casi tiempo real), perfil propio
/// después, y el feed de cercanía queda fuera del ciclo automático — se
/// dispara solo cuando el usuario lo pide (pull-to-refresh, abrir el mapa),
/// para no gastar datos móviles en cada reconexión.
class SyncService {
  SyncService(this._db);

  final AppDatabase _db;
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _sincronizando = false;

  Future<void> sincronizarTodo() async {
    if (_sincronizando) return;
    if (!ConnectivityService.instancia.hayConexion) return;

    _sincronizando = true;
    try {
      await _descargarCambiosRemotos();
      await _sincronizarMensajesPendientes();
      await _sincronizarMatchesPendientes();
      await _sincronizarPerfilPropio();
      await _sincronizarReportesPendientes();
      await _sincronizarBloqueosPendientes();
    } finally {
      _sincronizando = false;
    }
  }

  Future<DateTime?> _ultimoTimestampSincronizacion() async {
    final propio = await (_db.select(_db.usuarios)
          ..where((u) => u.esPerfilPropio.equals(true)))
        .getSingleOrNull();
    return propio?.ultimaSincronizacionTimestamp;
  }

  Future<void> _descargarCambiosRemotos() async {
    final ultimoSync = await _ultimoTimestampSincronizacion();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // Descargar solo perfiles nuevos o actualizados desde el último sync
    if (ultimoSync != null) {
      final perfilesRemotos = await _supabase
          .from('profiles')
          .select()
          .gte('creado_en', ultimoSync.toIso8601String())
          .neq('id', userId);

      for (final perfil in perfilesRemotos) {
        final existente = await (_db.select(_db.usuarios)
              ..where((u) => u.uuid.equals(perfil['id'])))
            .getSingleOrNull();

        if (existente == null) {
          final creadoEn = perfil['creado_en'] != null
              ? DateTime.parse(perfil['creado_en'])
              : DateTime.now();
          final fechaNac = perfil['fecha_nacimiento'] as String?;
          await _db.into(_db.usuarios).insertOnConflictUpdate(
            UsuariosCompanion.insert(
              uuid: perfil['id'],
              nombre: perfil['nombre'] ?? '',
              edad: fechaNac != null ? _calcularEdad(fechaNac) : 18,
              genero: perfil['genero'] ?? 'otro',
              buscaGenero: perfil['busca_genero'] ?? 'otro',
              biografia: Value(perfil['biografia'] ?? ''),
              verificadoStatus: Value(perfil['verificado_status'] ?? false),
              scorePopularidad: Value(perfil['score_popularidad'] ?? 0),
              esPerfilPropio: const Value(false),
              pendienteDeSincronizar: const Value(false),
              creadoEn: Value(creadoEn),
            ),
          );
        }
      }
    }

    // Descargar mensajes remotos que no estén en local
    final mensajesLocales = await (_db.select(_db.mensajes)).get();
    final uuidsLocalesSet = mensajesLocales.map((m) => m.uuid).toSet();

    final mensajesRemotos = await _supabase
        .from('messages')
        .select()
        .or('emisor_id.eq.$userId,receptor_id.eq.$userId');

    for (final msg in mensajesRemotos) {
      final id = msg['id'] as String;
      if (uuidsLocalesSet.contains(id)) continue;
      await _db.into(_db.mensajes).insertOnConflictUpdate(
        MensajesCompanion.insert(
          uuid: id,
          emisorId: msg['emisor_id'],
          receptorId: msg['receptor_id'],
          contenido: msg['contenido'],
          timestamp: DateTime.parse(msg['timestamp']),
        ),
      );
    }
  }

  // ------------------------------------------------------------
  // PRIORIDAD ALTA: mensajes
  // ------------------------------------------------------------
  Future<void> _sincronizarMensajesPendientes() async {
    final pendientes = await (_db.select(_db.mensajes)
          ..where((m) => m.pendienteDeSincronizar.equals(true))
          ..orderBy([(m) => OrderingTerm.asc(m.timestamp)]))
        .get();

    for (final mensaje in pendientes) {
      try {
        await _supabase.from('messages').upsert({
          'id': mensaje.uuid,
          'emisor_id': mensaje.emisorId,
          'receptor_id': mensaje.receptorId,
          'contenido': mensaje.contenido,
          'timestamp': mensaje.timestamp.toIso8601String(),
          'estado_envio': 'enviado',
        });

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
        // seguimos con el resto de la cola, no abortamos todo por un fallo
      }
    }
  }

  // ------------------------------------------------------------
  // PRIORIDAD ALTA: matches
  // ------------------------------------------------------------
  Future<void> _sincronizarMatchesPendientes() async {
    final pendientes = await (_db.select(_db.matches)
          ..where((m) => m.pendienteDeSincronizar.equals(true)))
        .get();

    for (final match in pendientes) {
      try {
        await _supabase.from('matches').upsert({
          'id': match.uuid,
          'usuario_a_id': match.usuarioAId,
          'usuario_b_id': match.usuarioBId,
          'timestamp_match': match.timestampMatch.toIso8601String(),
        });

        await (_db.update(_db.matches)
              ..where((m) => m.uuid.equals(match.uuid)))
            .write(const MatchesCompanion(pendienteDeSincronizar: Value(false)));
      } catch (_) {
        // se reintenta en la próxima corrida
      }
    }
  }

  // ------------------------------------------------------------
  // PRIORIDAD MEDIA: perfil propio
  // ------------------------------------------------------------
  Future<void> _sincronizarPerfilPropio() async {
    final propio = await (_db.select(_db.usuarios)
          ..where((u) =>
              u.esPerfilPropio.equals(true) &
              u.pendienteDeSincronizar.equals(true)))
        .getSingleOrNull();

    if (propio == null) return;

    try {
      await _supabase.from('profiles').upsert({
        'id': propio.uuid,
        'nombre': propio.nombre,
        'biografia': propio.biografia,
        'genero': propio.genero,
        'busca_genero': propio.buscaGenero,
        'preferencia_edad_min': propio.preferenciaEdadMin,
        'preferencia_edad_max': propio.preferenciaEdadMax,
        // ubicacion se arma en el backend con ST_MakePoint via trigger,
        // aquí mandamos lat/lon planos.
        'ubicacion_lat': propio.ubicacionLat,
        'ubicacion_lon': propio.ubicacionLon,
      });

      await (_db.update(_db.usuarios)
            ..where((u) => u.uuid.equals(propio.uuid)))
          .write(UsuariosCompanion(
        pendienteDeSincronizar: const Value(false),
        ultimaSincronizacionTimestamp: Value(DateTime.now()),
      ));
    } catch (_) {
      // se reintenta en la próxima corrida
    }
  }

  // ------------------------------------------------------------
  // PRIORIDAD BAJA: feed de perfiles cercanos.
  // Se llama explícitamente desde la UI, NO automáticamente en cada
  // reconexión, para cuidar datos móviles.
  // ------------------------------------------------------------
  Future<void> sincronizarFeedCercano({
    required double lat,
    required double lon,
    int radioMetros = 20000,
  }) async {
    if (!ConnectivityService.instancia.hayConexion) return;

    final resultado = await _supabase.rpc('perfiles_cercanos', params: {
      'lat': lat,
      'lon': lon,
      'radio_metros': radioMetros,
    });

    final filas = (resultado as List).map((fila) {
      return UsuariosCompanion.insert(
        uuid: fila['id'],
        nombre: fila['nombre'],
        edad: _calcularEdad(fila['fecha_nacimiento']),
        genero: fila['genero'],
        buscaGenero: fila['busca_genero'],
        biografia: Value(fila['biografia'] ?? ''),
        verificadoStatus: Value(fila['verificado_status'] ?? false),
        scorePopularidad: Value(fila['score_popularidad'] ?? 0),
        esPerfilPropio: const Value(false),
        pendienteDeSincronizar: const Value(false),
      );
    }).toList();

    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.usuarios, filas);
    });
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

  // ------------------------------------------------------------
  // Moderación
  // ------------------------------------------------------------
  Future<void> _sincronizarReportesPendientes() async {
    final pendientes = await (_db.select(_db.reportes)
          ..where((r) => r.pendienteDeSincronizar.equals(true)))
        .get();

    for (final reporte in pendientes) {
      try {
        await _supabase.from('reports').upsert({
          'id': reporte.uuid,
          'reportante_id': reporte.reportanteId,
          'reportado_id': reporte.reportadoId,
          'motivo': reporte.motivo,
          'detalle': reporte.detalle,
          'timestamp': reporte.timestamp.toIso8601String(),
        });

        await (_db.update(_db.reportes)
              ..where((r) => r.uuid.equals(reporte.uuid)))
            .write(const ReportesCompanion(pendienteDeSincronizar: Value(false)));
      } catch (_) {
        // reintenta luego
      }
    }
  }

  Future<void> _sincronizarBloqueosPendientes() async {
    final pendientes = await (_db.select(_db.bloqueos)
          ..where((b) => b.pendienteDeSincronizar.equals(true)))
        .get();

    for (final bloqueo in pendientes) {
      try {
        await _supabase.from('blocks').upsert({
          'id': bloqueo.uuid,
          'bloqueador_id': bloqueo.bloqueadorId,
          'bloqueado_id': bloqueo.bloqueadoId,
          'timestamp': bloqueo.timestamp.toIso8601String(),
        });

        await (_db.update(_db.bloqueos)
              ..where((b) => b.uuid.equals(bloqueo.uuid)))
            .write(const BloqueosCompanion(pendienteDeSincronizar: Value(false)));
      } catch (_) {
        // reintenta luego
      }
    }
  }
}
