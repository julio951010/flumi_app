import 'dart:convert';
import 'json_utils.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';
import 'auth_helper.dart';
import 'database.dart';

final _uuid = const Uuid();

class VisitasHandler {
  final DatabaseManager db;
  VisitasHandler(this.db);

  Future<Response> list(Request req) async {
    final user = await authenticate(db, req);
    if (user == null) return unauthorized();
    final userId = user['id'];
    final recibidas = req.url.queryParameters['recibidas'] == '1';
    final where = recibidas
        ? 'visitado_id = @userId'
        : '(visitante_id = @userId or visitado_id = @userId)';
    final rows = await db.query(
      'select * from flumi.visitas where $where order by timestamp desc',
      parameters: {'userId': userId},
    );
    return Response.ok(encodeJson(rows), headers: {'content-type': 'application/json'});
  }

  Future<Response> create(Request req) async {
    final user = await authenticate(db, req);
    if (user == null) return unauthorized();
    final userId = user['id'] as String;
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final visitadoId = body['visitado_id'] as String;
      if (visitadoId == userId) {
        return Response(400,
            body: encodeJson({'error': 'No puedes visitarte a ti mismo'}),
            headers: {'content-type': 'application/json'});
      }
      final id = (body['id'] as String?) ?? _uuid.v4();
      final ts = DateTime.tryParse(body['timestamp'] as String? ?? '') ??
          DateTime.now();
      await db.connection.execute(
        Sql.named('''
          insert into flumi.visitas (id, visitante_id, visitado_id, timestamp)
          values (@id, @visitante, @visitado, @ts)
        '''),
        parameters: {
          'id': id,
          'visitante': userId,
          'visitado': visitadoId,
          'ts': ts,
        },
      );
      final row = await db.queryRow('select * from flumi.visitas where id = @id',
          parameters: {'id': id});
      return Response.ok(encodeJson(row), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(
          body: encodeJson({'error': e.toString()}),
          headers: {'content-type': 'application/json'});
    }
  }
}
