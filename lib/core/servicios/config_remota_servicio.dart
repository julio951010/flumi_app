import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lee los feature flags de `public.app_config` en Supabase.
/// Solo se consulta `suscripciones_habilitadas` por ahora.
class ConfigRemotaServicio extends ChangeNotifier {
  final SupabaseClient? _client;
  bool _suscripcionesHabilitadas = true;
  bool _cargado = false;
  Timer? _pollTimer;
  RealtimeChannel? _channel;

  bool get suscripcionesHabilitadas => _suscripcionesHabilitadas;
  bool get cargado => _cargado;

  ConfigRemotaServicio(SupabaseClient? client) : _client = client;

  Future<void> inicializar() async {
    await _cargar();
    final client = _client;
    if (client != null) {
      try {
        _channel = client.channel('app_config_changes')
          ..onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'app_config',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'clave',
              value: 'suscripciones_habilitadas',
            ),
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
      final res = await client
          .from('app_config')
          .select('valor')
          .eq('clave', 'suscripciones_habilitadas')
          .maybeSingle();
      if (res != null) {
        final v = res['valor'];
        final nuevo = v is bool ? v : (v.toString().toLowerCase() == 'true');
        if (_suscripcionesHabilitadas != nuevo) {
          _suscripcionesHabilitadas = nuevo;
          notifyListeners();
        }
      }
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
