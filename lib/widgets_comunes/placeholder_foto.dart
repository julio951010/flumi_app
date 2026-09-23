import 'package:flutter/material.dart';

/// Placeholder que se muestra cuando una foto no carga (URL rota, sin red,
/// archivo borrado) en lugar de dejar un hueco vacio.
class PlaceholderFoto extends StatelessWidget {
  final double? width;
  final double? height;
  final String? inicial;

  const PlaceholderFoto({super.key, this.width, this.height, this.inicial});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/profile-picture-placeholder.png',
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        // Fallback si hasta el placeholder falla (asset no empaquetado)
        final letra = (inicial ?? '').trim().isNotEmpty
            ? inicial!.trim()[0].toUpperCase()
            : null;
        return Container(
          width: width,
          height: height,
          color: const Color(0xFFE0E0E0),
          alignment: Alignment.center,
          child: letra != null
              ? Text(
                  letra,
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[500],
                  ),
                )
              : Icon(Icons.person, size: 48, color: Colors.grey[500]),
        );
      },
    );
  }
}
