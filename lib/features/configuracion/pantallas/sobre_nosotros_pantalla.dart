import 'package:flutter/material.dart';

import '../../legal/contenido_legal_pantalla.dart';

class SobreNosotrosPantalla extends StatelessWidget {
  const SobreNosotrosPantalla({super.key});

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
    (
      clave: 'contactos',
      titulo: 'Contactos',
      icono: Icons.contact_support_outlined,
    ),
    (
      clave: 'sobre_flumi',
      titulo: 'Sobre Flumi',
      icono: Icons.info_outline,
    ),
  ];

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
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: _secciones.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final s = _secciones[i];
            return ListTile(
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
            );
          },
        ),
      ),
    );
  }
}