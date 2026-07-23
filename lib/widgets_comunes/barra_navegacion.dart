import 'package:flutter/material.dart';

class BarraNavegacion extends StatelessWidget {
  final int indiceActual;
  final ValueChanged<int> onCambio;

  const BarraNavegacion({
    super.key,
    required this.indiceActual,
    required this.onCambio,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: indiceActual,
      onDestinationSelected: onCambio,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.explore_outlined),
          selectedIcon: Icon(Icons.explore),
          label: 'Descubrir',
        ),
        NavigationDestination(
          icon: Icon(Icons.favorite_outline),
          selectedIcon: Icon(Icons.favorite),
          label: 'Matches',
        ),
        NavigationDestination(
          icon: Icon(Icons.chat_outlined),
          selectedIcon: Icon(Icons.chat),
          label: 'Chat',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ],
    );
  }
}
