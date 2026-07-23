import 'package:flutter/material.dart';

enum TipoNotificacion { alerta, advertencia, exito }

class NotificacionServicio {
  static OverlayEntry? _entry;

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
        mensaje: mensaje,
        duracion: duracion,
        onDismiss: _ocultar,
      ),
    );
    overlay.insert(_entry!);
  }

  static void _ocultar() {
    _entry?.remove();
    _entry = null;
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

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);

    _ctrl.forward();
    Future.delayed(widget.duracion, _cerrar);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _cerrar() {
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
