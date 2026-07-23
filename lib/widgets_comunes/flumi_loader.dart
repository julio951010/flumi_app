import 'package:flutter/material.dart';
import 'dart:math' as math;

class FlumiLoadingIndicator extends StatefulWidget {
  const FlumiLoadingIndicator({Key? key}) : super(key: key);

  @override
  State<FlumiLoadingIndicator> createState() => _FlumiLoadingIndicatorState();
}

class _FlumiLoadingIndicatorState extends State<FlumiLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 1. Configuramos el controlador de la animación.
    // La animación durará 2 segundos y se repetirá infinitamente.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    // 2. Importante: liberar el controlador al cerrar el widget.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Usamos un AnimatedBuilder para redibujar la pantalla cada vez que
    // el controlador avanza un paso.
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // 3. Definimos el tamaño del área de carga.
        return Center(
          child: SizedBox(
            width: 100, // Ancho del loader
            height: 100, // Alto del loader
            child: CustomPaint(
              // 4. Llamamos a nuestro pintor personalizado.
              painter: _WavePainter(
                animationValue: _controller.value,
                // Usamos el color azul de tu logo (puedes ajustarlo)
                waveColor: const Color(0xFF4FC3F7), 
              ),
            ),
          ),
        );
      },
    );
  }
}

// =======================================================
// CLASE DEL PINTOR PERSONALIZADO (Donde ocurre la magia)
// =======================================================

class _WavePainter extends CustomPainter {
  final double animationValue;
  final Color waveColor;

  _WavePainter({
    required this.animationValue,
    required this.waveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Definimos el pincel (estilo de la línea)
    final paint = Paint()
      ..color = waveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0 // Grosor de las olas
      ..strokeCap = StrokeCap.round;

    // Creamos el camino (la línea) de la ola
    final path = Path();
    
    // Punto de partida de la ola (fuera de la vista a la izquierda)
    // Esto nos permitirá hacer el bucle infinito.
    double startX = -size.width * 2; 
    
    path.moveTo(startX, size.height / 2);

    // Generamos la forma de la ola usando una función seno
    for (double x = 0; x <= size.width * 3; x++) {
      // Frecuencia y amplitud de la ola
      double waveHeight = 10.0; // Altura de la onda
      double frequency = 0.02; // Frecuencia de la onda
      
      // =================================================================
      // AQUÍ ESTÁ LA LÓGICA DE LA ANIMACIÓN
      // Movemos la fase de la onda usando la animationValue (de 0.0 a 1.0).
      // Esto crea la ilusión de que el agua fluye de izquierda a derecha.
      // =================================================================
      double wavePhase = animationValue * size.width * 4; 

      double y = math.sin((x + wavePhase) * frequency) * waveHeight;

      // Añadimos el punto a la línea, centrado verticalmente
      path.lineTo(x, y + size.height / 2);
    }

    // Recortamos el lienzo para que la ola solo se vea dentro del cuadrado
    // de 100x100 que definimos en el widget principal.
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    // Dibujamos la línea principal de la ola
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    // Le decimos a Flutter que vuelva a pintar si el valor de animación cambia.
    return oldDelegate.animationValue != animationValue;
  }
}