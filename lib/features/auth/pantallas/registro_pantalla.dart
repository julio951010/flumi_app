import 'dart:ui';

import 'package:flutter/material.dart';
import '../../auth/auth_service.dart';

class RegistroPantalla extends StatefulWidget {
  final AuthService authService;
  final VoidCallback onLogin;
  final VoidCallback onExito;
  final VoidCallback? onCodigoVerificacion;

  const RegistroPantalla({
    super.key,
    required this.authService,
    required this.onLogin,
    required this.onExito,
    this.onCodigoVerificacion,
  });

  @override
  State<RegistroPantalla> createState() => _RegistroPantallaState();
}

class _RegistroPantallaState extends State<RegistroPantalla> {
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _cargando = false;
  bool _verPassword = false;
  bool _verConfirmar = false;
  bool _aceptaTerminos = false;

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      final respuesta = await widget.authService.registrar(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        nombre: _nombreCtrl.text.trim(),
      );

      if (!mounted) return;

      if (respuesta.session == null) {
        widget.onLogin();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Revisa tu correo para confirmar la cuenta.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmarCtrl.dispose();
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
                        'Crear Cuenta',
                        style: TextStyle(
                          color: primario,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _CampoAuth(
                        label: 'Nombre',
                        icono: Icons.person_outlined,
                        tipo: TextInputType.text,
                        controlador: _nombreCtrl,
                        esOscuro: esOscuro,
                        colorPrimario: primario,
                      ),
                      const SizedBox(height: 12),
                      _CampoAuth(
                        label: 'Correo electrónico',
                        icono: Icons.email_outlined,
                        tipo: TextInputType.emailAddress,
                        controlador: _emailCtrl,
                        esOscuro: esOscuro,
                        colorPrimario: primario,
                      ),
                      const SizedBox(height: 12),
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
                      ),
                      const SizedBox(height: 12),
                      _CampoAuth(
                        label: 'Confirmar contraseña',
                        icono: Icons.lock_outlined,
                        tipo: TextInputType.text,
                        controlador: _confirmarCtrl,
                        esOscuro: esOscuro,
                        esPassword: true,
                        verPassword: _verConfirmar,
                        onCambioVisibilidad: () =>
                            setState(() => _verConfirmar = !_verConfirmar),
                        colorPrimario: primario,
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => setState(
                            () => _aceptaTerminos = !_aceptaTerminos),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: Checkbox(
                                value: _aceptaTerminos,
                                onChanged: (v) => setState(
                                    () => _aceptaTerminos = v!),
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
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  style: TextStyle(
                                    color: primario,
                                    fontSize: 13,
                                  ),
                                  children: [
                                    const TextSpan(text: 'Acepto los '),
                                    TextSpan(
                                      text: 'términos y condiciones',
                                      style: TextStyle(
                                        decoration:
                                            TextDecoration.underline,
                                      ),
                                    ),
                                    const TextSpan(text: ' y '),
                                    TextSpan(
                                      text: 'políticas de privacidad',
                                      style: TextStyle(
                                        decoration:
                                            TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _cargando || !_aceptaTerminos
                              ? null
                              : _registrar,
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
                                  'Crear Cuenta',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: widget.onLogin,
                        child: Text.rich(
                          TextSpan(
                            text: '¿Ya tienes cuenta? ',
                            style: TextStyle(
                              color: primario.withOpacity(0.85),
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text: 'Inicia sesión',
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
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextFormField(
        controller: controlador,
        keyboardType: tipo,
        obscureText: esPassword && !verPassword,
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
