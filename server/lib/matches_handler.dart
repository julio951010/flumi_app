import 'dart:convert';
import 'json_utils.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';
import 'auth_helper.dart';
import 'database.dart';

final _uuid = const Uuid();

class MatchesHandler {
  final DatabaseManager db;
  MatchesHandler(this.db);

  Future<Response> list(Request req) async {
    final user = await authenticate(db, req);
    if (user == null) return unauthorized();
    final userId = user['id'];

    final matches = await db.query('''
      select * from flumi.matches
      where usuario_a_id = @userId or usuario_b_id = @userId
      order by timestamp_match desc
    ''', parameters: {'userId': userId});

    return Response.ok(encodeJson(matches), headers: {'content-type': 'application/json'});
  }

  Future<Response> create(Request req) async {
    final user = await authenticate(db, req);
    if (user == null) return unauthorized();
    final userId = user['id'] as String;

    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final otroId = body['usuario_b_id'] as String;

      if (otroId == userId) {
        return Response(400, body: encodeJson({'error': 'No puedes hacer match contigo mismo'}), headers: {'content-type': 'application/json'});
      }

      final id = _uuid.v4();
      await db.connection.execute(
        Sql.named('''
          insert into flumi.matches (id, usuario_a_id, usuario_b_id, timestamp_match)
          values (@id, @a, @b, now())
        '''),
        parameters: {'id': id, 'a': userId, 'b': otroId},
      );

      return Response.ok(encodeJson({'id': id, 'ok': true}), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: encodeJson({'error': e.toString()}), headers: {'content-type': 'application/json'});
    }
  }
}
