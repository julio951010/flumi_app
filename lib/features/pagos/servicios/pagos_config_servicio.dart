import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/env.dart';
import '../modelos/pago_datos.dart';

class PagosConfig {
  final String metodo; // transfermovil | enzona
  final String tarjetaDestino;
  final String movilConfirmar;
  final String qrUrl;
  final String concepto;

  const PagosConfig({
    required this.metodo,
    required this.tarjetaDestino,
    required this.movilConfirmar,
    required this.qrUrl,
    required this.concepto,
  });

  factory PagosConfig.fromMap(Map<String, dynamic> m) => PagosConfig(
        metodo: (m['metodo'] as String?) ?? 'transfermovil',
        tarjetaDestino: (m['tarjeta_destino'] as String?) ?? '',
        movilConfirmar: (m['movil_confirmar'] as String?) ?? '',
        qrUrl: (m['qr_url'] as String?) ?? '',
        concepto: (m['concepto'] as String?) ?? '',
      );
}

/// Servicio que lee `pagos_config` desde Supabase (gestionado desde flumi_admin).
/// Si no hay fila o falla la red, devuelve null y la UI usa fallback local.
class PagosConfigServicio {
  /// ¿El método está activo en Supabase? Sin red o sin fila se asume activo
  /// (fallback local) para no bloquear el pago offline.
  static Future<bool> estaActivo(MetodoPago metodo) async {
    if (kUsarServidorLocal) return true;
    final key = metodo == MetodoPago.transfermovil ? 'transfermovil' : 'enzona';
    try {
      final row = await Supabase.instance.client
          .from('pagos_config')
          .select('activo')
          .eq('metodo', key)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));
      if (row == null) return true;
      return (row['activo'] as bool?) ?? true;
    } catch (e) {
      debugPrint('[PagosConfig] error activo $key: $e');
      return true;
    }
  }

  static Future<PagosConfig?> obtener(MetodoPago metodo) async {
    if (kUsarServidorLocal) return null;
    final key = metodo == MetodoPago.transfermovil ? 'transfermovil' : 'enzona';
    try {
      final row = await Supabase.instance.client
          .from('pagos_config')
          .select()
          .eq('metodo', key)
          .eq('activo', true)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));
      if (row == null) return null;
      return PagosConfig.fromMap(row);
    } catch (e) {
      debugPrint('[PagosConfig] error fetch $key: $e');
      return null;
    }
  }
}
