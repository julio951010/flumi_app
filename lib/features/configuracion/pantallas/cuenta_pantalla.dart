import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../../core/servicios/notificacion_servicio.dart';

class CuentaPantalla extends StatelessWidget {
  final AuthService authService;

  const CuentaPantalla({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    final secundario = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Cuenta',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _item(context, Icons.email_outlined, 'Dirección email', secundario,
                onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ActualizarEmailPantalla(
                            authService: authService),
                      ),
                    )),
            const Divider(height: 1),
            _item(context, Icons.lock_outline, 'Contraseña', secundario,
                onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CambiarContrasenaPantalla(
                            authService: authService),
                      ),
                    )),
            const Divider(height: 1),
            _item(context, Icons.delete_outline, 'Eliminar Cuenta', secundario,
                color: Colors.red,
                onTap: () => _confirmarEliminar(context)),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarEliminar(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar tu cuenta? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    final confirmadoFinal = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Última confirmación'),
        content: const Text(
          'Tu cuenta, perfil y datos serán eliminados permanentemente. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sí, eliminar mi cuenta',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirmadoFinal != true) return;

    if (!context.mounted) return;
    try {
      await authService.eliminarCuenta();
      if (!context.mounted) return;
      NotificacionServicio.exito(context, 'Cuenta eliminada correctamente.');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!context.mounted) return;
      NotificacionServicio.alerta(context, e.toString());
    }
  }

  Widget _item(BuildContext context, IconData icono, String titulo,
      Color secundario,
      {Color? color, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icono, color: color ?? secundario),
      title: Text(titulo, style: TextStyle(color: color ?? Colors.black87)),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
    );
  }
}

class ActualizarEmailPantalla extends StatefulWidget {
  final AuthService authService;

  const ActualizarEmailPantalla({super.key, required this.authService});

  @override
  State<ActualizarEmailPantalla> createState() => _ActualizarEmailPantallaState();
}

class _ActualizarEmailPantallaState extends State<ActualizarEmailPantalla> {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.authService.usuarioActual?['email'] as String? ?? '';
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await widget.authService.actualizarEmail(_emailCtrl.text.trim());
      if (!mounted) return;
      NotificacionServicio.exito(context, 'Email actualizado correctamente.');
      Navigator.pop(context);
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Dirección email',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            const Text(
              'Actualiza la dirección de email de tu cuenta.',
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                children: [
                  _campo(
                    context,
                    controlador: _emailCtrl,
                    label: 'Dirección email',
                    icono: Icons.email_outlined,
                    teclado: TextInputType.emailAddress,
                    primario: primario,
                    validator: (v) {
                      final valor = v?.trim() ?? '';
                      if (valor.isEmpty) return 'Ingresa un email';
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch(valor)) {
                        return 'Email no válido';
                      }
                      if (valor ==
                          widget.authService.usuarioActual?['email']) {
                        return 'El email es el mismo';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _cargando ? null : _guardar,
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
                                  fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campo(
    BuildContext context, {
    required TextEditingController controlador,
    required String label,
    required IconData icono,
    required TextInputType teclado,
    required Color primario,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controlador,
      keyboardType: teclado,
      validator: validator,
      style: const TextStyle(color: Colors.black87, fontSize: 15),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey[100],
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black45, fontSize: 14),
        prefixIcon: Icon(icono, color: primario.withValues(alpha: 0.7), size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primario.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primario.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primario, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

class CambiarContrasenaPantalla extends StatefulWidget {
  final AuthService authService;

  const CambiarContrasenaPantalla({super.key, required this.authService});

  @override
  State<CambiarContrasenaPantalla> createState() =>
      _CambiarContrasenaPantallaState();
}

class _CambiarContrasenaPantallaState extends State<CambiarContrasenaPantalla> {
  final _nuevaCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _cargando = false;
  bool _verNueva = false;
  bool _verConfirmar = false;

  @override
  void dispose() {
    _nuevaCtrl.dispose();
    _confirmarCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await widget.authService.actualizarPassword(_nuevaCtrl.text);
      if (!mounted) return;
      NotificacionServicio.exito(context, 'Contraseña actualizada correctamente.');
      Navigator.pop(context);
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Contraseña',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            const Text(
              'Cambia la contraseña de tu cuenta.',
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                children: [
                  _campo(
                    context,
                    controlador: _nuevaCtrl,
                    label: 'Nueva contraseña',
                    esPassword: true,
                    verPassword: _verNueva,
                    onCambioVisibilidad: () =>
                        setState(() => _verNueva = !_verNueva),
                    primario: primario,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Ingresa una contraseña';
                      if (v.length < 6) return 'Mínimo 6 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _campo(
                    context,
                    controlador: _confirmarCtrl,
                    label: 'Confirmar contraseña',
                    esPassword: true,
                    verPassword: _verConfirmar,
                    onCambioVisibilidad: () =>
                        setState(() => _verConfirmar = !_verConfirmar),
                    primario: primario,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Confirma tu contraseña';
                      if (v != _nuevaCtrl.text) return 'Las contraseñas no coinciden';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _cargando ? null : _guardar,
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
                              'Cambiar contraseña',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campo(
    BuildContext context, {
    required TextEditingController controlador,
    required String label,
    required Color primario,
    required String? Function(String?) validator,
    bool esPassword = false,
    bool verPassword = false,
    VoidCallback? onCambioVisibilidad,
  }) {
    return TextFormField(
      controller: controlador,
      obscureText: esPassword && !verPassword,
      validator: validator,
      style: const TextStyle(color: Colors.black87, fontSize: 15),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey[100],
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black45, fontSize: 14),
        prefixIcon: Icon(Icons.lock_outline,
            color: primario.withValues(alpha: 0.7), size: 20),
        suffixIcon: esPassword
            ? IconButton(
                icon: Icon(
                  verPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.black45,
                  size: 20,
                ),
                onPressed: onCambioVisibilidad,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primario.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primario.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primario, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
