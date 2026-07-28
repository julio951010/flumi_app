import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/servicios/connectivity_service.dart';

class SinConexionException implements Exception {
  @override
  String toString() => 'No hay conexión a internet. Verifica tu conexión e intenta de nuevo.';
}

class ErrorServidorException implements Exception {
  @override
  String toString() => 'No se pudo conectar con el servidor. Intenta de nuevo más tarde.';
}

class CredencialesInvalidasException implements Exception {
  @override
  String toString() => 'Credenciales inválidas. Verifica tus datos e intenta de nuevo.';
}

class AuthService {
  final GoTrueClient _auth;

  AuthService() : _auth = Supabase.instance.client.auth;

  User? get usuarioActual => _auth.currentUser;
  bool get estaAutenticado => _auth.currentSession != null;

  Stream<AuthState> get estadoStream => _auth.onAuthStateChange;

  Future<AuthResponse> iniciarSesion({
    required String email,
    required String password,
  }) async {
    _requerirConexion();
    return _ejecutar(() => _auth.signInWithPassword(email: email, password: password));
  }

  Future<AuthResponse> registrar({
    required String email,
    required String password,
    String? nombre,
  }) async {
    _requerirConexion();
    return _ejecutar(() => _auth.signUp(
      email: email,
      password: password,
      data: nombre != null ? {'nombre': nombre} : null,
    ));
  }

  Future<void> cerrarSesion() {
    return _auth.signOut();
  }

  Future<void> restablecerContrasena(String email) async {
    _requerirConexion();
    return _ejecutar(() => _auth.resetPasswordForEmail(email));
  }

  Future<void> actualizarPassword(String nuevaPassword) {
    return _auth.updateUser(UserAttributes(password: nuevaPassword));
  }

  void _requerirConexion() {
    if (!ConnectivityService.instancia.hayConexion) {
      throw SinConexionException();
    }
  }

  Future<T> _ejecutar<T>(Future<T> Function() llamada) async {
    try {
      return await llamada();
    } on SocketException {
      throw ErrorServidorException();
    } on HandshakeException {
      throw ErrorServidorException();
    } on HttpException {
      throw ErrorServidorException();
    } on AuthRetryableFetchException {
      throw ErrorServidorException();
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid login') ||
          msg.contains('invalid credentials') ||
          msg.contains('email not confirmed') ||
          msg.contains('user not found') ||
          msg.contains('wrong password')) {
        throw CredencialesInvalidasException();
      }
      if (msg.contains('user already registered')) {
        throw Exception('El correo ya está registrado. ¿Quieres iniciar sesión?');
      }
      if (msg.contains('invalid format') || msg.contains('validation_failed')) {
        throw Exception('El formato del correo no es válido.');
      }
      rethrow;
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('No address associated') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('Connection timed out')) {
        throw ErrorServidorException();
      }
      rethrow;
    }
  }

  Future<void> enviarOTP({required String email, String? nombre}) async {
    _requerirConexion();
    return _ejecutar(() => _auth.signInWithOtp(
      email: email,
      data: nombre != null ? {'nombre': nombre} : null,
    ));
  }

  Future<AuthResponse> verificarOTP({
    required String email,
    required String token,
  }) async {
    _requerirConexion();
    return _ejecutar(() => _auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    ));
  }

  Future<void> reenviarOTP({required String email}) async {
    _requerirConexion();
    return _ejecutar(() => _auth.signInWithOtp(email: email));
  }
}
