import 'package:flutter/material.dart';
import '../../../core/estilos/tema.dart';
import '../perfil_repositorio.dart';

class PerfilPantalla extends StatelessWidget {
  final PerfilRepositorio repositorio;

  const PerfilPantalla({super.key, required this.repositorio});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_circle, size: 100, color: FlumiTema.colorPrimario),
            const SizedBox(height: 16),
            const Text('Tu perfil se mostrará aquí'),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.edit),
              label: const Text('Editar perfil'),
            ),
          ],
        ),
      ),
    );
  }
}
