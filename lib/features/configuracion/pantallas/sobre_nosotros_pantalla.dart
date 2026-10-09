import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../legal/contenido_legal_pantalla.dart';
import 'nuestras_redes_pantalla.dart';

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
  ];

  Future<String> _version() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return 'Flumi v${info.version} (${info.buildNumber})';
    } catch (_) {
      return 'Flumi';
    }
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
            ListTile(
              leading: Icon(Icons.share_outlined, color: secundario),
              title: const Text(
                'Nuestras redes',
                style: TextStyle(color: Colors.black87, fontSize: 15),
              ),
              trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NuestrasRedesPantalla(),
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
            const SizedBox(height: 24),
            FutureBuilder<String>(
              future: _version(),
              builder: (context, snap) => Text(
                snap.data ?? 'Flumi',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
