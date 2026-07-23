import 'dart:ui';

import 'package:flutter/material.dart';

class CodigoVerificacionPantalla extends StatefulWidget {
  final VoidCallback onLogin;
  final VoidCallback onRegistro;

  const CodigoVerificacionPantalla({
    super.key,
    required this.onLogin,
    required this.onRegistro,
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
    // TODO: Implementar verificación de código
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
                        'Código de Verificación',
                        style: TextStyle(
                          color: primario,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Ingresa el código que enviamos a tu correo electrónico.',
                        style: TextStyle(fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      _CampoCodigo(
                        label: 'Código',
                        icono: Icons.lock_outlined,
                        controlador: _codigoCtrl,
                        esOscuro: esOscuro,
                        colorPrimario: primario,
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
                        onTap: () {},
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

class _CampoCodigo extends StatelessWidget {
  final String label;
  final IconData icono;
  final TextEditingController? controlador;
  final bool esOscuro;
  final Color colorPrimario;

  const _CampoCodigo({
    required this.label,
    required this.icono,
    this.controlador,
    required this.esOscuro,
    required this.colorPrimario,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextFormField(
        controller: controlador,
        keyboardType: TextInputType.number,
        maxLength: 6,
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
          counterText: '',
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
