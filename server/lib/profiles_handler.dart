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

      final texto = {
        'nombre', 'biografia', 'genero', 'busca_genero', 'que_busca', 'ciudad',
        'orientacion_sexual', 'situacion_sentimental', 'altura', 'educacion',
        'trabajo', 'profesion', 'preferencia_relacion', 'bebe', 'fuma', 'hijos',
        'personalidad', 'signo_zodiaco', 'mascotas', 'religion', 'idiomas',
        'tatuajes', 'foto_verificacion',
      };
      final entero = {'edad', 'preferencia_edad_min', 'preferencia_edad_max', 'score_popularidad'};
      final booleano = {'ocultar_en_linea', 'ocultar_edad', 'perfil_completado', 'verificado_status'};
      final decimal = {'ubicacion_lat', 'ubicacion_lon'};
      final fecha = {'fecha_nacimiento', 'ultima_conexion'};

      final updates = <String, dynamic>{};
      for (final key in body.keys) {
        if (!body.containsKey(key) || body[key] == null) continue;
        if (texto.contains(key)) {
          updates[key] = body[key].toString();
        } else if (entero.contains(key)) {
          updates[key] = _aInt(body[key]);
        } else if (booleano.contains(key)) {
          updates[key] = body[key] == true || body[key] == 'true';
        } else if (decimal.contains(key)) {
          updates[key] = _aDouble(body[key]);
        } else if (fecha.contains(key)) {
          final dt = DateTime.tryParse(body[key].toString());
          if (dt != null) updates[key] = dt;
        } else if (key == 'intereses') {
          updates[key] = (body[key] as List).map((e) => e.toString()).toList();
        } else if (key == 'preguntas_perfil') {
          updates[key] = jsonEncode(body[key]);
        }
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
          parameters: {'nombre': body['nombre'].toString(), 'id': id},
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

int _aInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);

double _aDouble(dynamic v) =>
    v is double ? v : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);
