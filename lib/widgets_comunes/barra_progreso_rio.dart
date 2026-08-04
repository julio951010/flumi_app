import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/estilos/tema.dart';

class BarraProgresoRio extends StatelessWidget {
  final double progreso;
  final double altura;
  const BarraProgresoRio({super.key, required this.progreso, this.altura = 8});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: altura,
      child: CustomPaint(
        painter: _OndaProgresoPainter(progreso: progreso.clamp(0.0, 1.0)),
      ),
    );
  }
}

class _OndaProgresoPainter extends CustomPainter {
  final double progreso;

  _OndaProgresoPainter({required this.progreso});

  static const _ondas = 2;
  static const _amplitud = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final periodo = w / _ondas;
    const puntos = 48;

    Path banda() {
      final path = Path();
      for (var i = 0; i <= puntos; i++) {
        final t = i / puntos;
        final x = t * (w + periodo);
        final y = _amplitud + math.sin(2 * math.pi * t * _ondas) * _amplitud;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      for (var i = puntos; i >= 0; i--) {
        final t = i / puntos;
        final x = t * (w + periodo);
        final y =
            h - _amplitud + math.sin(2 * math.pi * t * _ondas) * _amplitud;
        path.lineTo(x, y);
      }
      path.close();
      return path;
    }

    final p = banda();

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(w * progreso, 0, w, h));
    canvas.drawPath(
        p,
        Paint()
          ..color = Colors.grey.withValues(alpha: 0.45)
          ..style = PaintingStyle.fill);
    canvas.restore();

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, w * progreso, h));
    canvas.drawPath(
        p,
        Paint()
          ..shader = const LinearGradient(
            colors: [FlumiTema.colorPrimario, Colors.lightBlueAccent],
          ).createShader(Rect.fromLTWH(0, 0, w, h)));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OndaProgresoPainter old) => old.progreso != progreso;
}
