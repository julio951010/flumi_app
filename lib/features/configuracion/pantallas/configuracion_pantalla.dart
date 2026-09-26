import 'package:flutter/material.dart';

import '../../../core/base_datos_local/database.dart';
import '../../../core/servicios/notificacion_servicio.dart';
import '../../../core/servicios/suscripcion_servicio.dart';
import '../../../core/servicios/sync_service.dart';
import '../../../core/utilidades/temp_cache_native.dart'
    if (dart.library.html) '../../../core/utilidades/temp_cache_web.dart';
import '../../auth/auth_service.dart';
import '../../perfiles/perfil_repositorio.dart';
import 'administrar_suscripcion_pantalla.dart';
import 'ayuda_soporte_pantalla.dart';
import 'cuenta_pantalla.dart';
import 'informacion_basica_pantalla.dart';
import 'modo_invisible_pantalla.dart';
import 'notificaciones_pantalla.dart';
import 'privacidad_pantalla.dart';
import 'sobre_nosotros_pantalla.dart';

class ConfiguracionPantalla extends StatelessWidget {
  final AuthService authService;
  final PerfilRepositorio repositorio;
  final AppDatabase db;
  final SuscripcionServicio suscripcionServicio;
  final SyncService syncService;
  final Future<void> Function()? onCerrarSesion;

  const ConfiguracionPantalla({
    super.key,
    required this.authService,
    required this.repositorio,
    required this.db,
    required this.suscripcionServicio,
    required this.syncService,
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
                        builder: (_) => PrivacidadPantalla(
                          db: db,
                          suscripcionServicio: suscripcionServicio,
                          syncService: syncService,
                          repositorio: repositorio,
                        ),
                      ),
                    )),
            const Divider(height: 1),
            _item(context, Icons.visibility_off_outlined, 'Modo invisible',
                onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ModoInvisiblePantalla(
                          suscripcionServicio: suscripcionServicio,
                          repositorio: repositorio,
                        ),
                      ),
                    )),
            if (suscripcionServicio.suscripcionesHabilitadas) ...[
              const Divider(height: 1),
              _item(context, Icons.credit_card_outlined, 'Administrar suscripción',
                  onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdministrarSuscripcionPantalla(
                            suscripcionServicio: suscripcionServicio,
                          ),
                        ),
                      )),
            ],
            const Divider(height: 1),
            _item(context, Icons.help_outline, 'Ayuda y soporte',
                onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AyudaSoportePantalla(),
                      ),
                    )),
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
                onPressed: () async {
                  // Capturamos el Navigator antes del await: tras cerrar sesión
                  // el router reconstruye la pantalla de inicio, pero esta ruta
                  // (Configuración) sigue montada y su Navigator sigue vivo.
                  final nav = Navigator.of(context);
                  final confirmado = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Cerrar sesión'),
                      content: const Text('¿Estás seguro?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Cerrar sesión'),
                        ),
                      ],
                    ),
                  );
                  if (confirmado != true) return;
                  // Feedback mientras el signOut (red) se completa.
                  showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                  );
                  try {
                    await onCerrarSesion?.call();
                  } finally {
                    // Cierra el diálogo de progreso y luego esta pantalla para
                    // revelar el login que ya mostró el router vía el listener.
                    if (context.mounted) Navigator.of(context).pop();
                    nav.pop();
                  }
                },
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
    // Capturamos el Navigator antes del await: mientras limpiamos el caché la
    // ruta sigue montada y su Navigator permanece vivo.
    final nav = Navigator.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );

    var liberados = 0;
    try {
      liberados = await borrarCacheTemporal();
      // Caché de imágenes en memoria de Flutter.
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}

    if (context.mounted) nav.pop();
    if (!context.mounted) return;

    final texto = liberados > 0
        ? 'Caché borrada (${_formatoBytes(liberados)} liberados).'
        : 'Caché borrada correctamente.';
    NotificacionServicio.exito(context, texto);
  }

  String _formatoBytes(int bytes) {
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
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
