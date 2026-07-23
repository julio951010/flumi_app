import 'package:flutter/material.dart';

class AnimacionAgua extends StatefulWidget {
  final Color color;

  const AnimacionAgua({super.key, this.color = const Color(0xff3B6ABA)});

  @override
  State<AnimacionAgua> createState() => _AnimacionAguaState();
}

class _AnimacionAguaState extends State<AnimacionAgua>
    with TickerProviderStateMixin {
  late final AnimationController _firstController;
  late final Animation<double> _firstAnimation;

  late final AnimationController _secondController;
  late final Animation<double> _secondAnimation;

  late final AnimationController _thirdController;
  late final Animation<double> _thirdAnimation;

  late final AnimationController _fourthController;
  late final Animation<double> _fourthAnimation;

  void _loop(AnimationController c) {
    if (!mounted) return;
    if (c.status == AnimationStatus.completed) {
      c.reverse();
    } else if (c.status == AnimationStatus.dismissed) {
      c.forward();
    }
  }

  @override
  void initState() {
    super.initState();

    _firstController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
    _firstAnimation = Tween<double>(begin: 2.0, end: 3.5).animate(
        CurvedAnimation(parent: _firstController, curve: Curves.easeInOut))
      ..addListener(() => setState(() {}))
      ..addStatusListener((s) => _loop(_firstController));
    _firstController.forward();

    _secondController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _secondAnimation = Tween<double>(begin: 2.2, end: 4.0).animate(
        CurvedAnimation(parent: _secondController, curve: Curves.easeInOut))
      ..addListener(() => setState(() {}))
      ..addStatusListener((s) => _loop(_secondController));
    _secondController.forward();

    _thirdController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000));
    _thirdAnimation = Tween<double>(begin: 2.5, end: 4.5).animate(
        CurvedAnimation(parent: _thirdController, curve: Curves.easeInOut))
      ..addListener(() => setState(() {}))
      ..addStatusListener((s) => _loop(_thirdController));
    _thirdController.forward();

    _fourthController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _fourthAnimation = Tween<double>(begin: 1.8, end: 3.0).animate(
        CurvedAnimation(parent: _fourthController, curve: Curves.easeInOut))
      ..addListener(() => setState(() {}))
      ..addStatusListener((s) => _loop(_fourthController));
    _fourthController.forward();
  }

  @override
  void dispose() {
    _firstController.dispose();
    _secondController.dispose();
    _thirdController.dispose();
    _fourthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AguaPainter(
        _firstAnimation.value,
        _secondAnimation.value,
        _thirdAnimation.value,
        _fourthAnimation.value,
        widget.color,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _AguaPainter extends CustomPainter {
  final double firstValue;
  final double secondValue;
  final double thirdValue;
  final double fourthValue;
  final Color color;

  _AguaPainter(
    this.firstValue,
    this.secondValue,
    this.thirdValue,
    this.fourthValue,
    this.color,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height / firstValue)
      ..cubicTo(size.width * .4, size.height / secondValue, size.width * .7,
          size.height / thirdValue, size.width, size.height / fourthValue)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AguaPainter oldDelegate) => true;
}
