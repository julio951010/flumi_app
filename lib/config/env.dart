import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

bool get kUsarServidorLocal => false;
bool get kUsarModoMock => true;
bool get kEsPremium => false;

String get kServidorLocalUrl {
  if (Platform.isAndroid) return 'http://10.0.2.2:8081';
  return 'http://localhost:8081';
}

class LocalTokenStore {
  static const _tokenKey = 'local_auth_token';
  static const _userIdKey = 'local_user_id';
  static const _userEmailKey = 'local_user_email';
  static const _userNombreKey = 'local_user_nombre';

  static Future<void> guardarToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> obtenerToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> guardarUsuario(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, user['id'] ?? '');
    await prefs.setString(_userEmailKey, user['email'] ?? '');
    await prefs.setString(_userNombreKey, user['nombre'] ?? '');
  }

  static Future<Map<String, dynamic>?> obtenerUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_userIdKey);
    if (id == null || id.isEmpty) return null;
    return {
      'id': id,
      'email': prefs.getString(_userEmailKey) ?? '',
      'nombre': prefs.getString(_userNombreKey) ?? '',
    };
  }

  static Future<void> limpiar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userNombreKey);
  }
}
