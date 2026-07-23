import 'package:flutter/material.dart';
import '../../../core/base_datos_local/database.dart';
import '../../../core/estilos/tema.dart';
import '../../auth/auth_service.dart';
import '../perfil_repositorio.dart';
import 'editar_perfil_pantalla.dart';

class PerfilPantalla extends StatelessWidget {
  final PerfilRepositorio repositorio;

  const PerfilPantalla({super.key, required this.repositorio});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return FutureBuilder<Usuario?>(
      future: repositorio.obtenerPerfilPropio(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final perfil = snapshot.data;
        if (perfil == null) {
          return _SinPerfil(authService: authService);
        }

        return _PerfilCompleto(
          perfil: perfil,
          authService: authService,
          repositorio: repositorio,
        );
      },
    );
  }
}

class _SinPerfil extends StatelessWidget {
  final AuthService authService;

  const _SinPerfil({required this.authService});

  @override
  Widget build(BuildContext context) {
    final userEmail = authService.usuarioActual?.email ?? '';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_circle, size: 100, color: FlumiTema.colorPrimario),
          const SizedBox(height: 16),
          Text(userEmail, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          const Text('Perfil no disponible'),
          const SizedBox(height: 24),
          _BotonCerrarSesion(authService: authService),
        ],
      ),
    );
  }
}

class _PerfilCompleto extends StatelessWidget {
  final Usuario perfil;
  final AuthService authService;
  final PerfilRepositorio repositorio;

  const _PerfilCompleto({
    required this.perfil,
    required this.authService,
    required this.repositorio,
  });

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;
    final userEmail = authService.usuarioActual?.email ?? '';
    final fotoUrl = perfil.fotosLocalesRutas.isNotEmpty
        ? perfil.fotosLocalesRutas.first
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        children: [
          const SizedBox(height: 8),
          CircleAvatar(
            radius: 55,
            backgroundColor: primario.withOpacity(0.15),
            backgroundImage: fotoUrl != null ? AssetImage(fotoUrl) : null,
            child: fotoUrl == null
                ? Icon(Icons.person, size: 60, color: primario)
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            '${perfil.nombre}, ${perfil.edad}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(userEmail, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Etiqueta(texto: perfil.genero, icono: Icons.wc),
              _Etiqueta(texto: 'Busca: ${perfil.buscaGenero}', icono: Icons.favorite_outline),
              _Etiqueta(
                texto: '${perfil.preferenciaEdadMin}-${perfil.preferenciaEdadMax} años',
                icono: Icons.date_range,
              ),
              if (perfil.verificadoStatus)
                const _Etiqueta(texto: 'Verificado', icono: Icons.verified),
            ],
          ),
          if (perfil.biografia.isNotEmpty) ...[
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Biografía', style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 6),
            Text(perfil.biografia, style: const TextStyle(fontSize: 15, height: 1.4)),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EditarPerfilPantalla(
                      perfil: perfil,
                      repositorio: repositorio,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.edit, size: 20),
              label: const Text('Editar perfil', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primario,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _BotonCerrarSesion(authService: authService),
        ],
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final IconData icono;

  const _Etiqueta({required this.texto, required this.icono});

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: primario.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: primario),
          const SizedBox(width: 6),
          Text(texto, style: TextStyle(fontSize: 13, color: primario, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _BotonCerrarSesion extends StatelessWidget {
  final AuthService authService;

  const _BotonCerrarSesion({required this.authService});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
        onPressed: () async {
          final confirmado = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Cerrar sesión'),
              content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cerrar sesión')),
              ],
            ),
          );
          if (confirmado == true) {
            await authService.cerrarSesion();
          }
        },
        icon: const Icon(Icons.logout, size: 20),
        label: const Text('Cerrar sesión', style: TextStyle(fontSize: 16)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red[400],
          side: BorderSide(color: Colors.red[400]!),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
    );
  }
}
