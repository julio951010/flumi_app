import 'dart:async';

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
        mensaje: sanear(mensaje),
        duracion: duracion,
        onDismiss: _ocultar,
      ),
    );
    overlay.insert(_entry!);
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
