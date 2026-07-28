import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/servicios/connectivity_service.dart';

class SinConexionException implements Exception {
  @override
  String toString() => 'No hay conexión a internet. Verifica tu conexión e intenta de nuevo.';
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
    return _auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> registrar({
    required String email,
    required String password,
    String? nombre,
  }) async {
    _requerirConexion();
    return _auth.signUp(
      email: email,
      password: password,
      data: nombre != null ? {'nombre': nombre} : null,
    );
  }

  Future<void> cerrarSesion() {
    return _auth.signOut();
  }

  Future<void> restablecerContrasena(String email) async {
    _requerirConexion();
    return _auth.resetPasswordForEmail(email);
  }

  Future<void> actualizarPassword(String nuevaPassword) {
    return _auth.updateUser(UserAttributes(password: nuevaPassword));
  }

  void _requerirConexion() {
    if (!ConnectivityService.instancia.hayConexion) {
      throw SinConexionException();
    }
  }
}
