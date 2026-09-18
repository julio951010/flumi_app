import 'package:flutter/material.dart';
import '../core/utilidades/fotos_perfil.dart';
import '../core/base_datos_local/database.dart';
import 'foto_perfil.dart';
import 'imagen_difuminada.dart';

class TarjetaUsuario extends StatelessWidget {
  final Usuario usuario;
  final Widget? imagenOverlay;
  final Widget? badge;
  final Widget? esquinaDerecha;
  final VoidCallback? onTap;
  final bool imagenBorrosa;
  final String? nombreMostrado;
  final bool nuevo;
  final bool esSuperRecibido;

  const TarjetaUsuario({
    super.key,
    required this.usuario,
    this.imagenOverlay,
    this.badge,
    this.esquinaDerecha,
    this.onTap,
    this.imagenBorrosa = false,
    this.nombreMostrado,
    this.nuevo = false,
    this.esSuperRecibido = false,
  });

  @override
  Widget build(BuildContext context) {
    final inicial =
        usuario.nombre.isNotEmpty ? usuario.nombre[0].toUpperCase() : '?';
    final enLinea = _estaEnLinea(usuario);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: esSuperRecibido
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 3,
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: esSuperRecibido
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.55)
                              : Colors.black.withValues(alpha: 0.12),
                          blurRadius: esSuperRecibido ? 16 : 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
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
                            if (fotosParaMostrar(usuario).isNotEmpty)
                              imagenBorrosa
                                  ? ImagenDifuminada(
                                      ruta: fotosParaMostrar(usuario).first,
                                      sigma: 20,
                                      fit: BoxFit.cover,
                                    )
                                  : imagenFoto(fotosParaMostrar(usuario).first,
                                      fit: BoxFit.cover),
                            if (imagenOverlay != null) imagenOverlay!,
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (badge != null)
                    Positioned(top: 6, right: 6, child: badge!),
                  if (nuevo)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Nuevo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
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
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (usuario.verificadoStatus)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(Icons.verified,
                                  color: Colors.blueAccent, size: 16),
                            ),
                          Flexible(
                            child: Text(
                              nombreMostrado ??
                                  (usuario.ocultarEdad
                                      ? usuario.nombre
                                      : '${usuario.nombre}, ${usuario.edad}'),
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
                              color: enLinea
                                  ? const Color(0xFF4CD964)
                                  : Colors.grey[400],
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
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

  bool _estaEnLinea(Usuario usuario) {
    if (usuario.ocultarEnLinea) return false;
    final conexion = usuario.ultimaConexion;
    if (conexion == null) return false;
    return DateTime.now().difference(conexion).inMinutes < 5;
  }
}
