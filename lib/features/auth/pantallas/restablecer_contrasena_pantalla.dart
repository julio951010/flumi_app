import 'dart:ui';

import 'package:flutter/material.dart';
import '../../auth/auth_service.dart';

class RestablecerContrasenaPantalla extends StatefulWidget {
  final AuthService authService;
  final VoidCallback onCompletado;

  const RestablecerContrasenaPantalla({
    super.key,
    required this.authService,
    required this.onCompletado,
  });

  @override
  State<RestablecerContrasenaPantalla> createState() =>
      _RestablecerContrasenaPantallaState();
}

class _RestablecerContrasenaPantallaState
    extends State<RestablecerContrasenaPantalla> {
  final _passwordCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _cargando = false;
  bool _verPassword = false;
  bool _verConfirmar = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmarCtrl.dispose();
    super.dispose();
  }

  Future<void> _actualizar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await widget.authService.actualizarPassword(_passwordCtrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contraseña actualizada correctamente.'),
        ),
      );
      widget.onCompletado();
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
                        'Restablecer Contraseña',
                        style: TextStyle(
                          color: primario,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Ingresa tu nueva contraseña.',
                        style: TextStyle(fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      _CampoRestablecer(
                        label: 'Nueva contraseña',
                        icono: Icons.lock_outlined,
                        controlador: _passwordCtrl,
                        esOscuro: esOscuro,
                        esPassword: true,
                        verPassword: _verPassword,
                        onCambioVisibilidad: () =>
                            setState(() => _verPassword = !_verPassword),
                        colorPrimario: primario,
                      ),
                      const SizedBox(height: 12),
                      _CampoRestablecer(
                        label: 'Confirmar contraseña',
                        icono: Icons.lock_outlined,
                        controlador: _confirmarCtrl,
                        esOscuro: esOscuro,
                        esPassword: true,
                        verPassword: _verConfirmar,
                        onCambioVisibilidad: () =>
                            setState(() => _verConfirmar = !_verConfirmar),
                        colorPrimario: primario,
                        validator: (v) {
                          if (v != _passwordCtrl.text) {
                            return 'Las contraseñas no coinciden';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _cargando ? null : _actualizar,
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
                                  'Actualizar',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
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

class _CampoRestablecer extends StatelessWidget {
  final String label;
  final IconData icono;
  final TextEditingController? controlador;
  final bool esOscuro;
  final bool esPassword;
  final bool verPassword;
  final VoidCallback? onCambioVisibilidad;
  final Color colorPrimario;
  final String? Function(String?)? validator;

  const _CampoRestablecer({
    required this.label,
    required this.icono,
    this.controlador,
    required this.esOscuro,
    this.esPassword = false,
    this.verPassword = false,
    this.onCambioVisibilidad,
    required this.colorPrimario,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextFormField(
        controller: controlador,
        obscureText: esPassword && !verPassword,
        validator: validator ??
            (v) {
              if (v == null || v.isEmpty) return 'Campo requerido';
              if (esPassword && v.length < 6) {
                return 'Mínimo 6 caracteres';
              }
              return null;
            },
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
                    verPassword ? Icons.visibility_off : Icons.visibility,
                    color: colorPrimario.withOpacity(0.7),
                    size: 20,
                  ),
                  onPressed: onCambioVisibilidad,
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
