import 'dart:async';

import 'package:flutter/material.dart';

enum TipoNotificacion { alerta, advertencia, exito }

class NotificacionServicio {
  static OverlayEntry? _entry;
  static OverlayEntry? _burbujaEntry;

  static void mostrar(
    BuildContext context, {
    required TipoNotificacion tipo,
    required String mensaje,
    Duration duracion = const Duration(seconds: 4),
  }) {
    _ocultar();

    final overlay = Overlay.of(context);
    _entry = OverlayEntry(
      builder: (_) => _NotificacionWidget(
        tipo: tipo,
        mensaje: sanear(mensaje),
        duracion: duracion,
        onDismiss: _ocultar,
      ),
    );
    overlay.insert(_entry!);
  }

  /// Burbuja con LayerLink (CompositedTransformFollower): posicionamiento
  /// 100% fiable, nunca se sale de pantalla. Preferida para el botón
  /// Deshacer.
  static void mostrarBurbujaConLink(
    BuildContext context, {
    required LayerLink link,
    required String mensaje,
    Duration duracion = const Duration(seconds: 3),
  }) {
    try {
      _ocultarBurbuja();
      final overlay = Overlay.maybeOf(context);
      if (overlay == null) {
        advertencia(context, mensaje);
        return;
      }
      _burbujaEntry = OverlayEntry(
        builder: (_) => _BurbujaFollowerWidget(
          link: link,
          mensaje: sanear(mensaje),
          duracion: duracion,
          onDismiss: _ocultarBurbuja,
        ),
      );
      overlay.insert(_burbujaEntry!);
    } catch (_) {
      try {
        advertencia(context, mensaje);
      } catch (_) {}
    }
  }

  /// Burbuja flotante anclada debajo de [anchorKey] con flechita apuntando
  /// al ancla. Usada para "Te has perdido un match" apuntando al botón
  /// Deshacer. Si el ancla no está montada hace fallback al banner superior.
  static void mostrarBurbujaAnclada(
    BuildContext context, {
    required GlobalKey anchorKey,
    required String mensaje,
    Duration duracion = const Duration(seconds: 3),
  }) {
    // Difiere al siguiente frame para garantizar que el botón ya esté
    // layouteado y que el Overlay esté disponible (evita "No Overlay widget
    // found" al llamar desde initState / callbacks muy tempranos).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _ocultarBurbuja();
        final ctx = anchorKey.currentContext;
        if (ctx == null) {
          advertencia(context, mensaje);
          return;
        }
        final render = ctx.findRenderObject() as RenderBox?;
        if (render == null || !render.hasSize) {
          advertencia(context, mensaje);
          return;
        }
        final anchorPos = render.localToGlobal(Offset.zero);
        final anchorSize = render.size;
        final anchorRect = anchorPos & anchorSize;
        final overlay = Overlay.maybeOf(context);
        if (overlay == null) {
          advertencia(context, mensaje);
          return;
        }
        _burbujaEntry = OverlayEntry(
          builder: (_) => _BurbujaAncladaWidget(
            anchorRect: anchorRect,
            mensaje: sanear(mensaje),
            duracion: duracion,
            onDismiss: _ocultarBurbuja,
          ),
        );
        overlay.insert(_burbujaEntry!);
      } catch (_) {
        try {
          advertencia(context, mensaje);
        } catch (_) {}
      }
    });
  }

  static void _ocultarBurbuja() {
    _burbujaEntry?.remove();
    _burbujaEntry = null;
  }

  /// Convierte cualquier error técnico en un mensaje entendible.
  /// Los mensajes ya curados (terminan en llamada a la acción) pasan intactos.
  static String sanear(Object? errorOuMensaje) {
    final crudo = errorOuMensaje?.toString().trim() ?? '';
    if (crudo.isEmpty) {
      return 'Ocurrió un error inesperado. Intenta de nuevo.';
    }
    var t = crudo;
    // 1. Extrae `message:` de AuthApiException/AuthException/PostgrestException(...)
    if (t.contains('Exception(')) {
      final m = RegExp(r'message:\s*([^,]+?)(,|\}|\)|$)').firstMatch(t);
      final extraido = m?.group(1)?.trim() ?? '';
      if (extraido.isNotEmpty) t = extraido;
    }
    // 2. Quita prefijos tipo "Exception:", "SocketException:", "XxxException(...):"
    t = t
        .replaceAll(
            RegExp(r'^\s*(?:\w*Exception(?:\([^)]*\))?\s*:\s*)+'), '')
        .trim();
    if (t.isEmpty) return 'Ocurrió un error inesperado. Intenta de nuevo.';
    final low = t.toLowerCase();
    // 3. Mensajes ya curados: no tocarlos.
    if (low.contains('intenta de nuevo') ||
        low.contains('inténtalo de nuevo') ||
        low.contains('revisa tu')) {
      return t;
    }
    // 4. Mapeo técnico → español entendible.
    bool tiene(List<String> claves) => claves.any(low.contains);
    if (tiene(const [
      'socketexception',
      'failed host lookup',
      'no address associated',
      'network is unreachable',
      'connection refused',
      'connection timed out',
      'connection reset',
      'connection failed',
      'network error',
      'no route to host',
      'sin conexión',
      'no hay conexión'
    ])) {
      return 'Sin conexión. Verifica tu internet e inténtalo de nuevo.';
    }
    if (tiene(const [
      'rate limit',
      'too many requests',
      'over_email_send_rate_limit',
      '429'
    ])) {
      return 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';
    }
    if (tiene(const ['invalid login', 'invalid credentials', 'wrong password'])) {
      return 'Correo o contraseña incorrectos. Verifica tus datos.';
    }
    if (tiene(const ['email not confirmed', 'email_not_confirmed'])) {
      return 'Debes verificar tu correo antes de entrar. Revisa tu bandeja e ingresa el código.';
    }
    if (tiene(const ['user already registered', 'already registered', 'already exists'])) {
      return 'El correo ya está registrado. ¿Quieres iniciar sesión?';
    }
    if (tiene(const ['same_password']) ||
        (low.contains('different from') && low.contains('password'))) {
      return 'La nueva contraseña debe ser diferente a la anterior.';
    }
    if (tiene(const ['token has expired', 'token expired', 'invalid token', 'otp expired', 'invalid otp', 'otp_disabled'])) {
      return 'El código es inválido o expiró. Solicita uno nuevo.';
    }
    if (tiene(const [
      'jwt expired',
      'invalid jwt',
      'invalid signature',
      'session expired',
      'refresh token'
    ])) {
      return 'Tu sesión expiró. Inicia sesión de nuevo.';
    }
    if (tiene(const [
      'violates row-level security',
      'row-level security',
      'permission denied',
      '42501',
      'not authorized',
      'unauthorized',
      '401'
    ])) {
      return 'No tienes permiso para realizar esta acción.';
    }
    // 5. Recorte de seguridad: nada gigante ni con restos técnicos.
    if (t.length > 220) return '${t.substring(0, 217).trim()}…';
    return t;
  }

  static void _ocultar() {
    _entry?.remove();
    _entry = null;
  }

  /// Alias para compatibilidad: oculta cualquier burbuja si existe.
  static void ocultarTodo() {
    _ocultar();
    _ocultarBurbuja();
  }

  static void alerta(BuildContext context, String mensaje) {
    mostrar(context, tipo: TipoNotificacion.alerta, mensaje: mensaje);
  }

  static void advertencia(BuildContext context, String mensaje) {
    mostrar(context, tipo: TipoNotificacion.advertencia, mensaje: mensaje);
  }

  static void exito(BuildContext context, String mensaje) {
    mostrar(context, tipo: TipoNotificacion.exito, mensaje: mensaje);
  }
}

class _NotificacionWidget extends StatefulWidget {
  final TipoNotificacion tipo;
  final String mensaje;
  final Duration duracion;
  final VoidCallback onDismiss;

  const _NotificacionWidget({
    required this.tipo,
    required this.mensaje,
    required this.duracion,
    required this.onDismiss,
  });

  @override
  State<_NotificacionWidget> createState() => _NotificacionWidgetState();
}

class _NotificacionWidgetState extends State<_NotificacionWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);

    _ctrl.forward();
    _timer = Timer(widget.duracion, _cerrar);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _ctrl.dispose();
    super.dispose();
  }

  void _cerrar() {
    if (!mounted) return;
    _ctrl.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    final colores = _colores(widget.tipo);
    final icono = _icono(widget.tipo);

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Positioned(
          top: safeTop + 8,
          left: 16,
          right: 16,
          child: Opacity(
            opacity: _anim.value,
            child: Transform.translate(
              offset: Offset(0, -20 * (1 - _anim.value)),
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(14),
                color: colores.bg,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(icono, color: Colors.white, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.mensaje,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _cerrar,
                        child: const Icon(Icons.close, color: Colors.white70, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  ({Color bg, Color fg}) _colores(TipoNotificacion tipo) {
    switch (tipo) {
      case TipoNotificacion.alerta:
        return (bg: Color(0xFFE53935), fg: Color(0xFFEF5350));
      case TipoNotificacion.advertencia:
        return (bg: Color(0xFFFB8C00), fg: Color(0xFFFFA726));
      case TipoNotificacion.exito:
        return (bg: Color(0xFF43A047), fg: Color(0xFF66BB6A));
    }
  }

  IconData _icono(TipoNotificacion tipo) {
    switch (tipo) {
      case TipoNotificacion.alerta:
        return Icons.error_outline;
      case TipoNotificacion.advertencia:
        return Icons.warning_amber_outlined;
      case TipoNotificacion.exito:
        return Icons.check_circle_outline;
    }
  }
}

class _BurbujaAncladaWidget extends StatefulWidget {
  final Rect anchorRect;
  final String mensaje;
  final Duration duracion;
  final VoidCallback onDismiss;

  const _BurbujaAncladaWidget({
    required this.anchorRect,
    required this.mensaje,
    required this.duracion,
    required this.onDismiss,
  });

  @override
  State<_BurbujaAncladaWidget> createState() => _BurbujaAncladaWidgetState();
}

class _BurbujaAncladaWidgetState extends State<_BurbujaAncladaWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  Timer? _timer;

  static const _bubbleWidth = 210.0;
  static const _arrowH = 8.0;
  static const _arrowW = 14.0;
  static const _gap = 6.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    // easeOutBack rebasa 1.0 (1.27) → rompería Opacity(0..1). Usa clamp
    // vía Tween o curva sin overshoot para la opacidad; la escala sí puede
    // rebotar, así que la dejamos con back pero clampeamos la opacidad.
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _ctrl.forward();
    _timer = Timer(widget.duracion, _cerrar);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _cerrar() {
    if (!mounted) return;
    _ctrl.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenW = mq.size.width;
    final screenH = mq.size.height;
    // Ancho responsivo: nunca se sale de pantalla (12px margen cada lado).
    final bubbleWidth = (_bubbleWidth).clamp(0.0, screenW - 24.0);
    final anchorCenterX = widget.anchorRect.center.dx;
    var top = widget.anchorRect.bottom + _gap + _arrowH;
    const estBubbleH = 56.0; // alto aproximado burbuja+flecha
    // Si no cabe abajo (pantalla pequeña), flip arriba del botón.
    var flipUp = false;
    if (top + estBubbleH > screenH - 12) {
      top = widget.anchorRect.top - _gap - _arrowH - 44;
      flipUp = true;
    }

    // Alineación: si el ancla está en la mitad derecha (botón Deshacer
    // siempre a la derecha) alineamos la burbuja al borde derecho para
    // que nunca se corte por el margen. Si está centrada, la centramos.
    double left;
    if (anchorCenterX > screenW * 0.55) {
      left = screenW - bubbleWidth - 12.0; // pegada a derecha
    } else {
      left = anchorCenterX - bubbleWidth / 2;
      final maxLeft = (screenW - bubbleWidth - 12.0).clamp(12.0, screenW);
      left = left.clamp(12.0, maxLeft);
    }

    // Posición de la flecha relativa a la burbuja.
    var arrowLeft = anchorCenterX - left - _arrowW / 2;
    arrowLeft = arrowLeft.clamp(8.0, bubbleWidth - 8.0 - _arrowW);

    const bg = Color(0xFFFB8C00);

    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) {
          return SizedBox.expand(
            child: Stack(
              children: [
                // Tap fuera cierra (detrás de la burbuja).
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _cerrar,
                    child: const SizedBox.expand(),
                  ),
                ),
                Positioned(
                  left: left,
                  top: top,
                  child: Opacity(
                    opacity: _anim.value.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(
                          0, (flipUp ? 6 : -6) * (1 - _anim.value.clamp(0.0, 1.0))),
                      child: Transform.scale(
                        scale: (0.92 + 0.08 * _anim.value).clamp(0.92, 1.05),
                        alignment:
                            flipUp ? Alignment.bottomCenter : Alignment.topCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!flipUp)
                              Padding(
                                padding: EdgeInsets.only(left: arrowLeft),
                                child: CustomPaint(
                                  size: const Size(_arrowW, _arrowH),
                                  painter: _TrianglePainter(
                                      color: bg, invert: false),
                                ),
                              ),
                            Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(14),
                              color: bg,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                child: SizedBox(
                                  width: bubbleWidth - 28,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.favorite,
                                          color: Colors.white, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          widget.mensaje,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: _cerrar,
                                        child: const Padding(
                                          padding: EdgeInsets.only(left: 8),
                                          child: Icon(Icons.close,
                                              color: Colors.white70, size: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (flipUp)
                              Padding(
                                padding: EdgeInsets.only(left: arrowLeft),
                                child: CustomPaint(
                                  size: const Size(_arrowW, _arrowH),
                                  painter: _TrianglePainter(
                                      color: bg, invert: true),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BurbujaFollowerWidget extends StatefulWidget {
  final LayerLink link;
  final String mensaje;
  final Duration duracion;
  final VoidCallback onDismiss;

  const _BurbujaFollowerWidget({
    required this.link,
    required this.mensaje,
    required this.duracion,
    required this.onDismiss,
  });

  @override
  State<_BurbujaFollowerWidget> createState() => _BurbujaFollowerWidgetState();
}

class _BurbujaFollowerWidgetState extends State<_BurbujaFollowerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _ctrl.forward();
    _timer = Timer(widget.duracion, _cerrar);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _cerrar() {
    if (!mounted) return;
    _ctrl.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenW = mq.size.width;
    // Ancho para una sola línea: "Te has perdido un match" ≈ 175px + paddings.
    // Usa ancho intrínseco limitado por pantalla; no fuerza wrap.
    const rawW = 220.0;
    final bubbleW = rawW.clamp(0.0, screenW - 24.0);
    const bg = Color(0xFFFB8C00);
    const arrowW = 14.0;
    const arrowH = 6.0; // más pegado al botón
    // Calcula offset horizontal para que la burbuja nunca se salga: si el
    // follower centrado se desborda por derecha/izquierda, lo desplazamos.
    // Necesitamos la posición global del target; la estimamos vía link.
    // Fallback: sin corrección si no hay contexto aún.
    double offsetX = 0;
    try {
      final _ = widget.link.leaderSize; // null si no está montado aún
      // Usamos el rect del follower vía overlay: aproximamos con screen center;
      // corrección real se hace estimando overflow a partir de screenW.
      // Como el botón está a la derecha, casi siempre hay overflow derecho.
      // Calcula desborde derecho del bubble centrado:
      // follower centra -> left = anchorX - bubbleW/2, right = left+bubbleW.
      // Si right > screenW-12, offsetX = (screenW-12 - bubbleW/2) - anchorX.
      // Necesitamos anchorX: lo obtenemos del LayerLink vía contexto del
      // CompositedTransformTarget (no expuesto), así que usamos heurística:
      // el botón Deshacer está a ~48px del borde derecho + filtros (40px) →
      // anchorX ≈ screenW - 70. Si bubbleW=220, left centrado ≈ screenW-180,
      // right ≈ screenW+40 → desborda 40. Offset ≈ -40.
      // Aplicamos un offset fijo seguro para derecha.
      const estAnchorFromRight = 70.0;
      final estAnchorX = screenW - estAnchorFromRight;
      final estRight = estAnchorX + bubbleW / 2;
      final overflow = estRight - (screenW - 12);
      if (overflow > 0) offsetX = -overflow - 4;
    } catch (_) {}

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _cerrar,
              child: const SizedBox.expand(),
            ),
          ),
          // Follower anclado al botón, pegado (gap mínimo) y corregido en X
          // para quedar 100% dentro de pantalla.
          CompositedTransformFollower(
            link: widget.link,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomCenter,
            followerAnchor: Alignment.topCenter,
            offset: Offset(offsetX, 4),
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) {
                // Flecha integrada al bubble como un solo path: el pintor dibuja
                // rect redondeado + triángulo arriba en el mismo shape, con una
                // sola sombra → parece una sola pieza.
                final arrowCenter = bubbleW / 2 - offsetX;
                return Opacity(
                  opacity: _anim.value.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, -6 * (1 - _anim.value.clamp(0.0, 1.0))),
                    child: Transform.scale(
                      scale: (0.92 + 0.08 * _anim.value).clamp(0.92, 1.05),
                      alignment: Alignment.topCenter,
                      child: CustomPaint(
                        painter: _BubblePainter(
                          color: bg,
                          arrowCenter: arrowCenter.clamp(
                              18.0, bubbleW - 18.0),
                          arrowW: arrowW,
                          arrowH: arrowH,
                          radius: 14,
                        ),
                        child: Padding(
                          // arrowH arriba para no tapar la flecha, + padding
                          // interno del bubble
                          padding: EdgeInsets.fromLTRB(
                              14, arrowH + 9, 14, 9),
                          child: SizedBox(
                            width: bubbleW - 28,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.mensaje,
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.visible,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _cerrar,
                                  child: const Padding(
                                    padding: EdgeInsets.only(left: 10),
                                    child: Icon(Icons.close,
                                        color: Colors.white70, size: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Pintor de burbuja + flecha como una sola pieza (sin costura).
class _BubblePainter extends CustomPainter {
  final Color color;
  final double arrowCenter; // X del centro de la flecha dentro del bubble
  final double arrowW;
  final double arrowH;
  final double radius;

  const _BubblePainter({
    required this.color,
    required this.arrowCenter,
    required this.arrowW,
    required this.arrowH,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final w = size.width;
    final h = size.height;
    final r = radius;
    final aw = arrowW;
    final ah = arrowH;
    final ac = arrowCenter.clamp(aw / 2 + r, w - aw / 2 - r);

    final path = Path()
      // Empieza en top-left con radio, a la altura de la base de la flecha
      ..moveTo(r, ah)
      // Línea hasta la base izquierda de la flecha
      ..lineTo(ac - aw / 2, ah)
      // Flecha
      ..lineTo(ac, 0)
      ..lineTo(ac + aw / 2, ah)
      // Línea hasta top-right
      ..lineTo(w - r, ah)
      ..arcToPoint(Offset(w, ah + r), radius: Radius.circular(r))
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: Radius.circular(r))
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: Radius.circular(r))
      ..lineTo(0, ah + r)
      ..arcToPoint(Offset(r, ah), radius: Radius.circular(r))
      ..close();

    canvas.drawShadow(path, Colors.black26, 6, false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BubblePainter old) =>
      old.color != color ||
      old.arrowCenter != arrowCenter ||
      old.arrowW != arrowW ||
      old.arrowH != arrowH ||
      old.radius != radius;
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  final bool invert;
  const _TrianglePainter({required this.color, this.invert = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    if (invert) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0)
        ..close();
    } else {
      path
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..close();
    }
    canvas.drawShadow(path, Colors.black26, 2, false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.invert != invert;
}
