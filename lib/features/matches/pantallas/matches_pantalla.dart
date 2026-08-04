import 'package:flutter/material.dart';
import '../../../core/base_datos_local/database.dart';
import '../../../widgets_comunes/shimmer_caja.dart';
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
          return _esqueleto();
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

  Widget _esqueleto() {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, __) => const Row(
        children: [
          ShimmerCaja(width: 48, height: 48, radius: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerCaja(width: 140, height: 16),
                SizedBox(height: 6),
                ShimmerCaja(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
