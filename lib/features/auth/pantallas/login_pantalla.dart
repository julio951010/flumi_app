import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/auth_service.dart';
import '../../../core/servicios/notificacion_servicio.dart';

class LoginPantalla extends StatefulWidget {
  final AuthService authService;
  final VoidCallback onRegistro;
  final VoidCallback onOlvide;
  final VoidCallback onExito;

  const LoginPantalla({
    super.key,
    required this.authService,
    required this.onRegistro,
    required this.onOlvide,
    required this.onExito,
  });

  @override
  State<LoginPantalla> createState() => _LoginPantallaState();
}

class _LoginPantallaState extends State<LoginPantalla> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _cargando = false;
  bool _verPassword = false;
  bool _recordar = false;

  @override
  void initState() {
    super.initState();
    _cargarRecordado();
  }

  Future<void> _cargarRecordado() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email_recordado') ?? '';
    if (email.isNotEmpty) {
      setState(() {
        _emailCtrl.text = email;
        _recordar = true;
      });
    }
  }

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await widget.authService.iniciarSesion(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      final prefs = await SharedPreferences.getInstance();
      if (_recordar) {
        await prefs.setString('email_recordado', _emailCtrl.text.trim());
      } else {
        await prefs.remove('email_recordado');
      }

      widget.onExito();
    } catch (e) {
      if (!mounted) return;
      NotificacionServicio.alerta(context, e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;
    final esOscuro = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          constraints: const BoxConstraints(maxWidth: 380),
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Iniciar Sesión',
                        style: TextStyle(
                          color: primario,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _CampoAuth(
                        label: 'Correo electrónico',
                        icono: Icons.email_outlined,
                        tipo: TextInputType.emailAddress,
                        controlador: _emailCtrl,
                        esOscuro: esOscuro,
                        colorPrimario: primario,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim())) {
                            return 'Correo inválido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _CampoAuth(
                        label: 'Contraseña',
                        icono: Icons.lock_outlined,
                        tipo: TextInputType.text,
                        controlador: _passwordCtrl,
                        esOscuro: esOscuro,
                        esPassword: true,
                        verPassword: _verPassword,
                        onCambioVisibilidad: () =>
                            setState(() => _verPassword = !_verPassword),
                        colorPrimario: primario,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
                          if (v.length < 6) return 'Mínimo 6 caracteres';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => setState(() => _recordar = !_recordar),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: Checkbox(
                                value: _recordar,
                                onChanged: (v) =>
                                    setState(() => _recordar = v!),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                side: BorderSide(color: primario),
                                fillColor: WidgetStateProperty.all(
                                  primario,
                                ),
                                checkColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Recordar contraseña',
                            style: TextStyle(
                              color: primario,
                              fontSize: 13,
                            ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: widget.onOlvide,
                            child: Text(
                              '¿Olvidaste tu contraseña?',
                              style: TextStyle(
                                color: primario,
                                fontSize: 13,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _cargando ? null : _iniciarSesion,
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
                                  'Iniciar Sesión',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: widget.onRegistro,
                        child: Text.rich(
                          TextSpan(
                            text: '¿No tienes cuenta? ',
                            style: TextStyle(
                              color: primario.withOpacity(0.85),
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text: 'Regístrate',
                                style: TextStyle(
                                  color: primario,
                                  fontSize: 14,
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

class _CampoAuth extends StatelessWidget {
  final String label;
  final IconData icono;
  final TextInputType tipo;
  final TextEditingController? controlador;
  final bool esOscuro;
  final bool esPassword;
  final bool verPassword;
  final VoidCallback? onCambioVisibilidad;
  final Color colorPrimario;
  final String? Function(String?)? validator;

  const _CampoAuth({
    required this.label,
    required this.icono,
    required this.tipo,
    this.controlador,
    required this.esOscuro,
    required this.colorPrimario,
    this.esPassword = false,
    this.verPassword = false,
    this.onCambioVisibilidad,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextFormField(
        controller: controlador,
        keyboardType: tipo,
        obscureText: esPassword && !verPassword,
        validator: validator,
        style: TextStyle(
          color: esOscuro ? Colors.white : Colors.black87,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withOpacity(0.9),
          labelText: label,
          labelStyle: TextStyle(
            color: esOscuro ? Colors.white70 : Colors.black45,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            icono,
            color: colorPrimario.withOpacity(0.7),
            size: 20,
          ),
          suffixIcon: esPassword
              ? IconButton(
                  icon: Icon(
                    verPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: esOscuro ? Colors.white70 : Colors.black45,
                    size: 20,
                  ),
                  onPressed: onCambioVisibilidad,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: colorPrimario,
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
