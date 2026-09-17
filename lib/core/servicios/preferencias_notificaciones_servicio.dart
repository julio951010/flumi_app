import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/env.dart';

/// Preferencias de notificaciones del usuario (pantalla Configuración →
/// Notificaciones). Se persisten localmente con shared_preferences y se
/// consultan en la bandeja y en el aviso en vivo para no mostrar
/// notificaciones de categorías desactivadas.
class PreferenciasNotificacionesServicio extends ChangeNotifier {
  PreferenciasNotificacionesServicio._();

  static final PreferenciasNotificacionesServicio instancia =
      PreferenciasNotificacionesServicio._();

  static const _prefijo = 'pref_notif.';

  bool _cargada = false;

  bool mensajes = true;
  bool matches = true;
  bool lesGusto = true;
  bool visitas = true;
  bool cercaDeTi = true;
  bool regalos = true;
  bool consejos = true;
  bool sondeos = true;

  bool get cargada => _cargada;

  Future<void> asegurarCargada() async {
    if (_cargada) return;
    final prefs = await SharedPreferences.getInstance();
    mensajes = prefs.getBool('${_prefijo}mensajes') ?? true;
    matches = prefs.getBool('${_prefijo}matches') ?? true;
    lesGusto = prefs.getBool('${_prefijo}lesGusto') ?? true;
    visitas = prefs.getBool('${_prefijo}visitas') ?? true;
    cercaDeTi = prefs.getBool('${_prefijo}cercaDeTi') ?? true;
    regalos = prefs.getBool('${_prefijo}regalos') ?? true;
    consejos = prefs.getBool('${_prefijo}consejos') ?? true;
    sondeos = prefs.getBool('${_prefijo}sondeos') ?? true;
    _cargada = true;
    notifyListeners();
  }

  Future<void> establecer({
    bool? mensajes,
    bool? matches,
    bool? lesGusto,
    bool? visitas,
    bool? cercaDeTi,
    bool? regalos,
    bool? consejos,
    bool? sondeos,
  }) async {
    await asegurarCargada();
    this.mensajes = mensajes ?? this.mensajes;
    this.matches = matches ?? this.matches;
    this.lesGusto = lesGusto ?? this.lesGusto;
    this.visitas = visitas ?? this.visitas;
    this.cercaDeTi = cercaDeTi ?? this.cercaDeTi;
    this.regalos = regalos ?? this.regalos;
    this.consejos = consejos ?? this.consejos;
    this.sondeos = sondeos ?? this.sondeos;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_prefijo}mensajes', this.mensajes);
    await prefs.setBool('${_prefijo}matches', this.matches);
    await prefs.setBool('${_prefijo}lesGusto', this.lesGusto);
    await prefs.setBool('${_prefijo}visitas', this.visitas);
    await prefs.setBool('${_prefijo}cercaDeTi', this.cercaDeTi);
    await prefs.setBool('${_prefijo}regalos', this.regalos);
    await prefs.setBool('${_prefijo}consejos', this.consejos);
    await prefs.setBool('${_prefijo}sondeos', this.sondeos);
    notifyListeners();
    // Write-through al servidor (best-effort) para que los push la respeten.
    if (!kUsarServidorLocal) {
      try {
        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid == null) return;
        await Supabase.instance.client.from('notif_prefs').upsert({
          'usuario_id': uid,
          'mensajes': mensajes,
          'matches': matches,
          'les_gusto': lesGusto,
          'visitas': visitas,
          'cerca_de_ti': cercaDeTi,
          'regalos': regalos,
          'consejos': consejos,
          'sondeos': sondeos,
        });
      } catch (_) {}
    }
  }
}