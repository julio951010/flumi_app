import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  bool _cargado = false;
  Timer? _pollTimer;
  RealtimeChannel? _channel;

  bool get suscripcionesHabilitadas => _suscripcionesHabilitadas;
  bool get enMantenimiento => _enMantenimiento;
  String get mensajeMantenimiento => _mensajeMantenimiento;
  String get actualizarUrl => _actualizarUrl;
  String get mensajeActualizar => _mensajeActualizar;
  bool get cargado => _cargado;

  /// true si esta compilación quedó por debajo del mínimo exigido.
  bool get necesitaActualizar => _buildActual < _versionMinimaBuild;

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
        if (kDebugMode) debugPrint('ConfigRemota channel: $e');
      }
    }
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _cargar());
  }

  Future<void> _cargar() async {
    final client = _client;
    if (client == null) return;
    try {
      final res = await client.from('app_config').select('clave,valor').inFilter(
        'clave',
        const [
          'suscripciones_habilitadas',
          'mantenimiento',
          'mantenimiento_mensaje',
          'version_minima_build',
          'actualizar_url',
          'actualizar_mensaje',
        ],
      );
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
        }
      }
      if (cambio) notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('ConfigRemota: $e');
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
