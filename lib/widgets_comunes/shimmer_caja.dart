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
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
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
        final opacidad = 0.3 +
            0.2 *
                (_ctrl.value < 0.5
                    ? _ctrl.value * 2
                    : (1 - _ctrl.value) * 2);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.grey[300]!.withValues(alpha: opacidad),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}
