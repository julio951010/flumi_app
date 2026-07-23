import 'package:flutter/material.dart';

class EncabezadoPagina extends StatelessWidget {
  final String titulo;

  const EncabezadoPagina({super.key, required this.titulo});

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Image.asset('assets/images/flumi_logo.png', height: 36),
          const SizedBox(width: 10),
          Text(
            titulo,
            style: TextStyle(
              color: primario,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
