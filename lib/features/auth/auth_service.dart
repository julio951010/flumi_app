import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../config/env.dart';
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

class DemasiadosIntentosException implements Exception {
  @override
  String toString() => 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';
}

class EmailNoConfirmadoException implements Exception {
  @override
  String toString() => 'Debes verificar tu correo antes de entrar. Revisa tu bandeja (y el spam) e ingresa el código.';
}

class MismaContrasenaException implements Exception {
  @override
  String toString() => 'La nueva contraseña debe ser diferente a la anterior.';
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
    if (kUsarServidorLocal) return _localUser;
    return sb.Supabase.instance.client.auth.currentUser?.toJson();
  }

  bool get estaAutenticado {
    if (kUsarServidorLocal) return _localUser != null;
    return sb.Supabase.instance.client.auth.currentSession != null;
  }

  Stream<AuthState> get estadoStream {
    _localStreamCtrl ??= StreamController<AuthState>.broadcast();
    if (kUsarServidorLocal) return _localStreamCtrl!.stream;
    return sb.Supabase.instance.client.auth.onAuthStateChange.map(
      // Los eventos de supabase_flutter llegan en camelCase (signedIn,
      // initialSession, userUpdated...) y se normalizan a MAYÚSCULAS con
      // guion bajo (SIGNED_IN, INITIAL_SESSION, USER_UPDATED...) para que
      // los listeners de la app los comparen como siempre lo han hecho.
      (e) => AuthState(
        e.event.name
            .replaceAllMapped(
                RegExp(r'[A-Z]'), (m) => '_${m.group(0)}')
            .toUpperCase(),
        user: e.session?.user.toJson(),
      ),
    );
  }

  // -----------------------------------------------------------
  // Inicializar
  // -----------------------------------------------------------
  Future<void> inicializar() async {
    if (kUsarServidorLocal) {
      final token = await LocalTokenStore.obtenerToken();
      final user = await LocalTokenStore.obtenerUsuario();
      if (token != null && user != null) {
        _localUser = user;
        _localStreamCtrl ??= StreamController<AuthState>.broadcast();
        _localStreamCtrl!.add(AuthState('INITIAL_SESSION', user: user));
      }
      await registrarConexion();
    }
  }

  // -----------------------------------------------------------
  // Registrar conexión (estado en línea)
  // -----------------------------------------------------------
  Future<void> registrarConexion() async {
    try {
      final filas =
          (db.select(db.usuarios)..where((u) => u.esPerfilPropio.equals(true))..limit(1))
              .get();
      final usuario = await filas;
      if (usuario.isEmpty) return;
      await (db.update(db.usuarios)
            ..where((u) => u.uuid.equals(usuario.first.uuid)))
          .write(UsuariosCompanion(ultimaConexion: Value(DateTime.now())));
    } catch (_) {
      // Best-effort: no bloquear el flujo de auth si falla el registro.
    }
  }

  // -----------------------------------------------------------
  // Iniciar sesión
  // -----------------------------------------------------------
  Future<Map<String, dynamic>> iniciarSesion({
    required String email,
    required String password,
  }) async {
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
          await registrarConexion();
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
      // Enviar mensaje de bienvenida desde el perfil "Flumi" al nuevo usuario.
      // Usa fire-and-forget para no bloquear el registro si falla.
      if (r.user != null) {
        Future.microtask(() => sb.Supabase.instance.client
            .rpc('enviar_bienvenida_nuevo_usuario')
            .catchError((_) {}));
      }
      return {'user': r.user?.toJson(), 'token': ''};
    });
  }

  // -----------------------------------------------------------
  // Cerrar sesión
  // -----------------------------------------------------------
  Future<void> cerrarSesion() async {
    if (kUsarServidorLocal) {
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

  /// Envía código OTP de RECUPERACIÓN (flujo con código, no enlace).
  /// No abre sesión; el código se verifica con tipo `recovery`.
  Future<void> solicitarCodigoRecuperacion({required String email}) async {
    _requerirConexion();
    return _ejecutar(() async {
      await sb.Supabase.instance.client.auth.signInWithOtp(email: email);
    });
  }

  // -----------------------------------------------------------
  // Solicitar recuperación (por enlace, legado)
  // -----------------------------------------------------------
  Future<void> solicitarRecuperacion({required String email}) async {
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
    return _ejecutar(() => sb.Supabase.instance.client.auth.updateUser(
          sb.UserAttributes(password: nuevaPassword),
        ));
  }

  // -----------------------------------------------------------
  // Actualizar email
  // -----------------------------------------------------------
  Future<void> actualizarEmail(String nuevoEmail) async {
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
    return _ejecutar(() => sb.Supabase.instance.client.auth.updateUser(
          sb.UserAttributes(email: nuevoEmail),
        ));
  }

  // -----------------------------------------------------------
  // Eliminar cuenta COMPLETA (borra auth, datos, storage, todo)
  // -----------------------------------------------------------
  Future<void> eliminarCuentaCompleta() async {
    if (kUsarServidorLocal) {
      _localUser = null;
      await LocalTokenStore.limpiar();
      _localStreamCtrl ??= StreamController<AuthState>.broadcast();
      _localStreamCtrl!.add(const AuthState('SIGNED_OUT'));
      return;
    }

    // Llama a la Edge Function que borra TODO (auth, datos, storage)
    try {
      await sb.Supabase.instance.client.functions.invoke('eliminar-cuenta');
    } catch (e) {
      // Fallback: si falla la Edge Function, al menos cerramos sesión
      await sb.Supabase.instance.client.auth.signOut();
      rethrow;
    }
  }

  // Mantener compatibilidad: alias para código existente
  Future<void> eliminarCuenta() async {
    await eliminarCuentaCompleta();
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

  /// Envía el mensaje de bienvenida de Flumi al usuario actual.
  /// Llamar DESPUÉS de verificar (ya hay sesión). Idempotente en servidor.
  Future<void> enviarBienvenida() async {
    if (kUsarServidorLocal) return;
    await sb.Supabase.instance.client.rpc('enviar_bienvenida_nuevo_usuario');
  }

  /// Reenvía el código de verificación de REGISTRO (signup).
  /// Usa `resend` con tipo signup: no crea sesión, solo reenvía el email.
  Future<void> reenviarCodigoRegistro({required String email}) async {
    _requerirConexion();
    return _ejecutar(() async {
      await sb.Supabase.instance.client.auth.resend(
        type: sb.OtpType.signup,
        email: email,
      );
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
    } on sb.AuthRetryableFetchException {
      throw ErrorServidorException();
    } on sb.AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('rate limit') ||
          msg.contains('too many requests') ||
          msg.contains('over_email_send_rate_limit') ||
          msg.contains('429')) {
        throw DemasiadosIntentosException();
      }
      if (msg.contains('email not confirmed') ||
          msg.contains('email_not_confirmed')) {
        throw EmailNoConfirmadoException();
      }
      if (msg.contains('same_password') ||
          (msg.contains('different from') && msg.contains('password'))) {
        throw MismaContrasenaException();
      }
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
