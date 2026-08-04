import 'dart:convert';
import 'json_utils.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';
import 'auth_helper.dart';
import 'database.dart';

final _uuid = const Uuid();

class ReportsHandler {
  final DatabaseManager db;
  ReportsHandler(this.db);

  Future<Response> list(Request req) async {
    final user = await authenticate(db, req);
    if (user == null) return unauthorized();
    final userId = user['id'];
    final reports = await db.query(
      'select * from flumi.reports where reportante_id = @userId order by timestamp desc',
      parameters: {'userId': userId},
    );
    return Response.ok(encodeJson(reports), headers: {'content-type': 'application/json'});
  }

  Future<Response> create(Request req) async {
    final user = await authenticate(db, req);
    if (user == null) return unauthorized();
    final userId = user['id'] as String;

    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final id = _uuid.v4();
      await db.connection.execute(
        Sql.named('''
          insert into flumi.reports (id, reportante_id, reportado_id, motivo, detalle)
          values (@id, @reportante, @reportado, @motivo, @detalle)
        '''),
        parameters: {
          'id': id,
          'reportante': userId,
          'reportado': body['reportado_id'],
          'motivo': body['motivo'],
          'detalle': body['detalle'] ?? '',
        },
      );
      return Response.ok(encodeJson({'id': id, 'ok': true}), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: encodeJson({'error': e.toString()}), headers: {'content-type': 'application/json'});
    }
  }
}
