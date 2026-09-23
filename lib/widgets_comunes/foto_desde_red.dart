import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'placeholder_foto.dart';
import 'shimmer_caja.dart';

final Map<String, Uint8List> _cacheFotos = {};
final Map<String, Future<Uint8List>> _descargas = {};

Future<Uint8List> _descargarBytes(String ruta) {
  return _descargas.putIfAbsent(ruta, () async {
    try {
      final res = await http
          .get(Uri.parse(ruta))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final bytes = res.bodyBytes;
      _cacheFotos[ruta] = bytes;
      return bytes;
    } finally {
      _descargas.remove(ruta);
    }
  });
}

/// Bytes de una foto remota, con el mismo caché en memoria de FotoDesdeRed.
Future<Uint8List> bytesDeRed(String ruta) => _descargarBytes(ruta);

/// Carga fotos remotas descargando los bytes con `package:http`
/// (funciona igual en web, Android e iOS) en lugar del motor de
/// `Image.network`, que en web se queda cargando eternamente con
/// ciertos servidores y navegadores.
class FotoDesdeRed extends StatefulWidget {
  final String ruta;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final VoidCallback? onError;
  final VoidCallback? onLoad;

  const FotoDesdeRed({
    super.key,
    required this.ruta,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.cacheWidth,
    this.onError,
    this.onLoad,
  });

  @override
  State<FotoDesdeRed> createState() => _FotoDesdeRedState();
}

class _FotoDesdeRedState extends State<FotoDesdeRed> {
  Uint8List? _bytes;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(covariant FotoDesdeRed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ruta != widget.ruta) {
      _error = false;
      final cache = _cacheFotos[widget.ruta];
      if (cache != null) {
        _bytes = cache;
      } else {
        _bytes = null;
        _cargar();
      }
    }
  }

  Future<void> _cargar() async {
    final cache = _cacheFotos[widget.ruta];
    if (cache != null) {
      if (mounted) {
        setState(() => _bytes = cache);
        widget.onLoad?.call();
      }
      return;
    }
    try {
      final bytes = await _descargarBytes(widget.ruta);
      if (mounted) {
        setState(() => _bytes = bytes);
        widget.onLoad?.call();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = true);
        widget.onError?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return PlaceholderFoto(width: widget.width, height: widget.height);
    }
    Widget imagen;
    if (_bytes != null) {
      imagen = Image.memory(
        _bytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        cacheWidth: widget.cacheWidth,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) {
          WidgetsBinding.instance.addPostFrameCallback((_) => widget.onError?.call());
          return PlaceholderFoto(
            width: widget.width,
            height: widget.height,
          );
        },
      );
    } else {
      imagen = const ShimmerCaja(radius: 0);
    }
    return imagen;
  }
}