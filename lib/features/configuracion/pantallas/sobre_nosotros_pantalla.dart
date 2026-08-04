import 'package:flutter/material.dart';

import '../../../core/servicios/notificacion_servicio.dart';

class SobreNosotrosPantalla extends StatelessWidget {
  const SobreNosotrosPantalla({super.key});

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
            _item(context, Icons.description_outlined,
                'Términos y condiciones de uso', secundario),
            const Divider(height: 1),
            _item(context, Icons.privacy_tip_outlined, 'Políticas de privacidad',
                secundario),
            const Divider(height: 1),
            _item(context, Icons.child_care_outlined,
                'Políticas de seguridad infantil', secundario),
            const Divider(height: 1),
            _item(context, Icons.verified_outlined, 'Licencias', secundario),
            const Divider(height: 1),
            _item(context, Icons.contact_support_outlined, 'Contactos',
                secundario),
            const Divider(height: 1),
            _item(context, Icons.info_outline, 'Sobre Flumi', secundario),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, IconData icono, String titulo,
      Color secundario) {
    return ListTile(
      leading: Icon(icono, color: secundario),
      title: Text(
        titulo,
        style: const TextStyle(color: Colors.black87, fontSize: 15),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: () => NotificacionServicio.advertencia(
          context, 'Esta sección estará disponible próximamente.'),
    );
  }
}