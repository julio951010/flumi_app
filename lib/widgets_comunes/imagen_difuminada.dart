import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class ImagenDifuminada extends StatefulWidget {
  final String ruta;
  final double sigma;
  final BoxFit fit;

  const ImagenDifuminada({
    super.key,
    required this.ruta,
    this.sigma = 4,
    this.fit = BoxFit.cover,
  });

  @override
  State<ImagenDifuminada> createState() => _ImagenDifuminadaState();
}

class _ImagenDifuminadaState extends State<ImagenDifuminada> {
  ui.Image? _borrosa;
  bool _fallo = false;

  @override
  void initState() {
    super.initState();
    _procesar();
  }

  Future<void> _procesar() async {
    try {
      final bytes = await File(widget.ruta).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final original = frame.image;

      const maxLado = 480.0;
      final escala =
          original.width >= original.height
              ? maxLado / original.width
              : maxLado / original.height;
      final w = (original.width * escala).round();
      final h = (original.height * escala).round();

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint()
        ..imageFilter =
            ui.ImageFilter.blur(sigmaX: widget.sigma, sigmaY: widget.sigma);
      canvas.drawImageRect(
        original,
        ui.Rect.fromLTWH(
            0, 0, original.width.toDouble(), original.height.toDouble()),
        ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        paint,
      );
      final picture = recorder.endRecording();
      final resultado = await picture.toImage(w, h);

      if (!mounted) return;
      setState(() => _borrosa = resultado);
    } catch (_) {
      if (!mounted) return;
      setState(() => _fallo = true);
    }
  }

  @override
  void dispose() {
    _borrosa?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borrosa = _borrosa;
    if (borrosa == null) {
      return Container(
        color: _fallo ? Colors.black12 : const Color(0xFFB39DDB),
      );
    }
    return RawImage(image: borrosa, fit: widget.fit);
  }
}