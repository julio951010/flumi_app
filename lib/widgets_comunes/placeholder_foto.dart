import 'package:flutter/material.dart';

/// Fallback cuando una foto no carga (URL rota, sin red, archivo borrado):
/// icono de Flumi grande y centrado en el área que ocuparía la imagen.
class PlaceholderFoto extends StatelessWidget {
  final double? width;
  final double? height;
  final String? inicial; // Sin uso: se conserva por compatibilidad.

  const PlaceholderFoto({super.key, this.width, this.height, this.inicial});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFF4F2FA),
      alignment: Alignment.center,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Logo al 60% del lado menor cuando el área es conocida;
          // tamaño natural si el área no tiene cota.
          double? lado;
          if (constraints.maxWidth.isFinite &&
              constraints.maxHeight.isFinite) {
            final menor = constraints.maxWidth < constraints.maxHeight
                ? constraints.maxWidth
                : constraints.maxHeight;
            if (menor > 0) lado = menor * 0.6;
          } else if (width != null && width! > 0) {
            lado = width! * 0.6;
          }
          return Image.asset(
            'assets/images/flumi_logo.png',
            width: lado,
            height: lado,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.broken_image_outlined,
              size: lado ?? 64,
              color: Colors.grey[400],
            ),
          );
        },
      ),
    );
  }
}
