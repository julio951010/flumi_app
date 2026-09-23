import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'foto_desde_red.dart';
import 'placeholder_foto.dart';

Widget imagenFoto(String ruta,
    {BoxFit fit = BoxFit.cover, int? cacheWidth, VoidCallback? onError, VoidCallback? onLoad}) {
  if (ruta.startsWith('http')) {
    return FotoDesdeRed(ruta: ruta, fit: fit, cacheWidth: cacheWidth, onError: onError, onLoad: onLoad);
  }
  if (ruta.startsWith('assets/')) {
    return Image.asset(ruta,
        fit: fit,
        cacheWidth: cacheWidth,
        errorBuilder: (context, error, stack) {
          if (onError != null) WidgetsBinding.instance.addPostFrameCallback((_) => onError.call());
          return const PlaceholderFoto();
        });
  }
  return Image.file(File(ruta),
      fit: fit,
      cacheWidth: cacheWidth,
      errorBuilder: (context, error, stack) {
        if (onError != null) WidgetsBinding.instance.addPostFrameCallback((_) => onError.call());
        return const PlaceholderFoto();
      });
}

Future<Uint8List> bytesDeArchivo(String ruta) async {
  if (ruta.startsWith('assets/')) {
    final datos = await rootBundle.load(ruta);
    return datos.buffer.asUint8List();
  }
  return File(ruta).readAsBytes();
}

Widget imagenOrigen(String ruta,
    {double? width, double? height, BoxFit fit = BoxFit.cover, VoidCallback? onError, VoidCallback? onLoad}) {
  if (ruta.startsWith('http')) {
    return FotoDesdeRed(
      ruta: ruta,
      fit: fit,
      width: width,
      height: height,
      onError: onError,
      onLoad: onLoad,
    );
  }
  return imagenFoto(ruta, fit: fit, onError: onError, onLoad: onLoad);
}