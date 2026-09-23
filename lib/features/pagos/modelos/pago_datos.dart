enum MetodoPago { transfermovil, enzona }

extension MetodoPagoX on MetodoPago {
  String get nombre {
    switch (this) {
      case MetodoPago.transfermovil:
        return 'Transfermóvil';
      case MetodoPago.enzona:
        return 'EnZona';
    }
  }

  String get descripcion {
    switch (this) {
      case MetodoPago.transfermovil:
        return 'ETECSA · CUP';
      case MetodoPago.enzona:
        return 'Plataforma ETECSA';
    }
  }
}

class PagoDatos {
  final String nombrePlan; // Flumi Plus / Premium
  final int dias; // 7, 30, 90
  final int precio; // en CUP
  MetodoPago? metodo;
  String? idTransaccion;
  bool autoAprobado = false;

  PagoDatos({
    required this.nombrePlan,
    required this.dias,
    required this.precio,
    this.metodo,
    this.idTransaccion,
  });

  // Datos fijos del destino (de tu negocio). Cambia aquí si rotas tarjeta/teléfono.
  String get tarjetaDestino => '9225 9598 7143 2108';
  String get telefonoConfirmar => '+53 5 123 45 67';
  String get montoTexto => '$precio CUP';
  String get concepto => 'Flumi $nombrePlan $dias días';

  /// Payload para QR (formato simple para Transfermóvil/EnZona).
  String get qrPayload =>
      'transfer|tarjeta:$tarjetaDestino|tel:$telefonoConfirmar|monto:$precio|concepto:$concepto';
}
