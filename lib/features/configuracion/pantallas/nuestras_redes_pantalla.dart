import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/servicios/notificacion_servicio.dart';

/// Enlaces oficiales de Flumi. Rellena con las URLs reales.
class _Red {
  final String nombre;
  final String usuario;
  final String url;
  final IconData icono;
  final Color color;

  const _Red(this.nombre, this.usuario, this.url, this.icono, this.color);
}

const _redes = [
  _Red('Telegram', '@flumi', 'https://t.me/flumi',
      Icons.send_outlined, Color(0xFF229ED9)),
  _Red('WhatsApp', '+53 5 123 45 67', 'https://wa.me/5351234567',
      Icons.chat_outlined, Color(0xFF25D366)),
  _Red('Instagram', '@flumi.app', 'https://instagram.com/flumi.app',
      Icons.camera_alt_outlined, Color(0xFFE1306C)),
];

/// Nuestras redes oficiales (reemplaza al antiguo "Contactos").
class NuestrasRedesPantalla extends StatelessWidget {
  const NuestrasRedesPantalla({super.key});

  Future<void> _abrir(BuildContext context, _Red red) async {
    final uri = Uri.tryParse(red.url);
    if (uri == null || red.url.isEmpty) {
      NotificacionServicio.alerta(context, 'Enlace no disponible.');
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        NotificacionServicio.alerta(
            context, 'No se pudo abrir ${red.nombre}.');
      }
    } catch (_) {
      if (context.mounted) {
        NotificacionServicio.alerta(
            context, 'No se pudo abrir ${red.nombre}.');
      }
    }
  }

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
          'Nuestras redes',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: _redes.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final red = _redes[i];
            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: red.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(red.icono, color: red.color, size: 22),
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
              onTap: () => _abrir(context, red),
            );
          },
        ),
      ),
    );
  }
}
