import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'foto_desde_red.dart';
import 'placeholder_foto.dart';

Widget imagenFoto(String ruta,
    {BoxFit fit = BoxFit.cover, int? cacheWidth}) {
  if (ruta.startsWith('http')) {
    return FotoDesdeRed(ruta: ruta, fit: fit, cacheWidth: cacheWidth);
  }
  // Archivos recién elegidos con el picker en web (blob:/data:).
  if (ruta.startsWith('blob:') || ruta.startsWith('data:')) {
    return Image.network(ruta,
        fit: fit,
        errorBuilder: (context, error, stack) => const PlaceholderFoto());
  }
  return Image.asset(ruta,
      fit: fit,
      cacheWidth: cacheWidth,
      errorBuilder: (context, error, stack) => const PlaceholderFoto());
}

Future<Uint8List> bytesDeArchivo(String ruta) async {
  final datos = await rootBundle.load(ruta);
  return datos.buffer.asUint8List();
}

Widget imagenOrigen(String ruta,
    {double? width, double? height, BoxFit fit = BoxFit.cover}) {
  if (ruta.startsWith('http')) {
    return FotoDesdeRed(
      ruta: ruta,
      fit: fit,
      width: width,
      height: height,
    );
  }
  return imagenFoto(ruta, fit: fit);
}