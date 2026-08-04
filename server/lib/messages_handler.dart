import 'dart:convert';
import 'json_utils.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';
import 'auth_helper.dart';
import 'database.dart';

final _uuid = const Uuid();

class MessagesHandler {
  final DatabaseManager db;
  MessagesHandler(this.db);

  Future<Response> list(Request req) async {
    final user = await authenticate(db, req);
    if (user == null) return unauthorized();
    final userId = user['id'];

    final messages = await db.query('''
      select * from flumi.messages
      where emisor_id = @userId or receptor_id = @userId
      order by timestamp asc
    ''', parameters: {'userId': userId});

    return Response.ok(encodeJson(messages), headers: {'content-type': 'application/json'});
  }

  Future<Response> create(Request req) async {
    final user = await authenticate(db, req);
    if (user == null) return unauthorized();
    final userId = user['id'] as String;

    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final receptorId = body['receptor_id'] as String;
      final contenido = body['contenido'] as String;

      if (receptorId == userId) {
        return Response(400, body: encodeJson({'error': 'No puedes enviarte mensajes a ti mismo'}), headers: {'content-type': 'application/json'});
      }

      final id = _uuid.v4();
      await db.connection.execute(
        Sql.named('''
          insert into flumi.messages (id, emisor_id, receptor_id, contenido, timestamp, estado_envio)
          values (@id, @emisor, @receptor, @contenido, now(), 'enviado')
        '''),
        parameters: {
          'id': id,
          'emisor': userId,
          'receptor': receptorId,
          'contenido': contenido,
        },
      );

      final msg = await db.queryRow('select * from flumi.messages where id = @id', parameters: {'id': id});
      return Response.ok(encodeJson(msg), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: encodeJson({'error': e.toString()}), headers: {'content-type': 'application/json'});
    }
  }

  Future<Response> markRead(Request req, String id) async {
    final user = await authenticate(db, req);
    if (user == null) return unauthorized();
    await db.connection.execute(
      Sql.named("update flumi.messages set estado_envio = 'leido' where id = @id and receptor_id = @userId"),
      parameters: {'id': id, 'userId': user['id']},
    );
    return Response.ok(encodeJson({'ok': true}), headers: {'content-type': 'application/json'});
  }
}
