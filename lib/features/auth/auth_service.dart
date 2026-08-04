import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../config/env.dart';
import '../../core/api/mock_data.dart';
import '../../core/base_datos_local/database.dart';
import '../../core/servicios/connectivity_service.dart';

// ---------------------------------------------------------------
// Excepciones
// ---------------------------------------------------------------
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

class CodigoInvalidoException implements Exception {
  @override
  String toString() => 'Código inválido o expirado. Solicita uno nuevo.';
}

class EmailNoRegistradoException implements Exception {
  @override
  String toString() => 'No hay una cuenta asociada a este correo.';
}

class EmailYaRegistradoException implements Exception {
  @override
  String toString() => 'El correo ya está registrado. ¿Quieres iniciar sesión?';
}

class EmailInvalidoException implements Exception {
  @override
  String toString() => 'El formato del correo no es válido.';
}

class RegistroDeshabilitadoException implements Exception {
  @override
  String toString() => 'El registro no está habilitado en este momento.';
}

class ErrorInesperadoException implements Exception {
  @override
  String toString() => 'Ocurrió un error inesperado. Intenta de nuevo.';
}

// ---------------------------------------------------------------
// AuthState
// ---------------------------------------------------------------
class AuthState {
  final String event;
  final Map<String, dynamic>? user;
  const AuthState(this.event, {this.user});
}

// ---------------------------------------------------------------
// AuthService
// ---------------------------------------------------------------
class AuthService {
  static Map<String, dynamic>? _localUser;
  static String? _localToken;
  static StreamController<AuthState>? _localStreamCtrl;
  static AppDatabase? _db;

  static void initDb(AppDatabase db) => _db = db;
  static AppDatabase get db => _db!;

  // -----------------------------------------------------------
  // Propiedades
  // -----------------------------------------------------------
  Map<String, dynamic>? get usuarioActual {
    if (kUsarModoMock || kUsarServidorLocal) return _localUser;
    return sb.Supabase.instance.client.auth.currentUser?.toJson();
  }

  bool get estaAutenticado {
    if (kUsarModoMock || kUsarServidorLocal) return _localUser != null;
    return sb.Supabase.instance.client.auth.currentSession != null;
  }

  Stream<AuthState> get estadoStream {
    _localStreamCtrl ??= StreamController<AuthState>.broadcast();
    if (kUsarModoMock || kUsarServidorLocal) return _localStreamCtrl!.stream;
    return sb.Supabase.instance.client.auth.onAuthStateChange.map(
      (e) => AuthState(e.event.name, user: e.session?.user.toJson()),
    );
  }

  // -----------------------------------------------------------
  // Inicializar
  // -----------------------------------------------------------
  Future<void> inicializar() async {
    if (kUsarModoMock) {
      await GeneradorMock.sembrarSiVacio(db);
      final user = await LocalTokenStore.obtenerUsuario();
      if (user != null) {
        _localUser = user;
        _localStreamCtrl ??= StreamController<AuthState>.broadcast();
        _localStreamCtrl!.add(AuthState('INITIAL_SESSION', user: user));
      }
      return;
    }
    if (kUsarServidorLocal) {
      final token = await LocalTokenStore.obtenerToken();
      final user = await LocalTokenStore.obtenerUsuario();
      if (token != null && user != null) {
        _localUser = user;
        _localStreamCtrl ??= StreamController<AuthState>.broadcast();
        _localStreamCtrl!.add(AuthState('INITIAL_SESSION', user: user));
      }
    }
  }

  // -----------------------------------------------------------
  // Iniciar sesión
  // -----------------------------------------------------------
  Future<Map<String, dynamic>> iniciarSesion({
    required String email,
    required String password,
  }) async {
    if (kUsarModoMock) return _mockAuth(email);
    _requerirConexion();

    if (kUsarServidorLocal) {
      return _localHttp(() async {
        final res = await http.post(
          Uri.parse('$kServidorLocalUrl/api/auth/login'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          _localUser = data['user'] as Map<String, dynamic>;
          await LocalTokenStore.guardarUsuario(_localUser!);
          _localStreamCtrl ??= StreamController<AuthState>.broadcast();
          _localStreamCtrl!.add(AuthState('SIGNED_IN', user: _localUser));
          return data;
        }
        if (res.statusCode == 401) throw CredencialesInvalidasException();
        throw ErrorServidorException();
      });
    }

    return _ejecutar(() async {
      final r = await sb.Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return {'user': r.user?.toJson(), 'token': ''};
    });
  }

  // -----------------------------------------------------------
  // Registro
  // -----------------------------------------------------------
  Future<Map<String, dynamic>> registrar({
    required String email,
    required String password,
    String? nombre,
  }) async {
    if (kUsarModoMock) return _mockAuth(email, nombre: nombre);
    _requerirConexion();

    if (kUsarServidorLocal) {
      return _localHttp(() async {
        final res = await http.post(
          Uri.parse('$kServidorLocalUrl/api/auth/signup'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password, 'nombre': nombre ?? email.split('@').first}),
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          _localUser = data['user'] as Map<String, dynamic>;
          await LocalTokenStore.guardarUsuario(_localUser!);
          _localStreamCtrl ??= StreamController<AuthState>.broadcast();
          _localStreamCtrl!.add(AuthState('SIGNED_IN', user: _localUser));
          return data;
        }
        if (res.statusCode == 409) throw EmailYaRegistradoException();
        throw ErrorServidorException();
      });
    }

    return _ejecutar(() async {
      final r = await sb.Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: nombre != null ? {'nombre': nombre} : null,
      );
      return {'user': r.user?.toJson(), 'token': ''};
    });
  }

  // -----------------------------------------------------------
  // Cerrar sesión
  // -----------------------------------------------------------
  Future<void> cerrarSesion() async {
    if (kUsarModoMock || kUsarServidorLocal) {
      _localUser = null;
      await LocalTokenStore.limpiar();
      _localStreamCtrl ??= StreamController<AuthState>.broadcast();
      _localStreamCtrl!.add(const AuthState('SIGNED_OUT'));
      return;
    }
    return sb.Supabase.instance.client.auth.signOut();
  }

  void actualizarIdLocal(String id) {
    if (_localUser != null) {
      _localUser!['id'] = id;
    }
  }

  // -----------------------------------------------------------
  // Email existe
  // -----------------------------------------------------------
  Future<bool> emailExiste(String email) async {
    if (kUsarModoMock) return true;
    if (kUsarServidorLocal) {
      try {
        final res = await http.post(
          Uri.parse('$kServidorLocalUrl/api/auth/recover'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'email': email}),
        );
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body);
          return (body['error'] as String?)?.contains('no user found') != true;
        }
        return true;
      } catch (_) {
        return true;
      }
    }
    try {
      final result = await sb.Supabase.instance.client.rpc('email_existe', params: {'email_ingresado': email});
      return result == true;
    } catch (_) {
      return true;
    }
  }

  // -----------------------------------------------------------
  // Solicitar recuperación
  // -----------------------------------------------------------
  Future<void> solicitarRecuperacion({required String email}) async {
    if (kUsarModoMock) return;
    _requerirConexion();
    if (kUsarServidorLocal) {
      return _localHttp(() async {
        final res = await http.post(
          Uri.parse('$kServidorLocalUrl/api/auth/recover'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'email': email}),
        );
        if (res.statusCode == 200) return;
        throw ErrorServidorException();
      });
    }
    return _ejecutar(() => sb.Supabase.instance.client.auth.resetPasswordForEmail(email));
  }

  // -----------------------------------------------------------
  // Actualizar password
  // -----------------------------------------------------------
  Future<void> actualizarPassword(String nuevaPassword) async {
    if (kUsarModoMock) return;
    if (kUsarServidorLocal) {
      return _localHttp(() async {
        final res = await http.post(
          Uri.parse('$kServidorLocalUrl/api/auth/update-password'),
          headers: {'content-type': 'application/json', 'authorization': 'Bearer $_localToken'},
          body: jsonEncode({'password': nuevaPassword}),
        );
        if (res.statusCode == 200) return;
        throw ErrorServidorException();
      });
    }
    await sb.Supabase.instance.client.auth.updateUser(
      sb.UserAttributes(password: nuevaPassword),
    );
  }

  // -----------------------------------------------------------
  // Actualizar email
  // -----------------------------------------------------------
  Future<void> actualizarEmail(String nuevoEmail) async {
    if (kUsarModoMock) {
      _localUser?['email'] = nuevoEmail;
      await LocalTokenStore.guardarUsuario(_localUser!);
      return;
    }
    if (kUsarServidorLocal) {
      return _localHttp(() async {
        final res = await http.post(
          Uri.parse('$kServidorLocalUrl/api/auth/update-email'),
          headers: {
            'content-type': 'application/json',
            'authorization': 'Bearer $_localToken'
          },
          body: jsonEncode({'email': nuevoEmail}),
        );
        if (res.statusCode == 200) return;
        throw ErrorServidorException();
      });
    }
    await sb.Supabase.instance.client.auth.updateUser(
      sb.UserAttributes(email: nuevoEmail),
    );
  }

  // -----------------------------------------------------------
  // Eliminar cuenta
  // -----------------------------------------------------------
  Future<void> eliminarCuenta() async {
    if (kUsarModoMock || kUsarServidorLocal) {
      _localUser = null;
      await LocalTokenStore.limpiar();
      _localStreamCtrl ??= StreamController<AuthState>.broadcast();
      _localStreamCtrl!.add(const AuthState('SIGNED_OUT'));
      return;
    }
    await sb.Supabase.instance.client.auth.signOut();
  }

  // -----------------------------------------------------------
  // OTP (solo Supabase)
  // -----------------------------------------------------------
  Future<Map<String, dynamic>> verificarCodigo({
    required String email,
    required String token,
    required sb.OtpType tipo,
  }) async {
    _requerirConexion();
    return _ejecutar(() async {
      final r = await sb.Supabase.instance.client.auth.verifyOTP(
        email: email,
        token: token,
        type: tipo,
      );
      return {'user': r.user?.toJson(), 'token': ''};
    });
  }

  Future<void> reenviarCodigo({required String email, sb.OtpType tipo = sb.OtpType.email}) async {
    _requerirConexion();
    return _ejecutar(() async {
      if (tipo == sb.OtpType.recovery) {
        return sb.Supabase.instance.client.auth.resetPasswordForEmail(email);
      }
      return sb.Supabase.instance.client.auth.signInWithOtp(email: email);
    });
  }

  // -----------------------------------------------------------
  // Mock helpers
  // -----------------------------------------------------------
  Future<Map<String, dynamic>> _mockAuth(String email, {String? nombre}) async {
    final id = 'mock-${email.hashCode.toRadixString(16)}';
    _localUser = {
      'id': id,
      'email': email,
      'nombre': (nombre != null && nombre.isNotEmpty)
          ? nombre
          : email.split('@').first,
    };

    if (_db != null) {
      final usuario = await GeneradorMock.crearUsuarioPropio(_db!, _localUser!['nombre'] as String);
      _localUser!['id'] = usuario.uuid;
    }

    await LocalTokenStore.guardarUsuario(_localUser!);
    _localStreamCtrl ??= StreamController<AuthState>.broadcast();
    _localStreamCtrl!.add(AuthState('SIGNED_IN', user: _localUser));
    return {'user': _localUser!, 'token': 'mock-token'};
  }

  // -----------------------------------------------------------
  // Helpers de red
  // -----------------------------------------------------------
  void _requerirConexion() {
    if (!ConnectivityService.instancia.hayConexion) {
      throw SinConexionException();
    }
  }

  Future<T> _localHttp<T>(Future<T> Function() llamada) async {
    try {
      return await llamada();
    } on SocketException {
      throw ErrorServidorException();
    } on http.ClientException {
      throw ErrorServidorException();
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('Connection timed out') ||
          e.toString().contains('Failed host lookup')) {
        throw ErrorServidorException();
      }
      rethrow;
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
    } on sb.AuthRetryableFetchException {
      throw ErrorServidorException();
    } on sb.AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid format') || msg.contains('validation_failed')) {
        throw EmailInvalidoException();
      }
      if (msg.contains('user already registered')) {
        throw EmailYaRegistradoException();
      }
      if (msg.contains('email not found') ||
          msg.contains('user not found') ||
          msg.contains('no account') ||
          msg.contains('could not find user') ||
          msg.contains('no user found')) {
        throw EmailNoRegistradoException();
      }
      if (msg.contains('signup') &&
          (msg.contains('not allowed') || msg.contains('disabled') || msg.contains('forbidden'))) {
        throw RegistroDeshabilitadoException();
      }
      if (msg.contains('invalid login') || msg.contains('invalid credentials') || msg.contains('wrong password')) {
        throw CredencialesInvalidasException();
      }
      if (msg.contains('invalid token') || msg.contains('token expired') || msg.contains('otp expired') || msg.contains('invalid otp')) {
        throw CodigoInvalidoException();
      }
      throw ErrorInesperadoException();
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('No address associated') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('Connection timed out')) {
        throw ErrorServidorException();
      }
      throw ErrorInesperadoException();
    }
  }
}
