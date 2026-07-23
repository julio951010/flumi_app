import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';

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
    final primario = Theme.of(context).colorScheme.primary;

    return CurvedNavigationBar(
      index: indiceActual,
      onTap: onCambio,
      color: Colors.white,
      buttonBackgroundColor: primario,
      backgroundColor: primario,
      animationCurve: Curves.easeInOut,
      animationDuration: const Duration(milliseconds: 300),
      height: 60,
      items: <Widget>[
        Icon(Icons.fmd_good_outlined, size: 26, color: indiceActual == 0 ? Colors.white : Colors.grey),
        Icon(Icons.switch_account_outlined, size: 26, color: indiceActual == 1 ? Colors.white : Colors.grey),
        Icon(Icons.favorite_outline, size: 26, color: indiceActual == 2 ? Colors.white : Colors.grey),
        Icon(Icons.chat_outlined, size: 26, color: indiceActual == 3 ? Colors.white : Colors.grey),
        Icon(Icons.person_outline, size: 26, color: indiceActual == 4 ? Colors.white : Colors.grey),
      ],
    );
  }
}
