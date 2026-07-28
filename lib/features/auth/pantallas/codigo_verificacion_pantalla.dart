import 'dart:ui';

import 'package:flutter/material.dart';
import '../../auth/auth_service.dart';
import '../../../core/servicios/notificacion_servicio.dart';

class CodigoVerificacionPantalla extends StatefulWidget {
  final AuthService authService;
  final String email;
  final String? password;
  final VoidCallback onExito;
  final VoidCallback onLogin;
  final VoidCallback? onReenviar;

  const CodigoVerificacionPantalla({
    super.key,
    required this.authService,
    required this.email,
    this.password,
    required this.onExito,
    required this.onLogin,
    this.onReenviar,
  });

  @override
  State<CodigoVerificacionPantalla> createState() =>
      _CodigoVerificacionPantallaState();
}

class _CodigoVerificacionPantallaState
    extends State<CodigoVerificacionPantalla> {
  final _codigoCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _cargando = false;

  @override
  void dispose() {
    _codigoCtrl.dispose();
    super.dispose();
  }

  Future<void> _verificar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await widget.authService.verificarOTP(
        email: widget.email,
        token: _codigoCtrl.text.trim(),
      );

      if (widget.password != null) {
        await widget.authService.actualizarPassword(widget.password!);
      }

      if (!mounted) return;
      NotificacionServicio.exito(context, 'Cuenta verificada correctamente.');
      widget.onExito();
    } catch (e) {
      if (!mounted) return;
      NotificacionServicio.alerta(context, e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _reenviar() async {
    setState(() => _cargando = true);
    try {
      await widget.authService.reenviarOTP(email: widget.email);
      if (!mounted) return;
      NotificacionServicio.exito(
        context,
        'Código reenviado. Revisa tu correo.',
      );
    } catch (e) {
      if (!mounted) return;
      NotificacionServicio.alerta(context, e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final ancho = MediaQuery.of(context).size.width;
    final maxCardWidth = ancho > 600 ? 480.0 : 380.0;
    final horizontalMargin = ancho > 600 ? 48.0 : 24.0;

    return Center(
      child: SingleChildScrollView(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
          constraints: BoxConstraints(maxWidth: maxCardWidth),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(15),
            color: Colors.white.withOpacity(0.1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 24,
                ),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Código de Verificación',
                        style: TextStyle(
                          color: primario,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Ingresa el código de 6 dígitos que enviamos a ${widget.email}',
                        style: const TextStyle(fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _codigoCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: esOscuro ? Colors.white : Colors.black87,
                          fontSize: 24,
                          letterSpacing: 8,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().length < 6) {
                            return 'Ingresa el código completo';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.9),
                          labelText: 'Código',
                          labelStyle: TextStyle(
                            color: esOscuro ? Colors.white70 : Colors.black45,
                            fontSize: 14,
                          ),
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: primario.withOpacity(0.3),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: primario.withOpacity(0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: primario,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _cargando ? null : _verificar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primario,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: _cargando
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Verificar',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _cargando ? null : _reenviar,
                        child: Text(
                          'Reenviar código',
                          style: TextStyle(
                            color: primario,
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: widget.onLogin,
                        child: Text.rich(
                          TextSpan(
                            text: 'Volver a ',
                            style: TextStyle(
                              color: primario.withOpacity(0.85),
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text: 'Iniciar Sesión',
                                style: TextStyle(
                                  color: primario,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
