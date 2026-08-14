import 'package:flutter/material.dart';

import '../../../core/servicios/suscripcion_servicio.dart';
import '../../../features/perfiles/pantallas/detalle_plan_pantalla.dart';
import '../../../widgets_comunes/bloqueo_suscripcion_sheet.dart';

class ModoInvisiblePantalla extends StatefulWidget {
  final SuscripcionServicio suscripcionServicio;

  const ModoInvisiblePantalla({super.key, required this.suscripcionServicio});

  @override
  State<ModoInvisiblePantalla> createState() => _ModoInvisiblePantallaState();
}

class _ModoInvisiblePantallaState extends State<ModoInvisiblePantalla> {
  bool _ocultarPerfil = false;
  bool _ocultarVisitas = false;

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;
    final bloqueado = !widget.suscripcionServicio.tienePremium;

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
              bloqueado,
            ),
            const Divider(height: 1),
            _fila(
              primario,
              Icons.remove_red_eye_outlined,
              'Ocultar visitas',
              'Nadie podrá ver que visitaste su perfil',
              _ocultarVisitas,
              (v) => setState(() => _ocultarVisitas = v),
              bloqueado,
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
    bool bloqueado,
  ) {
    return GestureDetector(
      onTap: bloqueado ? () => _mostrarBloqueoPremium(titulo) : null,
      child: SwitchListTile(
        value: valor,
        onChanged: bloqueado ? null : onCambio,
        activeTrackColor: primario,
      secondary: Icon(
        icono,
        color: bloqueado ? Colors.grey : primario.withValues(alpha: 0.7),
      ),
      title: Text(
        titulo,
        style: TextStyle(
          fontSize: 15,
          color: bloqueado ? Colors.grey : Colors.black87,
        ),
      ),
      subtitle: Text(
        descripcion,
        style: TextStyle(
          fontSize: 13,
          color: bloqueado ? Colors.grey : Colors.black54,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
    );
  }

  void _mostrarBloqueoPremium(String funcionalidad) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BloqueoSuscripcionSheet(
        titulo: 'Requiere Flumi Premium',
        descripcion: '$funcionalidad es una función exclusiva de Flumi Premium.',
        onSuscribir: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const DetallePlanPantalla(
              nombre: 'Flumi Premium',
              periodo: 'mensual',
              precio: '500 cup',
              icono: Icons.workspace_premium,
              detalle: 'Acceso total',
              destacado: false,
            ),
          ),
        ),
      ),
    );
  }
}
