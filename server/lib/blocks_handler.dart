import 'dart:convert';
import 'json_utils.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';
import 'auth_helper.dart';
import 'database.dart';

final _uuid = const Uuid();

class BlocksHandler {
  final DatabaseManager db;
  BlocksHandler(this.db);

  Future<Response> list(Request req) async {
    final user = await authenticate(db, req);
    if (user == null) return unauthorized();
    final userId = user['id'];
    final blocks = await db.query(
      'select * from flumi.blocks where bloqueador_id = @userId order by timestamp desc',
      parameters: {'userId': userId},
    );
    return Response.ok(encodeJson(blocks), headers: {'content-type': 'application/json'});
  }

  Future<Response> create(Request req) async {
    final user = await authenticate(db, req);
    if (user == null) return unauthorized();
    final userId = user['id'] as String;

    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final bloqueadoId = body['bloqueado_id'] as String;

      if (bloqueadoId == userId) {
        return Response(400, body: encodeJson({'error': 'No puedes bloquearte a ti mismo'}), headers: {'content-type': 'application/json'});
      }

      final id = _uuid.v4();
      await db.connection.execute(
        Sql.named('''
          insert into flumi.blocks (id, bloqueador_id, bloqueado_id)
          values (@id, @bloqueador, @bloqueado)
        '''),
        parameters: {'id': id, 'bloqueador': userId, 'bloqueado': bloqueadoId},
      );
      return Response.ok(encodeJson({'id': id, 'ok': true}), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: encodeJson({'error': e.toString()}), headers: {'content-type': 'application/json'});
    }
  }

  Future<Response> remove(Request req, String id) async {
    final user = await authenticate(db, req);
    if (user == null) return unauthorized();
    await db.connection.execute(
      Sql.named('delete from flumi.blocks where id = @id and bloqueador_id = @userId'),
      parameters: {'id': id, 'userId': user['id']},
    );
    return Response.ok(encodeJson({'ok': true}), headers: {'content-type': 'application/json'});
  }
}
