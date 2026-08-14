import 'dart:convert';
import 'json_utils.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';
import 'auth_helper.dart';
import 'database.dart';

final _uuid = const Uuid();

class LikesHandler {
  final DatabaseManager db;
  LikesHandler(this.db);

  Future<Response> list(Request req) async {
    final user = await authenticate(db, req);
    if (user == null) return unauthorized();
    final rows = await db.query(
      'select * from flumi.historial_likes where usuario_id = @userId order by timestamp desc',
      parameters: {'userId': user['id']},
    );
    return Response.ok(encodeJson(rows), headers: {'content-type': 'application/json'});
  }

  Future<Response> create(Request req) async {
    final user = await authenticate(db, req);
    if (user == null) return unauthorized();
    final userId = user['id'] as String;
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final likeadoId = body['usuario_likeado_id'] as String;
      if (likeadoId == userId) {
        return Response(400,
            body: encodeJson({'error': 'No puedes darte like a ti mismo'}),
            headers: {'content-type': 'application/json'});
      }
      final id = (body['id'] as String?) ?? _uuid.v4();
      final ts = DateTime.tryParse(body['timestamp'] as String? ?? '') ??
          DateTime.now();
      await db.connection.execute(
        Sql.named('''
          insert into flumi.historial_likes (id, usuario_id, usuario_likeado_id, timestamp)
          values (@id, @uid, @likeado, @ts)
        '''),
        parameters: {'id': id, 'uid': userId, 'likeado': likeadoId, 'ts': ts},
      );
      final row = await db.queryRow(
          'select * from flumi.historial_likes where id = @id',
          parameters: {'id': id});
      return Response.ok(encodeJson(row), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(
          body: encodeJson({'error': e.toString()}),
          headers: {'content-type': 'application/json'});
    }
  }
}
