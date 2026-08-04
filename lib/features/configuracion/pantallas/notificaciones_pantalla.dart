import 'package:flutter/material.dart';

class NotificacionesPantalla extends StatefulWidget {
  const NotificacionesPantalla({super.key});

  @override
  State<NotificacionesPantalla> createState() => _NotificacionesPantallaState();
}

class _NotificacionesPantallaState extends State<NotificacionesPantalla> {
  bool _mensajes = true;
  bool _matches = true;
  bool _lesGusto = true;
  bool _visitas = true;
  bool _cercaDeTi = true;
  bool _regalos = true;
  bool _consejos = true;
  bool _sondeos = true;

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
          'Notificaciones',
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
              Icons.chat_bubble_outline,
              'Mensajes',
              'Recibe notificaciones sobre mensajes nuevos',
              _mensajes,
              (v) => setState(() => _mensajes = v),
            ),
            const Divider(height: 1),
            _fila(
              primario,
              Icons.favorite_outline,
              'Matches',
              'Recibe notificaciones sobre nuevos matches',
              _matches,
              (v) => setState(() => _matches = v),
            ),
            const Divider(height: 1),
            _fila(
              primario,
              Icons.thumb_up_outlined,
              'Les gusto',
              'Recibe notificaciones cuando le gustes a alguien',
              _lesGusto,
              (v) => setState(() => _lesGusto = v),
            ),
            const Divider(height: 1),
            _fila(
              primario,
              Icons.remove_red_eye_outlined,
              'Visitas',
              'Recibe notificaciones sobre quién visita tu perfil',
              _visitas,
              (v) => setState(() => _visitas = v),
            ),
            const Divider(height: 1),
            _fila(
              primario,
              Icons.location_on_outlined,
              'Cerca de ti',
              'Recibe notificaciones cuando alguien que coincide con tu perfil está cerca de ti',
              _cercaDeTi,
              (v) => setState(() => _cercaDeTi = v),
            ),
            const Divider(height: 1),
            _fila(
              primario,
              Icons.card_giftcard,
              'Regalos',
              'Recibe notificaciones cuando te envíen regalos',
              _regalos,
              (v) => setState(() => _regalos = v),
            ),
            const Divider(height: 1),
            _fila(
              primario,
              Icons.campaign_outlined,
              'Consejos, ofertas, promociones',
              'Recibe consejos para mejorar tu perfil e información sobre ofertas y promociones',
              _consejos,
              (v) => setState(() => _consejos = v),
            ),
            const Divider(height: 1),
            _fila(
              primario,
              Icons.poll_outlined,
              'Sondeos y encuestas',
              'Recibe información sobre programas de investigación remunerados y no remunerados y comparte tu opinión sobre cómo mejorar nuestros servicios',
              _sondeos,
              (v) => setState(() => _sondeos = v),
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
