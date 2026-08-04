import 'package:flutter/material.dart';

import 'personas_bloqueadas_pantalla.dart';

class PrivacidadPantalla extends StatefulWidget {
  const PrivacidadPantalla({super.key});

  @override
  State<PrivacidadPantalla> createState() => _PrivacidadPantallaState();
}

class _PrivacidadPantallaState extends State<PrivacidadPantalla> {
  bool _mostrarUbicacion = true;
  bool _mostrarEnLinea = true;
  bool _soloRangoEdad = false;
  bool _soloPersonasQueMeGustan = false;
  bool _mensajesSoloGustados = false;
  bool _mensajesSoloVerificados = false;

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
          'Privacidad',
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
              Icons.location_on_outlined,
              'Mostrar mi ubicación',
              'Permite que otras personas vean tu ubicación',
              _mostrarUbicacion,
              (v) => setState(() => _mostrarUbicacion = v),
            ),
            const Divider(height: 1),
            _fila(
              primario,
              Icons.circle_outlined,
              'Mostrarme en línea',
              'Muestra tu estado de conexión a otras personas',
              _mostrarEnLinea,
              (v) => setState(() => _mostrarEnLinea = v),
            ),
            const Divider(height: 1),
            _fila(
              primario,
              Icons.cake_outlined,
              'Mostrarme solo a personas dentro de mi rango de edad',
              'Solo las personas dentro del rango de edad que configures podrán ver tu perfil',
              _soloRangoEdad,
              (v) => setState(() => _soloRangoEdad = v),
            ),
            const Divider(height: 1),
            _fila(
              primario,
              Icons.favorite_outline,
              'Mostrarme solo a personas que me gustan',
              'Solo las personas a las que les diste "me gusta" podrán ver tu perfil',
              _soloPersonasQueMeGustan,
              (v) => setState(() => _soloPersonasQueMeGustan = v),
            ),
            const Divider(height: 1),
            _fila(
              primario,
              Icons.forum_outlined,
              'Recibir mensajes solo de las personas que me gustan',
              'Solo las personas a las que les diste "me gusta" podrán escribirte',
              _mensajesSoloGustados,
              (v) => setState(() => _mensajesSoloGustados = v),
            ),
            const Divider(height: 1),
            _fila(
              primario,
              Icons.verified_outlined,
              'Recibir mensajes solo de perfiles verificados',
              'Solo los perfiles con verificación podrán escribirte',
              _mensajesSoloVerificados,
              (v) => setState(() => _mensajesSoloVerificados = v),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.block_outlined,
                color: primario.withValues(alpha: 0.7),
              ),
              title: const Text(
                'Lista de personas bloqueadas',
                style: TextStyle(fontSize: 15, color: Colors.black87),
              ),
              trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PersonasBloqueadasPantalla(),
                ),
              ),
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
