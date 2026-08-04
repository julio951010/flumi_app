import 'package:flutter/material.dart';

class PersonasBloqueadasPantalla extends StatelessWidget {
  const PersonasBloqueadasPantalla({super.key});

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Personas bloqueadas',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.block_outlined,
                size: 64,
                color: primario.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              const Text(
                'No has bloqueado a nadie',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Las personas que bloquees aparecerán aquí',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
