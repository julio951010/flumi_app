import 'dart:io';
import 'package:flutter/material.dart';
import '../core/base_datos_local/database.dart';

class TarjetaUsuario extends StatelessWidget {
  final Usuario usuario;
  final Widget? imagenOverlay;
  final Widget? badge;
  final Widget? esquinaDerecha;
  final VoidCallback? onTap;

  const TarjetaUsuario({
    super.key,
    required this.usuario,
    this.imagenOverlay,
    this.badge,
    this.esquinaDerecha,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inicial =
        usuario.nombre.isNotEmpty ? usuario.nombre[0].toUpperCase() : '?';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipPath(
                    clipper: const AlmohadillaClipper(),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFFFF6584)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Center(
                            child: Text(inicial,
                                style: const TextStyle(
                                    fontSize: 48,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                          if (usuario.fotosLocalesRutas.isNotEmpty &&
                              File(usuario.fotosLocalesRutas.first)
                                  .existsSync())
                            Image.file(File(usuario.fotosLocalesRutas.first),
                                fit: BoxFit.cover),
                          if (imagenOverlay != null) imagenOverlay!,
                        ],
                      ),
                    ),
                  ),
                  if (badge != null)
                    Positioned(top: 6, right: 6, child: badge!),
                ],
              ),
            ),
            // Name + Age + Verified + online dot
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: Stack(
                children: [
                  Padding(
                    padding:
                        EdgeInsets.only(right: esquinaDerecha != null ? 26 : 0),
                    child: Row(
                      children: [
                        if (usuario.verificadoStatus)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.verified,
                                color: Colors.blueAccent, size: 16),
                          ),
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  '${usuario.nombre}, ${usuario.edad}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color:
                                      usuario.ultimaSincronizacionTimestamp !=
                                              null
                                          ? const Color(0xFF4CD964)
                                          : Colors.grey[400],
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (esquinaDerecha != null)
                    Positioned(
                      right: 4,
                      top: 0,
                      bottom: 0,
                      child: Center(child: esquinaDerecha!),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AlmohadillaClipper extends CustomClipper<Path> {
  const AlmohadillaClipper();

  static const double _radio = 30;
  static const double _hundimiento = 7;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    const r = _radio;
    const d = _hundimiento;

    return Path()
      ..moveTo(r, 0)
      ..quadraticBezierTo(w / 2, d, w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..quadraticBezierTo(w - d, h / 2, w, h - r)
      ..quadraticBezierTo(w, h, w - r, h)
      ..quadraticBezierTo(w / 2, h - d, r, h)
      ..quadraticBezierTo(0, h, 0, h - r)
      ..quadraticBezierTo(d, h / 2, 0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant AlmohadillaClipper oldClipper) => false;
}
