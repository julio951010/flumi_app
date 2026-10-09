import 'package:flutter/material.dart';

import '../../../core/base_datos_local/database.dart';
import '../../../core/estilos/tema.dart';
import 'contactar_soporte_pantalla.dart';
import '../../../main.dart'; // database global

class AyudaSoportePantalla extends StatelessWidget {
  /// Se llama cuando el hilo muestra respuestas (para darlas por vistas).
  final VoidCallback? onRespuestasVistas;

  const AyudaSoportePantalla({super.key, this.onRespuestasVistas});

  void _contactarSoporte(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactarSoportePantalla(
          onRespuestasVistas: onRespuestasVistas,
          database: database,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Ayuda y soporte',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          GestureDetector(
            onTap: () => _contactarSoporte(context),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FlumiTema.colorPrimario.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: FlumiTema.colorPrimario,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.support_agent,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('¿Necesitas ayuda?',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        SizedBox(height: 2),
                        Text(
                          'Escríbenos y te respondemos lo antes posible.',
                          style:
                              TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _contactarSoporte(context),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FlumiTema.colorPrimario.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: FlumiTema.colorPrimario,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.lightbulb_outline,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('¿Tienes una idea o sugerencia?',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        SizedBox(height: 2),
                        Text(
                          'Tus comentarios nos ayudan a mejorar y crecer.',
                          style:
                              TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () => _contactarSoporte(context),
              icon: const Icon(Icons.chat_outlined, size: 20),
              label: const Text('Contactar con soporte',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              style: FilledButton.styleFrom(
                backgroundColor: FlumiTema.colorPrimario,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
