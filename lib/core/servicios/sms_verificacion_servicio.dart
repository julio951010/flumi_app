import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';

/// Datos extraídos del SMS de confirmación de PAGOxMOVIL / ENZONA.
/// No autorrellena el campo: solo se usa para comparar con lo que el usuario
/// escribe manualmente en el paso de comprobante.
class SmsPagoData {
  final String remitente; // PAGOxMOVIL | ENZONA
  final String nro; // 13 Transfermóvil / 12 EnZona alfanumérico
  final double? monto; // ej 1640.00
  final String? beneficiario; // "9224XXXXXXXXX0870" tal cual en SMS (con X)
  final DateTime? fechaSms; // Fecha extraída del SMS (Fecha: 22/3/2026)
  final String raw;
  final DateTime timestamp; // cuando se recibió el SMS en el dispositivo

  const SmsPagoData({
    required this.remitente,
    required this.nro,
    this.monto,
    this.beneficiario,
    this.fechaSms,
    required this.raw,
    required this.timestamp,
  });
}

/// Servicio que escucha SMS en Android y extrae Nro + monto.
/// En iOS no hay acceso a SMS → siempre devuelve null y el flujo queda manual/pendiente.
class SmsVerificacionServicio {
  SmsVerificacionServicio._();
  static final SmsVerificacionServicio instancia = SmsVerificacionServicio._();

  SmsPagoData? _ultimo;
  SmsPagoData? get ultimo => _ultimo;
  bool _escuchando = false;
  final Telephony _telephony = Telephony.instance;

  // Para flumi_app: el usuario debe haber pagado hace poco. SMS viejos no valen.
  static const _validez = Duration(minutes: 15);

  bool get tieneSmsValido {
    final s = _ultimo;
    if (s == null) return false;
    return DateTime.now().difference(s.timestamp) < _validez;
  }

  /// Inicia escucha de SMS en Android (solicita permiso si hace falta).
  /// En iOS no hace nada (no hay acceso a SMS).
  Future<void> iniciar() async {
    if (!Platform.isAndroid) return;
    if (_escuchando) return;
    try {
      final perm = await Permission.sms.request();
      if (!perm.isGranted) {
        debugPrint('[SmsVerificacion] permiso SMS denegado');
        return;
      }
      await _telephony.requestPhoneAndSmsPermissions;
      // Escucha en foreground y background
      _telephony.listenIncomingSms(
        onNewMessage: (SmsMessage m) {
          final addr = m.address ?? '';
          final body = m.body ?? '';
          if (body.isNotEmpty) onSmsRecibido(address: addr, body: body);
        },
        listenInBackground: true,
      );
      _escuchando = true;
      debugPrint('[SmsVerificacion] escucha SMS iniciada');
    } catch (e) {
      debugPrint('[SmsVerificacion] error iniciar: $e');
    }
  }

  /// Llamado por el handler nativo de telephony (Android). Parsea el cuerpo
  /// según el formato real de Transfermóvil (Banco Metropolitano) y EnZona.
  /// No autorrellena: solo guarda el último SMS válido.
  void onSmsRecibido({required String address, required String body}) {
    final remitenteRaw = address.trim().toUpperCase();
    final bodyUpper = body.toUpperCase();
    // Estricto: solo PAGOxMOVIL para Transfermóvil y ENZONA para EnZona, si no no es válido.
    final esTransfermovil = remitenteRaw == 'PAGOXMOVIL';
    final esEnzona = remitenteRaw == 'ENZONA';

    if (!esTransfermovil && !esEnzona) return;

    // Nro: prioriza el campo "Nro. Transaccion: XXX" del formato oficial.
    // Ej Transfermóvil: "Nro. Transaccion: MM6047281W987" (13 alfanumérico).
    // Se normaliza (sin guiones/espacios) y se exige la longitud exacta del
    // método: 13 Transfermóvil, 12 EnZona. Sin coincidencia exacta se ignora
    // el SMS (el pago queda pendiente para revisión manual).
    final longitud = esTransfermovil ? 13 : 12;
    String? nro = RegExp(r'NRO\.?\s*TRANSACCION\s*:\s*([A-Z0-9\- ]+)', caseSensitive: false)
            .firstMatch(body)
            ?.group(1)
            ?.toUpperCase()
            .replaceAll(RegExp(r'[^A-Z0-9]'), '') ??
        RegExp(r'NRO\.?\s*TRANSAC\w*\s*:\s*([A-Z0-9\- ]+)', caseSensitive: false)
            .firstMatch(body)
            ?.group(1)
            ?.toUpperCase()
            .replaceAll(RegExp(r'[^A-Z0-9]'), '');

    // Fallback por longitud exacta si no se encontró el campo etiquetado
    nro ??= RegExp('\\b([A-Z0-9]{$longitud})\\b').firstMatch(bodyUpper)?.group(1);
    if (nro == null || nro.length != longitud) return;

    // Monto: formato oficial "Monto: 1640.00 CUP" — prioriza esa línea
    double? monto;
    final mMontoEtiquetado = RegExp(r'MONTO\s*:\s*([\d.,]+)', caseSensitive: false).firstMatch(body);
    final mMonto = mMontoEtiquetado ??
        RegExp(r'(\d+[.,]\d{1,2})\s*CUP', caseSensitive: false).firstMatch(body) ??
        RegExp(r'(\d+\.\d{1,2})').firstMatch(body);
    if (mMonto != null) {
      final raw = mMonto.group(1)!.replaceAll(',', '.');
      monto = double.tryParse(raw);
    }

    // Beneficiario: "Beneficiario: 9224XXXXXXXXX0870" — guarda tal cual con X
    String? beneficiario;
    final mBen = RegExp(r'BENEFICIARIO\s*:\s*([0-9X]+)', caseSensitive: false).firstMatch(body);
    if (mBen != null) beneficiario = mBen.group(1)!.trim();

    // Fecha: "Fecha: 22/3/2026" — del SMS (fecha de la transacción)
    DateTime? fechaSms;
    final mFecha = RegExp(r'FECHA\s*:\s*(\d{1,2})\/(\d{1,2})\/(\d{4})', caseSensitive: false).firstMatch(body);
    if (mFecha != null) {
      try {
        final d = int.parse(mFecha.group(1)!);
        final m = int.parse(mFecha.group(2)!);
        final y = int.parse(mFecha.group(3)!);
        fechaSms = DateTime(y, m, d);
      } catch (_) {}
    }

    final data = SmsPagoData(
      remitente: esTransfermovil ? 'PAGOxMOVIL' : 'ENZONA',
      nro: nro.toUpperCase(),
      monto: monto,
      beneficiario: beneficiario,
      fechaSms: fechaSms,
      raw: body,
      timestamp: DateTime.now(),
    );
    _ultimo = data;
    debugPrint('[SmsVerificacion] SMS $remitenteRaw -> nro=${data.nro} monto=$monto');
  }

  /// Para testing / inyección manual sin SMS real.
  void inyectarParaTest(SmsPagoData data) => _ultimo = data;

  /// Limpia el SMS cacheado (tras verificación exitosa o al salir del flujo).
  void limpiar() => _ultimo = null;

  /// Validación silenciosa (background): compara Nro + remitente + monto +
  /// beneficiario (4 primeros y 4 últimos) + fecha. No muestra nada al usuario,
  /// solo se usa para auto-aprobar en servidor si todo coincide.
  bool coincideConUsuario({
    required String nroUsuario,
    required String metodo,
    required int montoEsperado,
    String? tarjetaDestino, // ej "9225 9598 7143 2108" configurada
  }) {
    final sms = _ultimo;
    if (sms == null) return false;
    if (DateTime.now().difference(sms.timestamp) > _validez) return false;

    final nroU = nroUsuario.trim().toUpperCase().replaceAll(' ', '');
    final nroS = sms.nro.trim().toUpperCase();
    if (nroU != nroS) return false;

    final metodoNorm = metodo.toLowerCase();
    final remitenteOk = (metodoNorm == 'transfermovil' && sms.remitente == 'PAGOXMOVIL') ||
        (metodoNorm == 'enzona' && sms.remitente == 'ENZONA');
    if (!remitenteOk) return false;

    if (sms.monto != null && (sms.monto! - montoEsperado).abs() > 0.01) return false;

    // Beneficiario: 4 primeros y 4 últimos deben coincidir con tarjeta configurada
    if (sms.beneficiario != null && tarjetaDestino != null && tarjetaDestino.trim().isNotEmpty) {
      final ben = sms.beneficiario!.replaceAll(RegExp(r'[^0-9]'), '');
      final tarj = tarjetaDestino.replaceAll(RegExp(r'[^0-9]'), '');
      if (ben.length >= 8 && tarj.length >= 8) {
        final benFirst4 = ben.substring(0, 4);
        final benLast4 = ben.substring(ben.length - 4);
        final tarjFirst4 = tarj.substring(0, 4);
        final tarjLast4 = tarj.substring(tarj.length - 4);
        if (benFirst4 != tarjFirst4 || benLast4 != tarjLast4) return false;
      }
    }

    // Fecha: la del SMS debe ser hoy (fecha del pago en app)
    if (sms.fechaSms != null) {
      final hoy = DateTime.now();
      final f = sms.fechaSms!;
      if (f.year != hoy.year || f.month != hoy.month || f.day != hoy.day) {
        // Tolerancia: permite ayer por zona horaria / SMS retrasado
        final diffDays = hoy.difference(DateTime(f.year, f.month, f.day)).inDays.abs();
        if (diffDays > 1) return false;
      }
    }

    return true;
  }
}
