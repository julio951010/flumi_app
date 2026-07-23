import 'package:flutter/material.dart';
import '../../../core/base_datos_local/database.dart';
import '../matches_repositorio.dart';

class MatchesPantalla extends StatelessWidget {
  final MatchesRepositorio repositorio;

  const MatchesPantalla({super.key, required this.repositorio});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Matche>>(
      stream: repositorio.observarMatches(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final matches = snapshot.data ?? [];
        if (matches.isEmpty) {
          return const Center(child: Text('Aún no tienes matches'));
        }
        return ListView.builder(
          itemCount: matches.length,
          itemBuilder: (context, index) {
            final match = matches[index];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text('Match con ${match.usuarioBId}'),
              subtitle: match.ultimoMensajePreview != null
                  ? Text(match.ultimoMensajePreview!)
                  : null,
            );
          },
        );
      },
    );
  }
}
