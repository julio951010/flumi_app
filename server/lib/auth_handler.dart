import 'dart:convert';
import 'json_utils.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';
import 'auth_helper.dart';
import 'database.dart';

final _uuid = const Uuid();

class AuthHandler {
  final DatabaseManager db;
  AuthHandler(this.db);

  Future<Response> signup(Request req) async {
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final email = body['email'] as String?;
      final password = body['password'] as String?;
      final nombre = body['nombre'] as String? ?? email?.split('@').first ?? '';

      if (email == null || password == null) {
        return Response.badRequest(body: encodeJson({'error': 'Email y password requeridos'}), headers: {'content-type': 'application/json'});
      }
      if (password.length < 6) {
        return Response.badRequest(body: encodeJson({'error': 'Password debe tener al menos 6 caracteres'}), headers: {'content-type': 'application/json'});
      }

      final existing = await db.queryRow('select id from flumi.users where email = @email', parameters: {'email': email});
      if (existing != null) {
        return Response(409, body: encodeJson({'error': 'Email ya registrado'}), headers: {'content-type': 'application/json'});
      }

      final id = _uuid.v4();
      await db.connection.execute(
        Sql.named('insert into flumi.users (id, email, password_hash, nombre) values (@id, @email, @hash, @nombre)'),
        parameters: {'id': id, 'email': email, 'hash': hashPassword(password), 'nombre': nombre},
      );
      await db.connection.execute(
        Sql.named('insert into flumi.profiles (id, nombre) values (@id, @nombre)'),
        parameters: {'id': id, 'nombre': nombre},
      );

      final token = generateToken(id);
      return Response.ok(encodeJson({
        'user': {'id': id, 'email': email, 'nombre': nombre},
        'token': token,
      }), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: encodeJson({'error': e.toString()}), headers: {'content-type': 'application/json'});
    }
  }

  Future<Response> login(Request req) async {
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final email = body['email'] as String?;
      final password = body['password'] as String?;

      if (email == null || password == null) {
        return Response.badRequest(body: encodeJson({'error': 'Email y password requeridos'}), headers: {'content-type': 'application/json'});
      }

      final user = await db.queryRow(
        'select id, email, nombre, password_hash from flumi.users where email = @email',
        parameters: {'email': email},
      );
      if (user == null || user['password_hash'] != hashPassword(password)) {
        return Response(401, body: encodeJson({'error': 'Credenciales inválidas'}), headers: {'content-type': 'application/json'});
      }

      final token = generateToken(user['id'] as String);
      return Response.ok(encodeJson({
        'user': {'id': user['id'], 'email': user['email'], 'nombre': user['nombre']},
        'token': token,
      }), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: encodeJson({'error': e.toString()}), headers: {'content-type': 'application/json'});
    }
  }

  Future<Response> logout(Request req) async {
    return Response.ok(encodeJson({'ok': true}), headers: {'content-type': 'application/json'});
  }

  Future<Response> getUser(Request req) async {
    final user = await authenticate(db, req);
    if (user == null) return unauthorized();
    return Response.ok(encodeJson({'user': user}), headers: {'content-type': 'application/json'});
  }

  Future<Response> recover(Request req) async {
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final email = body['email'] as String?;
      if (email == null) {
        return Response.badRequest(body: encodeJson({'error': 'Email requerido'}), headers: {'content-type': 'application/json'});
      }
      final user = await db.queryRow('select id from flumi.users where email = @email', parameters: {'email': email});
      if (user == null) {
        return Response.ok(encodeJson({'error': 'no user found'}), headers: {'content-type': 'application/json'});
      }
      final token = _uuid.v4();
      await db.connection.execute(
        Sql.named("update flumi.users set recovery_token = @token, recovery_token_expires_at = now() + interval '1 hour' where id = @id"),
        parameters: {'token': token, 'id': user['id']},
      );
      print('Recovery token for $email: $token');
      return Response.ok(encodeJson({'ok': true, 'recovery_token': token}), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: encodeJson({'error': e.toString()}), headers: {'content-type': 'application/json'});
    }
  }

  Future<Response> resetPassword(Request req, String token) async {
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final password = body['password'] as String?;
      if (password == null) {
        return Response.badRequest(body: encodeJson({'error': 'Password requerido'}), headers: {'content-type': 'application/json'});
      }
      final user = await db.queryRow(
        'select id from flumi.users where recovery_token = @token and recovery_token_expires_at > now()',
        parameters: {'token': token},
      );
      if (user == null) {
        return Response(400, body: encodeJson({'error': 'Token inválido o expirado'}), headers: {'content-type': 'application/json'});
      }
      await db.connection.execute(
        Sql.named('update flumi.users set password_hash = @hash, recovery_token = null, recovery_token_expires_at = null where id = @id'),
        parameters: {'hash': hashPassword(password), 'id': user['id']},
      );
      return Response.ok(encodeJson({'ok': true}), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: encodeJson({'error': e.toString()}), headers: {'content-type': 'application/json'});
    }
  }

  Future<Response> updatePassword(Request req) async {
    final user = await authenticate(db, req);
    if (user == null) return unauthorized();
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final password = body['password'] as String?;
      if (password == null) {
        return Response.badRequest(body: encodeJson({'error': 'Password requerido'}), headers: {'content-type': 'application/json'});
      }
      await db.connection.execute(
        Sql.named('update flumi.users set password_hash = @hash where id = @id'),
        parameters: {'hash': hashPassword(password), 'id': user['id']},
      );
      return Response.ok(encodeJson({'ok': true}), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: encodeJson({'error': e.toString()}), headers: {'content-type': 'application/json'});
    }
  }
}
