import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'foto_desde_red.dart';

Widget imagenFoto(String ruta,
    {BoxFit fit = BoxFit.cover, int? cacheWidth}) {
  if (ruta.startsWith('http')) {
    return FotoDesdeRed(ruta: ruta, fit: fit, cacheWidth: cacheWidth);
  }
  if (ruta.startsWith('assets/')) {
    return Image.asset(ruta,
        fit: fit,
        cacheWidth: cacheWidth,
        errorBuilder: (context, error, stack) => const SizedBox.shrink());
  }
  return Image.file(File(ruta),
      fit: fit,
      cacheWidth: cacheWidth,
      errorBuilder: (context, error, stack) => const SizedBox.shrink());
}

Future<Uint8List> bytesDeArchivo(String ruta) async {
  if (ruta.startsWith('assets/')) {
    final datos = await rootBundle.load(ruta);
    return datos.buffer.asUint8List();
  }
  return File(ruta).readAsBytes();
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