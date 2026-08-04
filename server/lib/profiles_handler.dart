import 'dart:convert';
import 'json_utils.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'auth_helper.dart';
import 'database.dart';

class ProfilesHandler {
  final DatabaseManager db;
  ProfilesHandler(this.db);

  Future<Response> list(Request req) async {
    final user = await authenticate(db, req);
    if (user == null) return unauthorized();
    final profiles = await db.query('''
      select p.*, u.email
      from flumi.profiles p
      join flumi.users u on u.id = p.id
      where p.id != @currentUserId
      order by p.score_popularidad desc
    ''', parameters: {'currentUserId': user['id']});
    return Response.ok(encodeJson(profiles), headers: {'content-type': 'application/json'});
  }

  Future<Response> get(Request req, String id) async {
    final authUser = await authenticate(db, req);
    if (authUser == null) return unauthorized();
    final profile = await db.queryRow('''
      select p.*, u.email
      from flumi.profiles p
      join flumi.users u on u.id = p.id
      where p.id = @id
    ''', parameters: {'id': id});
    if (profile == null) {
      return Response.notFound(encodeJson({'error': 'Perfil no encontrado'}), headers: {'content-type': 'application/json'});
    }
    return Response.ok(encodeJson(profile), headers: {'content-type': 'application/json'});
  }

  Future<Response> update(Request req, String id) async {
    final currentUser = await authenticate(db, req);
    if (currentUser == null) return unauthorized();
    if (currentUser['id'] != id) {
      return Response(403, body: encodeJson({'error': 'No puedes editar otro perfil'}), headers: {'content-type': 'application/json'});
    }

    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

      final updates = <String, dynamic>{};
      for (final key in ['nombre', 'biografia', 'genero', 'busca_genero']) {
        if (body.containsKey(key)) {
          updates[key] = body[key];
        }
      }
      if (body.containsKey('fecha_nacimiento')) {
        updates['fecha_nacimiento'] = body['fecha_nacimiento'];
      }
      if (body.containsKey('preferencia_edad_min')) {
        updates['preferencia_edad_min'] = body['preferencia_edad_min'];
      }
      if (body.containsKey('preferencia_edad_max')) {
        updates['preferencia_edad_max'] = body['preferencia_edad_max'];
      }
      if (body.containsKey('ubicacion_lat')) {
        updates['ubicacion_lat'] = body['ubicacion_lat'];
      }
      if (body.containsKey('ubicacion_lon')) {
        updates['ubicacion_lon'] = body['ubicacion_lon'];
      }

      if (updates.isNotEmpty) {
        final setClauses = updates.keys.map((k) => '$k = @$k').join(', ');
        updates['id'] = id;
        await db.connection.execute(
          Sql.named('update flumi.profiles set $setClauses where id = @id'),
          parameters: updates,
        );
      }

      if (body.containsKey('nombre')) {
        await db.connection.execute(
          Sql.named('update flumi.users set nombre = @nombre where id = @id'),
          parameters: {'nombre': body['nombre'], 'id': id},
        );
      }

      final profile = await db.queryRow('''
        select p.*, u.email
        from flumi.profiles p
        join flumi.users u on u.id = p.id
        where p.id = @id
      ''', parameters: {'id': id});

      return Response.ok(encodeJson(profile), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: encodeJson({'error': e.toString()}), headers: {'content-type': 'application/json'});
    }
  }
}
