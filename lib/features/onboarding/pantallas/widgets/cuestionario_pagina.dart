import 'package:flutter/material.dart';
import '../../../../widgets_comunes/barra_progreso_rio.dart';

class CuestionarioPagina extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final Widget contenido;
  final double progreso;
  final VoidCallback? onBack;

  const CuestionarioPagina({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.contenido,
    required this.progreso,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.grey),
                onPressed: onBack,
              )
            : null,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: BarraProgresoRio(progreso: progreso),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitulo,
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),
              Expanded(child: contenido),
            ],
          ),
        ),
      ),
    );
  }
}
