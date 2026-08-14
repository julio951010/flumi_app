import 'package:flutter/material.dart';

class ShimmerCaja extends StatefulWidget {
  final double width;
  final double height;
  final double radius;
  const ShimmerCaja({
    super.key,
    this.width = double.infinity,
    this.height = 20,
    this.radius = 8,
  });

  @override
  State<ShimmerCaja> createState() => _ShimmerCajaState();
}

class _ShimmerCajaState extends State<ShimmerCaja>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        // Barrido de brillo: el foco recorre la caja de izquierda a derecha,
        // con el resto del área en gris base (el gradiente rellena toda la
        // caja y los extremos se repiten fuera del segmento).
        final dx = -1.4 + 2.8 * _ctrl.value; // -1.4 .. 1.4
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(dx, 0),
              end: Alignment(dx + 0.9, 0),
              colors: [
                Colors.grey[300]!,
                Colors.grey[100]!,
                Colors.grey[300]!,
              ],
            ),
          ),
        );
      },
    );
  }
}
