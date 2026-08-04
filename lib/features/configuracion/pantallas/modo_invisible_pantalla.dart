import 'package:flutter/material.dart';

class ModoInvisiblePantalla extends StatefulWidget {
  const ModoInvisiblePantalla({super.key});

  @override
  State<ModoInvisiblePantalla> createState() => _ModoInvisiblePantallaState();
}

class _ModoInvisiblePantallaState extends State<ModoInvisiblePantalla> {
  bool _ocultarPerfil = false;
  bool _ocultarVisitas = false;

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
          'Modo invisible',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _fila(
              primario,
              Icons.visibility_off_outlined,
              'Ocultar mi perfil',
              'Tu perfil no aparecerá en los resultados de otras personas',
              _ocultarPerfil,
              (v) => setState(() => _ocultarPerfil = v),
            ),
            const Divider(height: 1),
            _fila(
              primario,
              Icons.remove_red_eye_outlined,
              'Ocultar visitas',
              'Nadie podrá ver que visitaste su perfil',
              _ocultarVisitas,
              (v) => setState(() => _ocultarVisitas = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fila(
    Color primario,
    IconData icono,
    String titulo,
    String descripcion,
    bool valor,
    ValueChanged<bool> onCambio,
  ) {
    return SwitchListTile(
      value: valor,
      onChanged: onCambio,
      activeTrackColor: primario,
      secondary: Icon(icono, color: primario.withValues(alpha: 0.7)),
      title: Text(
        titulo,
        style: const TextStyle(fontSize: 15, color: Colors.black87),
      ),
      subtitle: Text(
        descripcion,
        style: const TextStyle(fontSize: 13, color: Colors.black54),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    );
  }
}
