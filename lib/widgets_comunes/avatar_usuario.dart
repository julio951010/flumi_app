import 'package:flutter/material.dart';

import 'foto_perfil.dart';

final List<List<Color>> paletaAvatares = [
  [const Color(0xFF6C63FF), const Color(0xFFFF6584)],
  [const Color(0xFF4ECDC4), const Color(0xFF2ecc71)],
  [const Color(0xFF667eea), const Color(0xFF764ba2)],
  [const Color(0xFFf093fb), const Color(0xFFf5576c)],
  [const Color(0xFF3AA5ED), const Color(0xFF7B2CBF)],
];

Color colorDeAvatar(String nombre) {
  final lista = paletaAvatares[nombre.hashCode.abs() % paletaAvatares.length];
  return Color.lerp(lista[0], lista[1], 0.5)!;
}

/// Círculo de perfil con la foto del usuario; si no hay foto (o aún no se
/// descargó) muestra el gradiente con la inicial como fallback. Opcionalmente
/// añade el punto de presencia y el anillo de match.
class AvatarUsuario extends StatelessWidget {
  final String nombre;
  final String? fotoUrl;
  final double size;
  final bool? online;
  final bool anilloMatch;
  final double radioPunto;

  const AvatarUsuario({
    super.key,
    required this.nombre,
    this.fotoUrl,
    required this.size,
    this.online,
    this.anilloMatch = false,
    this.radioPunto = 7.5,
  });

  @override
  Widget build(BuildContext context) {
    final gradiente =
        paletaAvatares[nombre.hashCode.abs() % paletaAvatares.length];
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

    final fondo = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradiente,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        inicial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    Widget contenido = fondo;
    final foto = fotoUrl;
    if (foto != null && foto.isNotEmpty) {
      contenido = ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              fondo,
              imagenOrigen(foto, fit: BoxFit.cover),
            ],
          ),
        ),
      );
    }

    final circulo = anilloMatch
        ? Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradiente,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: contenido,
          )
        : contenido;

    final online = this.online;
    if (online == null) return circulo;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        circulo,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: radioPunto * 2,
            height: radioPunto * 2,
            decoration: BoxDecoration(
              color: online ? const Color(0xFF4CD964) : Colors.grey[400],
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
