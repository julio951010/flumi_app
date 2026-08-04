import 'dart:convert';
import 'json_utils.dart';
import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'database.dart';

const _secret = 'flumi-dev-secret-key';

String hashPassword(String password) {
  return sha256.convert(utf8.encode(password)).toString();
}

String generateToken(String userId) {
  final payload = utf8.encode(encodeJson({
    'sub': userId,
    'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    'exp': DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch ~/ 1000,
  }));
  final header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
  final body = base64Url.encode(payload);
  final signature = base64Url.encode(sha256.convert(utf8.encode('$header.$body.$_secret')).bytes);
  return '$header.$body.$signature';
}

String _extractUserId(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return '';
    final body = utf8.decode(base64Url.decode(parts[1]));
    final payload = jsonDecode(body) as Map<String, dynamic>;
    return payload['sub'] as String? ?? '';
  } catch (_) {
    return '';
  }
}

bool _verifyToken(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return false;
    final header = parts[0];
    final body = parts[1];
    final sig = base64Url.encode(sha256.convert(utf8.encode('$header.$body.$_secret')).bytes);
    return sig == parts[2];
  } catch (_) {
    return false;
  }
}

Response unauthorized() {
  return Response.unauthorized(
    encodeJson({'error': 'Token inválido'}),
    headers: {'content-type': 'application/json'},
  );
}

Future<Map<String, dynamic>?> authenticate(DatabaseManager db, Request req) async {
  final auth = req.headers['authorization'] ?? '';
  final token = auth.startsWith('Bearer ') ? auth.substring(7) : '';
  if (!_verifyToken(token)) return null;
  final userId = _extractUserId(token);
  if (userId.isEmpty) return null;
  return await db.queryRow(
    'select id, email, nombre from flumi.users where id = @id',
    parameters: {'id': userId},
  );
}
