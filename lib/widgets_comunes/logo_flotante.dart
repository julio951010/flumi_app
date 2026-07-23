import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Logo de Flumi con flotación propia e independiente — igual que
/// [AnimacionAgua], una vez montado sigue flotando en loop sin
/// importar qué pase alrededor (cambios de página, autenticación, etc.).
///
/// La posición vertical entre "centro de splash" y "header" se
/// controla desde afuera con [progreso] (0 = centro, 1 = header).
/// La flotación se amortigua a medida que [progreso] se acerca a 1,
/// para que el logo quede quieto una vez asentado como encabezado.
class LogoFlotante extends StatefulWidget {
  final double progreso;
  final double topCentro;
  final double topHeader;
  final double tamano;
  final bool visible;
  final String? subtitulo;

  const LogoFlotante({
    super.key,
    required this.progreso,
    required this.topCentro,
    required this.topHeader,
    this.tamano = 100,
    this.visible = true,
    this.subtitulo,
  });

  @override
  State<LogoFlotante> createState() => _LogoFlotanteState();
}

class _LogoFlotanteState extends State<LogoFlotante>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flotarCtrl;
  late final Animation<double> _flotarAnim;

  // Al empezar la transición (progreso pasa de 0 a >0) "congelamos" el
  // valor de flotación de ese instante y lo dejamos decaer a 0 de forma
  // suave junto con el ascenso. Si seguimos leyendo el valor oscilante
  // en vivo mientras el logo sube, el seno se suma al ascenso y se ve
  // como un bamboleo en vez de una subida limpia.
  double _bobCongelado = 0;
  bool _transicionIniciada = false;

  @override
  void initState() {
    super.initState();
    _flotarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _flotarAnim = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _flotarCtrl, curve: Curves.easeInOutSine),
    );
  }

  @override
  void didUpdateWidget(covariant LogoFlotante oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progreso <= 0 && widget.progreso > 0 && !_transicionIniciada) {
      _bobCongelado = _flotarAnim.value;
      _transicionIniciada = true;
    }
    if (widget.progreso <= 0) {
      _transicionIniciada = false;
    }
  }

  @override
  void dispose() {
    _flotarCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // OJO: este widget debe usarse como hijo DIRECTO de un Stack (o
    // envuelto solo por widgets "transparentes" como AnimatedBuilder,
    // que no crean su propio RenderObject). Si se envuelve por fuera
    // con IgnorePointer/Opacity/etc., el Positioned de abajo deja de
    // funcionar y el logo no se mueve.
    return AnimatedBuilder(
      animation: _flotarAnim,
      builder: (context, child) {
        final t = widget.progreso.clamp(0.0, 1.0);
        final top = lerpDouble(widget.topCentro, widget.topHeader, t)!;
        final bobBase = t <= 0 ? _flotarAnim.value : _bobCongelado;
        final bob = bobBase * (1 - t);
        return Positioned(
          top: top + bob,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: widget.visible ? 1 : 0,
              duration: const Duration(milliseconds: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(child: child),
                  if (widget.subtitulo != null)
                    Opacity(
                      opacity: ((t - 0.5) / 0.5).clamp(0.0, 1.0),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          widget.subtitulo!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 18,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
      child: Image.asset(
        'assets/images/flumi_logo_down.png',
        width: widget.tamano,
        height: widget.tamano,
      ),
    );
  }
}