import 'package:flutter/material.dart';

import '../../../core/servicios/notificacion_servicio.dart';
import '../../auth/auth_service.dart';
import '../../perfiles/perfil_repositorio.dart';
import 'administrar_suscripcion_pantalla.dart';
import 'cuenta_pantalla.dart';
import 'informacion_basica_pantalla.dart';
import 'modo_invisible_pantalla.dart';
import 'notificaciones_pantalla.dart';
import 'privacidad_pantalla.dart';
import 'sobre_nosotros_pantalla.dart';

class ConfiguracionPantalla extends StatelessWidget {
  final AuthService authService;
  final PerfilRepositorio repositorio;
  final VoidCallback? onCerrarSesion;

  const ConfiguracionPantalla({
    super.key,
    required this.authService,
    required this.repositorio,
    this.onCerrarSesion,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Configuración',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _item(context, Icons.account_circle_outlined, 'Cuenta',
                onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CuentaPantalla(authService: authService),
                      ),
                    )),
            const Divider(height: 1),
            _item(context, Icons.person_outline, 'Información Básica',
                onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InformacionBasicaPantalla(
                            repositorio: repositorio),
                      ),
                    )),
            const Divider(height: 1),
            _item(context, Icons.notifications_none, 'Notificaciones',
                onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificacionesPantalla(),
                      ),
                    )),
            const Divider(height: 1),
            _item(context, Icons.lock_outline, 'Privacidad',
                onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrivacidadPantalla(),
                      ),
                    )),
            const Divider(height: 1),
            _item(context, Icons.visibility_off_outlined, 'Modo invisible',
                onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ModoInvisiblePantalla(),
                      ),
                    )),
            const Divider(height: 1),
            _item(context, Icons.credit_card_outlined, 'Administrar suscripción',
                onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdministrarSuscripcionPantalla(),
                      ),
                    )),
            const Divider(height: 1),
            _item(context, Icons.help_outline, 'Ayuda y soporte'),
            const Divider(height: 1),
            _item(context, Icons.info_outline, 'Sobre nosotros',
                onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SobreNosotrosPantalla(),
                      ),
                    )),
            const Divider(height: 1),
            _item(context, Icons.cleaning_services_outlined, 'Borrar caché',
                onTap: () => _confirmarBorrarCache(context)),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCerrarSesion,
                icon: const Icon(Icons.logout, size: 20),
                label: const Text(
                  'Cerrar sesión',
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[400],
                  side: BorderSide(color: Colors.red[400]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarBorrarCache(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar caché'),
        content: const Text(
          '¿Seguro que quieres borrar los datos temporales de la aplicación?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !context.mounted) return;
    NotificacionServicio.exito(context, 'Caché borrada correctamente.');
  }

  Widget _item(BuildContext context, IconData icono, String titulo,
      {VoidCallback? onTap}) {
    final secundario = Theme.of(context).colorScheme.secondary;
    return ListTile(
      leading: Icon(icono, color: secundario),
      title: Text(titulo),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
    );
  }
}
