import 'package:flutter/material.dart';

import '../../../core/servicios/preferencias_notificaciones_servicio.dart';

class NotificacionesPantalla extends StatefulWidget {
  const NotificacionesPantalla({super.key});

  @override
  State<NotificacionesPantalla> createState() => _NotificacionesPantallaState();
}

class _NotificacionesPantallaState extends State<NotificacionesPantalla> {
  bool _cargando = true;
  late final PreferenciasNotificacionesServicio _prefs =
      PreferenciasNotificacionesServicio.instancia;

  @override
  void initState() {
    super.initState();
    _prefs.addListener(_alCambiarPrefs);
    _prefs.asegurarCargada().then((_) {
      if (mounted) setState(() => _cargando = false);
    });
  }

  @override
  void dispose() {
    _prefs.removeListener(_alCambiarPrefs);
    super.dispose();
  }

  void _alCambiarPrefs() {
    if (mounted) setState(() {});
  }

  Future<void> _cambiar({
    bool? mensajes,
    bool? matches,
    bool? lesGusto,
    bool? visitas,
    bool? cercaDeTi,
    bool? regalos,
    bool? consejos,
    bool? sondeos,
  }) {
    return _prefs.establecer(
      mensajes: mensajes,
      matches: matches,
      lesGusto: lesGusto,
      visitas: visitas,
      cercaDeTi: cercaDeTi,
      regalos: regalos,
      consejos: consejos,
      sondeos: sondeos,
    );
  }

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
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _fila(
                    primario,
                    Icons.chat_bubble_outline,
                    'Mensajes',
                    'Recibe notificaciones sobre mensajes nuevos',
                    _prefs.mensajes,
                    (v) => _cambiar(mensajes: v),
                  ),
                  const Divider(height: 1),
                  _fila(
                    primario,
                    Icons.favorite_outline,
                    'Matches',
                    'Recibe notificaciones sobre nuevos matches',
                    _prefs.matches,
                    (v) => _cambiar(matches: v),
                  ),
                  const Divider(height: 1),
                  _fila(
                    primario,
                    Icons.thumb_up_outlined,
                    'Les gusto',
                    'Recibe notificaciones cuando le gustes a alguien',
                    _prefs.lesGusto,
                    (v) => _cambiar(lesGusto: v),
                  ),
                  const Divider(height: 1),
                  _fila(
                    primario,
                    Icons.remove_red_eye_outlined,
                    'Visitas',
                    'Recibe notificaciones sobre quién visita tu perfil',
                    _prefs.visitas,
                    (v) => _cambiar(visitas: v),
                  ),
                  const Divider(height: 1),
                  _fila(
                    primario,
                    Icons.location_on_outlined,
                    'Cerca de ti',
                    'Recibe notificaciones cuando alguien que coincide con tu perfil está cerca de ti',
                    _prefs.cercaDeTi,
                    (v) => _cambiar(cercaDeTi: v),
                  ),
                  const Divider(height: 1),
                  _fila(
                    primario,
                    Icons.card_giftcard,
                    'Regalos',
                    'Recibe notificaciones cuando te envíen regalos',
                    _prefs.regalos,
                    (v) => _cambiar(regalos: v),
                  ),
                  const Divider(height: 1),
                  _fila(
                    primario,
                    Icons.campaign_outlined,
                    'Consejos, ofertas, promociones',
                    'Recibe consejos para mejorar tu perfil e información sobre ofertas y promociones',
                    _prefs.consejos,
                    (v) => _cambiar(consejos: v),
                  ),
                  const Divider(height: 1),
                  _fila(
                    primario,
                    Icons.poll_outlined,
                    'Sondeos y encuestas',
                    'Recibe información sobre programas de investigación remunerados y no remunerados y comparte tu opinión sobre cómo mejorar nuestros servicios',
                    _prefs.sondeos,
                    (v) => _cambiar(sondeos: v),
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
