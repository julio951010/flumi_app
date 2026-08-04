import 'package:flutter/material.dart';

class EncabezadoPagina extends StatelessWidget {
  final String titulo;
  final Widget? accion;

  const EncabezadoPagina({super.key, required this.titulo, this.accion});

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;
    final paddingTop = MediaQuery.of(context).padding.top;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, paddingTop + 12, 16, 8),
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
          const Spacer(),
          if (accion != null) accion!,
        ],
      ),
    );
  }
}
