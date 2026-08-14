import 'dart:convert';
import 'json_utils.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'auth_helper.dart';
import 'database.dart';

class SuscripcionesHandler {
  final DatabaseManager db;
  SuscripcionesHandler(this.db);

  Future<Response> get(Request req) async {
    final user = await authenticate(db, req);
    if (user == null) return unauthorized();
    final row = await db.queryRow(
      'select * from flumi.suscripciones where usuario_id = @userId',
      parameters: {'userId': user['id']},
    );
    if (row == null) {
      return Response.notFound(encodeJson({'error': 'Sin suscripción'}),
          headers: {'content-type': 'application/json'});
    }
    return Response.ok(encodeJson(row), headers: {'content-type': 'application/json'});
  }

  Future<Response> upsert(Request req) async {
    final user = await authenticate(db, req);
    if (user == null) return unauthorized();
    final userId = user['id'] as String;
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final plan = body['plan'] as String? ?? 'gratis';
      final inicio =
          DateTime.tryParse(body['inicio'] as String? ?? '') ?? DateTime.now();
      final venceRaw = body['vence'];
      final vence = venceRaw == null ? null : DateTime.tryParse(venceRaw as String);
      final activa = body['activa'] == true || body['activa'] == 'true';
      await db.connection.execute(
        Sql.named('''
          insert into flumi.suscripciones (usuario_id, plan, inicio, vence, activa)
          values (@uid, @plan, @inicio, @vence, @activa)
          on conflict (usuario_id) do update set
            plan = excluded.plan,
            inicio = excluded.inicio,
            vence = excluded.vence,
            activa = excluded.activa
        '''),
        parameters: {
          'uid': userId,
          'plan': plan,
          'inicio': inicio,
          'vence': vence,
          'activa': activa,
        },
      );
      final row = await db.queryRow(
        'select * from flumi.suscripciones where usuario_id = @userId',
        parameters: {'userId': userId},
      );
      return Response.ok(encodeJson(row), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(
          body: encodeJson({'error': e.toString()}),
          headers: {'content-type': 'application/json'});
    }
  }

  Future<Response> getUsages(Request req) async {
    final user = await authenticate(db, req);
    if (user == null) return unauthorized();
    final fecha = req.url.queryParameters['fecha'] ??
        DateTime.now().toIso8601String().substring(0, 10);
    final row = await db.queryRow(
      'select * from flumi.usos_diarios where usuario_id = @userId and fecha = @fecha',
      parameters: {'userId': user['id'], 'fecha': fecha},
    );
    if (row == null) {
      return Response.notFound(encodeJson({'error': 'Sin usos'}),
          headers: {'content-type': 'application/json'});
    }
    return Response.ok(encodeJson(row), headers: {'content-type': 'application/json'});
  }

  Future<Response> upsertUsages(Request req) async {
    final user = await authenticate(db, req);
    if (user == null) return unauthorized();
    final userId = user['id'] as String;
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final fecha = body['fecha'] as String? ??
          DateTime.now().toIso8601String().substring(0, 10);
      final params = {
        'uid': userId,
        'fecha': fecha,
        'me_gustas': _aInt(body['me_gustas_usados']),
        'deshacer': _aInt(body['deshacer_usados']),
        'superlikes': _aInt(body['superlikes_usados']),
        'boosts': _aInt(body['boosts_usados']),
        'cerca': _aInt(body['vistas_cerca_usadas']),
      };
      await db.connection.execute(
        Sql.named('''
          insert into flumi.usos_diarios
            (usuario_id, fecha, me_gustas_usados, deshacer_usados, superlikes_usados, boosts_usados, vistas_cerca_usadas)
          values (@uid, @fecha, @me_gustas, @deshacer, @superlikes, @boosts, @cerca)
          on conflict (usuario_id, fecha) do update set
            me_gustas_usados = excluded.me_gustas_usados,
            deshacer_usados = excluded.deshacer_usados,
            superlikes_usados = excluded.superlikes_usados,
            boosts_usados = excluded.boosts_usados,
            vistas_cerca_usadas = excluded.vistas_cerca_usadas
        '''),
        parameters: params,
      );
      final row = await db.queryRow(
        'select * from flumi.usos_diarios where usuario_id = @userId and fecha = @fecha',
        parameters: {'userId': userId, 'fecha': fecha},
      );
      return Response.ok(encodeJson(row), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(
          body: encodeJson({'error': e.toString()}),
          headers: {'content-type': 'application/json'});
    }
  }
}

int _aInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);
