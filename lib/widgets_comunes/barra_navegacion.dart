import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';

class BarraNavegacion extends StatelessWidget {
  final int indiceActual;
  final ValueChanged<int> onCambio;
  final int meGustaNoLeidas;
  final int chatsNoLeidos;

  const BarraNavegacion({
    super.key,
    required this.indiceActual,
    required this.onCambio,
    this.meGustaNoLeidas = 0,
    this.chatsNoLeidos = 0,
  });

  static const _nombres = [
    'Cerca',
    'Encuentros',
    'Me Gusta',
    'Chats',
    'Perfil',
  ];

  static const _iconos = [
    Icons.fmd_good_outlined,
    Icons.switch_account_outlined,
    Icons.favorite_outline,
    Icons.chat_outlined,
    Icons.person_outline,
  ];

  int _badgeCount(int i) {
    switch (i) {
      case 2: // Me Gusta
        return meGustaNoLeidas;
      case 3: // Chats
        return chatsNoLeidos;
      default:
        return 0;
    }
  }

  Widget _item(int i) {
    final seleccionado = indiceActual == i;
    final badge = _badgeCount(i);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(_iconos[i], size: 26,
                color: seleccionado ? Colors.white : Colors.grey),
            if (badge > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
        if (!seleccionado)
          Text(_nombres[i],
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

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
      items: [
        _item(0),
        _item(1),
        _item(2),
        _item(3),
        _item(4),
      ],
    );
  }
}
