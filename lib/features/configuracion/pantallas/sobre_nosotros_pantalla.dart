import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/env.dart';
import '../../../core/estilos/tema.dart';
import '../../../core/servicios/notificacion_servicio.dart';
import '../../../core/servicios/redes_servicio.dart';
import '../../../main.dart' show configRemota;
import '../../legal/contenido_legal_pantalla.dart';

// ---------------------------------------------------------------------------
// (Invitar, Valorar, Descargar y Donar se configuran desde admin_flumi →
// Sobre nosotros: mensajes, URLs, cuentas y visibilidad de cada botón.)
// ---------------------------------------------------------------------------

class SobreNosotrosPantalla extends StatefulWidget {
  const SobreNosotrosPantalla({super.key});

  @override
  State<SobreNosotrosPantalla> createState() => _SobreNosotrosPantallaState();
}

class _SobreNosotrosPantallaState extends State<SobreNosotrosPantalla> {
  static const _secciones = [
    (
      clave: 'terminos',
      titulo: 'Términos y condiciones de uso',
      icono: Icons.description_outlined,
    ),
    (
      clave: 'privacidad',
      titulo: 'Políticas de privacidad',
      icono: Icons.privacy_tip_outlined,
    ),
    (
      clave: 'seguridad_infantil',
      titulo: 'Políticas de seguridad infantil',
      icono: Icons.child_care_outlined,
    ),
    (
      clave: 'licencias',
      titulo: 'Licencias',
      icono: Icons.verified_outlined,
    ),
  ];

  List<RedSocial>? _redes;
  bool _errorRedes = false;
  RealtimeChannel? _canalRedes;

  @override
  void initState() {
    super.initState();
    _cargarRedes();
    _suscribirRedes();
  }

  @override
  void dispose() {
    try {
      final canal = _canalRedes;
      if (canal != null) {
        Supabase.instance.client.removeChannel(canal);
      }
    } catch (_) {}
    super.dispose();
  }

  /// Cambios desde admin_flumi (agregar/editar/ocultar redes) llegan solos:
  /// se invalida la caché y se recarga, sin salir de la pantalla.
  void _suscribirRedes() {
    if (kUsarServidorLocal) return;
    try {
      _canalRedes = Supabase.instance.client.channel('redes_cambios')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'redes_sociales',
          callback: (_) {
            RedesServicio.instancia.limpiarCache();
            if (mounted) _cargarRedes(forzar: true);
          },
        )
        ..subscribe();
    } catch (_) {}
  }

  Future<String> _version() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return 'Flumi v${info.version} (${info.buildNumber})';
    } catch (_) {
      return 'Flumi';
    }
  }

  Future<void> _cargarRedes({bool forzar = false}) async {
    try {
      final redes =
          await RedesServicio.instancia.obtenerRedes(forzarRefresh: forzar);
      if (mounted) {
        setState(() {
          _redes = redes;
          _errorRedes = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _redes = null;
          _errorRedes = true;
        });
      }
    }
  }

  Future<void> _abrirRed(RedSocial red) async {
    final uri = Uri.tryParse(red.url);
    if (uri == null || red.url.isEmpty) {
      if (mounted) NotificacionServicio.alerta(context, 'Enlace no disponible.');
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        NotificacionServicio.alerta(
            context, 'No se pudo abrir ${red.nombre}.');
      }
    } catch (_) {
      if (mounted) {
        NotificacionServicio.alerta(
            context, 'No se pudo abrir ${red.nombre}.');
      }
    }
  }

  /// Enlace de descarga (admin_flumi → descarga_url; si está vacío se usa
  /// actualizar_url de la actualización obligatoria).
  String get _enlaceApp {
    final descarga = configRemota.descargaUrl.trim();
    if (descarga.isNotEmpty) return descarga;
    return configRemota.actualizarUrl.trim();
  }

  /// Mensaje de invitación (admin_flumi → invitacion_mensaje) + enlace.
  String get _textoInvitar {
    final mensaje = configRemota.invitacionMensaje.trim();
    const base =
        'Déjate llevar por la corriente con Flumi, la app cubana para conocer personas';
    final texto = mensaje.isEmpty ? base : mensaje;
    final enlace = _enlaceApp;
    return enlace.isEmpty ? texto : '$texto: $enlace';
  }

  Future<void> _abrirUrl(String url, String nombre) async {
    if (url.isEmpty) {
      if (mounted) {
        NotificacionServicio.alerta(
            context, '$nombre no está disponible por ahora.');
      }
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (mounted) {
        NotificacionServicio.alerta(context, 'Enlace no disponible.');
      }
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        NotificacionServicio.alerta(context, 'No se pudo abrir $nombre.');
      }
    } catch (_) {
      if (mounted) {
        NotificacionServicio.alerta(context, 'No se pudo abrir $nombre.');
      }
    }
  }

  /// Invitar: hoja nativa del sistema (todas las apps, contactos, etc.)
  /// con el mensaje + enlace de descarga (admin_flumi → invitacion_mensaje
  /// y descarga_url).
  Future<void> _invitar() async {
    try {
      await SharePlus.instance
          .share(ShareParams(text: _textoInvitar, subject: 'Flumi'));
    } catch (_) {
      if (mounted) {
        NotificacionServicio.alerta(
            context, 'No se pudo abrir para compartir.');
      }
    }
  }

  Future<void> _valorar() =>
      _abrirUrl(configRemota.valorarUrl.trim(), 'la valoración');

  Future<void> _descargar() => _abrirUrl(_enlaceApp, 'la descarga');

  /// Donar: ventana con el mensaje + datos de cuenta y teléfono
  /// (admin_flumi → donacion_*), cada dato con botón para copiar.
  Future<void> _donar() async {
    final mensaje = configRemota.donacionMensaje.trim();
    final cuenta = configRemota.donacionCuenta;
    final telefono = configRemota.donacionTelefono;
    if (mensaje.isEmpty && cuenta.isEmpty && telefono.isEmpty) {
      if (mounted) {
        NotificacionServicio.alerta(
            context, 'La donación no está disponible por ahora.');
      }
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Icon(Icons.volunteer_activism_outlined,
                      color: FlumiTema.colorPrimario),
                  SizedBox(width: 10),
                  Text(
                    'Apoya a Flumi',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                ],
              ),
            ),
            if (mensaje.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text(
                  mensaje,
                  style: const TextStyle(
                      fontSize: 14, color: Colors.black87, height: 1.45),
                ),
              ),
            if (cuenta.isNotEmpty) _datoDonar(ctx, 'Cuenta', Icons.credit_card, cuenta),
            if (telefono.isNotEmpty)
              _datoDonar(ctx, 'Teléfono', Icons.phone_outlined, telefono),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _datoDonar(
      BuildContext ctx, String etiqueta, IconData icono, String valor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icono, color: Colors.grey[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiqueta,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(valor,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: valor.replaceAll(' ', '')));
              Navigator.pop(ctx);
              NotificacionServicio.exito(context, '$etiqueta copiada.');
            },
            icon: const Icon(Icons.copy, size: 18),
            tooltip: 'Copiar',
          ),
        ],
      ),
    );
  }

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
          'Sobre nosotros',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            ListTile(
              leading: Icon(Icons.info_outline, color: secundario),
              title: const Text(
                'Sobre Flumi',
                style: TextStyle(color: Colors.black87, fontSize: 15),
              ),
              trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ContenidoLegalPantalla(
                    clave: 'sobre_flumi',
                    titulo: 'Sobre Flumi',
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            for (final s in _secciones) ...[
              ListTile(
                leading: Icon(s.icono, color: secundario),
                title: Text(
                  s.titulo,
                  style:
                      const TextStyle(color: Colors.black87, fontSize: 15),
                ),
                trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ContenidoLegalPantalla(
                      clave: s.clave,
                      titulo: s.titulo,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
            ],
            _seccionRedes(secundario),
            // Los switches de visibilidad (admin_flumi) se reflejan solos:
            // configRemota ya trae realtime + poll y avisa a sus oyentes.
            ListenableBuilder(
              listenable: configRemota,
              builder: (_, __) => _filaAcciones(),
            ),
            const SizedBox(height: 24),
            FutureBuilder<String>(
              future: _version(),
              builder: (context, snap) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    snap.data ?? 'Flumi',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '© ${DateTime.now().year} Flumi',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Todos los derechos reservados',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Acciones: iconos con el nombre debajo, en una fila. Cada botón se
  /// muestra u oculta desde admin_flumi (mostrar_invitar, mostrar_valorar,
  /// mostrar_descargar, mostrar_donar). Si están todos ocultos, no se
  /// muestra nada.
  Widget _filaAcciones() {
    const primario = FlumiTema.colorPrimario;
    final acciones = [
      if (configRemota.mostrarInvitar)
        (icono: Icons.person_add_outlined, texto: 'Invitar', accion: _invitar),
      if (configRemota.mostrarValorar)
        (icono: Icons.star_outline, texto: 'Valorar', accion: _valorar),
      if (configRemota.mostrarDescargar)
        (
          icono: Icons.download_outlined,
          texto: 'Descargar',
          accion: _descargar
        ),
      if (configRemota.mostrarDonar)
        (
          icono: Icons.volunteer_activism_outlined,
          texto: 'Donar',
          accion: _donar
        ),
    ];
    if (acciones.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final a in acciones)
                GestureDetector(
                  onTap: a.accion,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 72,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: primario.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(a.icono, color: primario, size: 26),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          a.texto,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  /// Redes oficiales inline (gestionadas desde admin_flumi): filas iguales
  /// a las demás opciones, una debajo de la otra y sin separadores entre
  /// ellas. Solo un Divider al final del bloque.
  Widget _seccionRedes(Color secundario) {
    final redes = _redes;
    if (redes == null && !_errorRedes) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
            child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (_errorRedes || redes == null) {
      return Column(
        children: [
          ListTile(
            leading: Icon(Icons.share_outlined, color: secundario),
            title: const Text(
              'No se pudieron cargar las redes',
              style: TextStyle(color: Colors.black87, fontSize: 15),
            ),
            trailing: Icon(Icons.refresh, color: Colors.grey[400]),
            onTap: () => _cargarRedes(forzar: true),
          ),
          const Divider(height: 1),
        ],
      );
    }
    if (redes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: Icon(Icons.share_outlined, color: secundario),
          title: const Text(
            'Nuestras redes',
            style: TextStyle(color: Colors.black87, fontSize: 15),
          ),
        ),
        for (final red in redes)
          Builder(builder: (context) {
            final estilo = estiloRed(red.icono);
            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: estilo.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(estilo.icono, color: estilo.color, size: 22),
              ),
              title: Text(
                red.nombre,
                style:
                    const TextStyle(color: Colors.black87, fontSize: 15),
              ),
              subtitle: Text(
                red.usuario,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              trailing:
                  Icon(Icons.open_in_new, color: Colors.grey[400], size: 20),
              onTap: () => _abrirRed(red),
            );
          }),
        const Divider(height: 1),
      ],
    );
  }
}
