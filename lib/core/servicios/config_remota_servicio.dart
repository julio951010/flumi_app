import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utilidades/app_log.dart';

/// Lee los feature flags de `public.app_config` en Supabase:
/// suscripciones, modo mantenimiento y versión mínima obligatoria.
/// El mantenimiento y la actualización se activan en vivo (realtime + poll).
class ConfigRemotaServicio extends ChangeNotifier {
  /// Build real de esta compilación (el `+N` de pubspec version, leído con
  /// package_info_plus). Única fuente de verdad: no hay que sincronizar nada
  /// a mano en cada release.
  int _buildActual = 1;
  int get buildActual => _buildActual;

  final SupabaseClient? _client;
  bool _suscripcionesHabilitadas = true;
  bool _enMantenimiento = false;
  String _mensajeMantenimiento = '';
  int _versionMinimaBuild = 1;
  String _actualizarUrl = '';
  String _mensajeActualizar = '';
  // Sobre nosotros (editables desde admin_flumi → Sobre nosotros).
  String _invitacionMensaje = '';
  String _descargaUrl = '';
  String _valorarUrl = '';
  String _donacionMensaje = '';
  String _donacionCuenta = '';
  String _donacionTelefono = '';
  bool _mostrarInvitar = true;
  bool _mostrarValorar = true;
  bool _mostrarDescargar = true;
  bool _mostrarDonar = true;
  bool _cargado = false;
  Timer? _pollTimer;
  RealtimeChannel? _channel;

  bool get suscripcionesHabilitadas => _suscripcionesHabilitadas;
  bool get enMantenimiento => _enMantenimiento;
  String get mensajeMantenimiento => _mensajeMantenimiento;
  String get actualizarUrl => _actualizarUrl;
  String get mensajeActualizar => _mensajeActualizar;
  String get invitacionMensaje => _invitacionMensaje;
  String get descargaUrl => _descargaUrl;
  String get valorarUrl => _valorarUrl;
  String get donacionMensaje => _donacionMensaje;
  String get donacionCuenta => _donacionCuenta;
  String get donacionTelefono => _donacionTelefono;
  bool get mostrarInvitar => _mostrarInvitar;
  bool get mostrarValorar => _mostrarValorar;
  bool get mostrarDescargar => _mostrarDescargar;
  bool get mostrarDonar => _mostrarDonar;
  bool get cargado => _cargado;

  /// true si esta compilación quedó por debajo del mínimo exigido.
  bool get necesitaActualizar => _buildActual < _versionMinimaBuild;

  bool _mostrarDe(String clave) => switch (clave) {
        'mostrar_invitar' => _mostrarInvitar,
        'mostrar_valorar' => _mostrarValorar,
        'mostrar_descargar' => _mostrarDescargar,
        'mostrar_donar' => _mostrarDonar,
        _ => true,
      };

  void _setMostrar(String clave, bool valor) {
    switch (clave) {
      case 'mostrar_invitar':
        _mostrarInvitar = valor;
      case 'mostrar_valorar':
        _mostrarValorar = valor;
      case 'mostrar_descargar':
        _mostrarDescargar = valor;
      case 'mostrar_donar':
        _mostrarDonar = valor;
    }
  }

  ConfigRemotaServicio(SupabaseClient? client) : _client = client;

  Future<void> inicializar() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _buildActual = int.tryParse(info.buildNumber) ?? 1;
    } catch (_) {}
    await _cargar();
    final client = _client;
    if (client != null) {
      try {
        // Sin filtro por clave: cualquier cambio de flags recarga todo.
        _channel = client.channel('app_config_changes')
          ..onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'app_config',
            callback: (_) => _cargar(),
          )
          ..subscribe();
      } catch (e) {
        appLog('ConfigRemota channel: $e');
      }
    }
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _cargar());
  }

  Future<void> _cargar() async {
    final client = _client;
    if (client == null) return;
    try {
      final res = await client
          .from('app_config')
          .select('clave,valor')
          .inFilter(
            'clave',
            const [
              'suscripciones_habilitadas',
              'mantenimiento',
              'mantenimiento_mensaje',
              'version_minima_build',
              'actualizar_url',
              'actualizar_mensaje',
              'invitacion_mensaje',
              'descarga_url',
              'valorar_url',
              'donacion_mensaje',
              'donacion_cuenta',
              'donacion_telefono',
              'mostrar_invitar',
              'mostrar_valorar',
              'mostrar_descargar',
              'mostrar_donar',
            ],
          )
          // Esta llamada se espera directo en el arranque (main() -> Grupo 2
          // -> inicializar()). Sin tope, una red lenta/caída podía dejar la
          // pantalla en negro indefinidamente antes de runApp(). Con tope,
          // el catch de abajo absorbe el timeout y sigue con los defaults.
          .timeout(const Duration(seconds: 5));
      var cambio = false;
      for (final fila in (res as List).cast<Map<String, dynamic>>()) {
        final clave = (fila['clave'] as String?) ?? '';
        final valor = (fila['valor'] as String?) ?? '';
        switch (clave) {
          case 'suscripciones_habilitadas':
            final nuevo = valor.toLowerCase() == 'true';
            if (_suscripcionesHabilitadas != nuevo) {
              _suscripcionesHabilitadas = nuevo;
              cambio = true;
            }
          case 'mantenimiento':
            final nuevo = valor.toLowerCase() == 'true';
            if (_enMantenimiento != nuevo) {
              _enMantenimiento = nuevo;
              cambio = true;
            }
          case 'mantenimiento_mensaje':
            if (_mensajeMantenimiento != valor) {
              _mensajeMantenimiento = valor;
              cambio = true;
            }
          case 'version_minima_build':
            final nuevo = int.tryParse(valor.trim()) ?? 1;
            if (_versionMinimaBuild != nuevo) {
              _versionMinimaBuild = nuevo;
              cambio = true;
            }
          case 'actualizar_url':
            if (_actualizarUrl != valor.trim()) {
              _actualizarUrl = valor.trim();
              cambio = true;
            }
          case 'actualizar_mensaje':
            if (_mensajeActualizar != valor) {
              _mensajeActualizar = valor;
              cambio = true;
            }
          case 'invitacion_mensaje':
            if (_invitacionMensaje != valor) {
              _invitacionMensaje = valor;
              cambio = true;
            }
          case 'descarga_url':
            if (_descargaUrl != valor.trim()) {
              _descargaUrl = valor.trim();
              cambio = true;
            }
          case 'valorar_url':
            if (_valorarUrl != valor.trim()) {
              _valorarUrl = valor.trim();
              cambio = true;
            }
          case 'mostrar_invitar':
          case 'mostrar_valorar':
          case 'mostrar_descargar':
          case 'mostrar_donar':
            final nuevo = valor.toLowerCase() == 'true';
            if (_mostrarDe(clave) != nuevo) {
              _setMostrar(clave, nuevo);
              cambio = true;
            }
          case 'donacion_mensaje':
            if (_donacionMensaje != valor) {
              _donacionMensaje = valor;
              cambio = true;
            }
          case 'donacion_cuenta':
            if (_donacionCuenta != valor.trim()) {
              _donacionCuenta = valor.trim();
              cambio = true;
            }
          case 'donacion_telefono':
            if (_donacionTelefono != valor.trim()) {
              _donacionTelefono = valor.trim();
              cambio = true;
            }
        }
      }
      if (cambio) notifyListeners();
    } catch (e) {
      appLog('ConfigRemota: $e');
    }
    _cargado = true;
  }

  Future<void> recargar() => _cargar();

  @override
  void dispose() {
    try {
      final client = _client;
      final channel = _channel;
      if (channel != null && client != null) client.removeChannel(channel);
    } catch (_) {}
    _pollTimer?.cancel();
    super.dispose();
  }
}
