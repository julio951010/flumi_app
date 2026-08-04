import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../config/env.dart';
import '../base_datos_local/database.dart';
import 'connectivity_service.dart';

class SyncService {
  SyncService(this._db);

  final AppDatabase _db;

  bool _sincronizando = false;

  String? get _token => null;

  Future<void> sincronizarTodo() async {
    if (kUsarModoMock) return;
    if (_sincronizando) return;
    if (!ConnectivityService.instancia.hayConexion) return;

    _sincronizando = true;
    try {
      await _sincronizarPerfilPropio();
      await _sincronizarMensajesPendientes();
      await _sincronizarMatchesPendientes();
      await _sincronizarReportesPendientes();
      await _sincronizarBloqueosPendientes();
    } finally {
      _sincronizando = false;
    }
  }

  // ------------------------------------------------------------
  // Perfil propio
  // ------------------------------------------------------------
  Future<void> _sincronizarPerfilPropio() async {
    final userId = _obtenerUserId();
    if (userId == null) return;

    final local = await (_db.select(_db.usuarios)
          ..where((u) => u.esPerfilPropio.equals(true)))
        .getSingleOrNull();

    // Descargar si no existe localmente
    if (local == null) {
      final remoto = await _fetchPerfil(userId);
      if (remoto == null) return;
      await _guardarPerfilLocal(remoto, true);
      return;
    }

    // Subir cambios pendientes
    final pendientes = await (_db.select(_db.usuarios)
          ..where((u) =>
              u.esPerfilPropio.equals(true) &
              u.pendienteDeSincronizar.equals(true)))
        .getSingleOrNull();

    if (pendientes == null) return;

    try {
      await _subirPerfil(pendientes);
      await (_db.update(_db.usuarios)
            ..where((u) => u.uuid.equals(pendientes.uuid)))
          .write(UsuariosCompanion(
        pendienteDeSincronizar: const Value(false),
        ultimaSincronizacionTimestamp: Value(DateTime.now()),
      ));
    } catch (_) {}
  }

  // ------------------------------------------------------------
  // Mensajes
  // ------------------------------------------------------------
  Future<void> _sincronizarMensajesPendientes() async {
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
  Future<void> _sincronizarMatchesPendientes() async {
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
  Future<void> _sincronizarReportesPendientes() async {
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
  Future<void> _sincronizarBloqueosPendientes() async {
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
  // Helpers de red
  // ------------------------------------------------------------
  String? _obtenerUserId() {
    if (kUsarServidorLocal) {
      // En modo local no necesitamos userId para subir datos
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
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
      return null;
    }

    final remoto = await sb.Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return remoto as Map<String, dynamic>?;
  }

  Future<void> _guardarPerfilLocal(Map<String, dynamic> perfil, bool esPropio) async {
    final fechaNac = perfil['fecha_nacimiento'] as String?;
    final creadoEn = perfil['creado_en'] != null
        ? DateTime.parse(perfil['creado_en'] as String)
        : DateTime.now();
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
        esPerfilPropio: Value(esPropio),
        pendienteDeSincronizar: const Value(false),
        creadoEn: Value(creadoEn),
      ),
    );
  }

  Future<void> _subirPerfil(Usuario perfil) async {
    final body = {
      'nombre': perfil.nombre,
      'biografia': perfil.biografia,
      'genero': perfil.genero,
      'busca_genero': perfil.buscaGenero,
      'preferencia_edad_min': perfil.preferenciaEdadMin,
      'preferencia_edad_max': perfil.preferenciaEdadMax,
      'ubicacion_lat': perfil.ubicacionLat,
      'ubicacion_lon': perfil.ubicacionLon,
    };

    if (kUsarServidorLocal) {
      final token = await LocalTokenStore.obtenerToken();
      if (token == null) return;
      await http.put(
        Uri.parse('$kServidorLocalUrl/api/profiles/${perfil.uuid}'),
        headers: {'content-type': 'application/json', 'authorization': 'Bearer $token'},
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
        headers: {'content-type': 'application/json', 'authorization': 'Bearer $token'},
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
        headers: {'content-type': 'application/json', 'authorization': 'Bearer $token'},
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
        headers: {'content-type': 'application/json', 'authorization': 'Bearer $token'},
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
        headers: {'content-type': 'application/json', 'authorization': 'Bearer $token'},
        body: jsonEncode(body),
      );
      return;
    }

    await sb.Supabase.instance.client.from('blocks').upsert(body);
  }

  // ------------------------------------------------------------
  // Feed de cercanía (opcional en local)
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
      final filas = lista.map((fila) {
        final f = fila as Map<String, dynamic>;
        final fechaNac = f['fecha_nacimiento'] as String?;
        return UsuariosCompanion.insert(
          uuid: f['id'],
          nombre: f['nombre'] ?? '',
          edad: fechaNac != null ? _calcularEdad(fechaNac) : 18,
          genero: f['genero'] ?? 'otro',
          buscaGenero: f['busca_genero'] ?? 'otro',
          biografia: Value(f['biografia'] ?? ''),
          verificadoStatus: Value(f['verificado_status'] ?? false),
          scorePopularidad: Value(f['score_popularidad'] ?? 0),
          esPerfilPropio: const Value(false),
          pendienteDeSincronizar: const Value(false),
        );
      }).toList();
      if (filas.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAllOnConflictUpdate(_db.usuarios, filas);
        });
      }
      return;
    }

    final resultado = await sb.Supabase.instance.client.rpc('perfiles_cercanos', params: {
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
}
