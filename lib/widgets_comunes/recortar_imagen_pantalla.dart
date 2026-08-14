import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../core/utilidades/xfile_bytes.dart';

class RecortarImagenPantalla extends StatefulWidget {
  final Uint8List bytes;
  final String nombre;

  const RecortarImagenPantalla({
    super.key,
    required this.bytes,
    required this.nombre,
  });

  @override
  State<RecortarImagenPantalla> createState() => _RecortarImagenPantallaState();
}

class _RecortarImagenPantallaState extends State<RecortarImagenPantalla> {
  final _ctrl = CropController();
  bool _procesando = false;

  Future<void> _confirmar() async {
    if (_procesando) return;
    setState(() => _procesando = true);
    _ctrl.crop();
  }

  void _onCropped(CropResult resultado) {
    switch (resultado) {
      case CropSuccess(:final croppedImage):
        _finalizar(croppedImage);
      case CropFailure(cause: final causa):
        _fallo(causa);
    }
  }

  Future<void> _finalizar(Uint8List recorte) async {
    try {
      final decodificada = img.decodeImage(recorte);
      if (decodificada == null) throw StateError('Formato no soportado');
      final redimensionada = img.copyResize(decodificada, width: 720);
      final jpeg = img.encodeJpg(redimensionada, quality: 85);
      final archivo =
          await xfileDesdeBytesImpl(jpeg, 'recorte_${widget.nombre}');
      if (mounted) Navigator.of(context).pop(archivo);
    } catch (error) {
      _fallo(error);
    }
  }

  void _fallo(Object causa) {
    if (!mounted) return;
    setState(() => _procesando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo recortar la imagen.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Recortar foto'),
        actions: [
          if (_procesando)
            const Padding(
              padding: EdgeInsets.all(14),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else
            TextButton(
              onPressed: _confirmar,
              child: const Text('Listo', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Crop(
              controller: _ctrl,
              image: widget.bytes,
              onCropped: _onCropped,
              aspectRatio: 1,
              interactive: true,
              fixCropRect: false,
              withCircleUi: false,
              maskColor: Colors.black.withValues(alpha: 0.55),
              baseColor: Colors.black,
              cornerDotBuilder: (size, edge) =>
                  const DotControl(color: Colors.white),
              progressIndicator: const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}