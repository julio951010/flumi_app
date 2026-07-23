import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final GoTrueClient _auth;

  AuthService() : _auth = Supabase.instance.client.auth;

  User? get usuarioActual => _auth.currentUser;
  bool get estaAutenticado => _auth.currentSession != null;

  Stream<AuthState> get estadoStream => _auth.onAuthStateChange;

  Future<AuthResponse> iniciarSesion({
    required String email,
    required String password,
  }) {
    return _auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> registrar({
    required String email,
    required String password,
  }) {
    return _auth.signUp(email: email, password: password);
  }

  Future<void> cerrarSesion() {
    return _auth.signOut();
  }
}
