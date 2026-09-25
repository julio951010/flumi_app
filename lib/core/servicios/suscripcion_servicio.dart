import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/env.dart';
import '../base_datos_local/database.dart';
import 'config_remota_servicio.dart';
import 'connectivity_service.dart';
import 'sync_service.dart';

enum PlanTipo { gratis, plus, premium }

class LimitesPlan {
  final int meGustasPorDia;
  final int deshacerPorDia;
  final int superlikesPorDia;
  final int boostsPorMes;
  final int vistasCercaPorDia;
  final bool verQuienTeLikeo;
  final bool verVisitas;
  final int visitasLimite;
  final bool filtrosBasicosCompletos;
  final bool filtrosAvanzados;
  final bool historialLikes;
  final int historialLikesLimite;
  final bool ocultarEnLinea;
  final bool ocultarPerfilFueraEdad;
  final bool visibilidadSelectiva;
  final bool filtrosMensajes;

  const LimitesPlan({
    required this.meGustasPorDia,
    required this.deshacerPorDia,
    required this.superlikesPorDia,
    required this.boostsPorMes,
    required this.vistasCercaPorDia,
    required this.verQuienTeLikeo,
    required this.verVisitas,
    required this.visitasLimite,
    required this.filtrosBasicosCompletos,
    required this.filtrosAvanzados,
    required this.historialLikes,
    required this.historialLikesLimite,
    required this.ocultarEnLinea,
    required this.ocultarPerfilFueraEdad,
    required this.visibilidadSelectiva,
    required this.filtrosMensajes,
  });

  factory LimitesPlan.gratis() => const LimitesPlan(
        meGustasPorDia: 15,
        deshacerPorDia: 1,
        superlikesPorDia: 0,
        boostsPorMes: 0,
        vistasCercaPorDia: 10,
        verQuienTeLikeo: false,
        verVisitas: false,
        visitasLimite: 0,
        filtrosBasicosCompletos: false,
        filtrosAvanzados: false,
        historialLikes: false,
        historialLikesLimite: 0,
        ocultarEnLinea: false,
        ocultarPerfilFueraEdad: false,
        visibilidadSelectiva: false,
        filtrosMensajes: false,
      );

  factory LimitesPlan.plus() => const LimitesPlan(
        meGustasPorDia: -1,
        deshacerPorDia: -1,
        superlikesPorDia: 10,
        boostsPorMes: 1,
        vistasCercaPorDia: 100,
        verQuienTeLikeo: true,
        verVisitas: true,
        visitasLimite: 20,
        filtrosBasicosCompletos: true,
        filtrosAvanzados: false,
        historialLikes: true,
        historialLikesLimite: 15,
        ocultarEnLinea: false,
        ocultarPerfilFueraEdad: true,
        visibilidadSelectiva: false,
        filtrosMensajes: false,
      );

  factory LimitesPlan.premium() => const LimitesPlan(
        meGustasPorDia: -1,
        deshacerPorDia: -1,
        superlikesPorDia: -1,
        boostsPorMes: 4,
        vistasCercaPorDia: -1,
        verQuienTeLikeo: true,
        verVisitas: true,
        visitasLimite: -1,
        filtrosBasicosCompletos: true,
        filtrosAvanzados: true,
        historialLikes: true,
        historialLikesLimite: -1,
        ocultarEnLinea: true,
        ocultarPerfilFueraEdad: true,
        visibilidadSelectiva: true,
        filtrosMensajes: true,
      );
}

class SuscripcionServicio with ChangeNotifier {
  final AppDatabase _db;
  final SyncService _sync;
  final ConfigRemotaServicio? _configRemota;
  PlanTipo _planActual = PlanTipo.gratis;
  Suscripcione? _suscripcionActual;
  UsosDiario? _usosHoy;
  bool _esAdmin = false;
  StreamSubscription<List<Usuario>>? _perfilSub;

  SuscripcionServicio(this._db, this._sync, {ConfigRemotaServicio? configRemota})
      : _configRemota = configRemota {
    cargarSuscripcion();
    // Refleja el rol de administrador en vivo: el perfil propio (con is_admin)
    // se sincroniza después de iniciar sesión, por lo que la carga inicial
    // puede no haberlo visto todavía.
    _perfilSub = (_db.select(_db.usuarios)
          ..where((u) => u.esPerfilPropio.equals(true)))
        .watch()
        .listen(_alCambiarPerfilPropio);
    _configRemota?.addListener(_onConfigCambiada);
  }

  void _onConfigCambiada() => notifyListeners();

  bool get _suscripcionesHabilitadas =>
      _configRemota?.suscripcionesHabilitadas ?? true;

  void _alCambiarPerfilPropio(List<Usuario> filas) {
    final admin = filas.isNotEmpty ? filas.first.isAdmin : false;
    if (admin != _esAdmin) {
      _esAdmin = admin;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _configRemota?.removeListener(_onConfigCambiada);
    _perfilSub?.cancel();
    _perfilSub = null;
    super.dispose();
  }

  /// true si el usuario logueado tiene rol de administrador (profiles.is_admin).
  /// En ese caso tiene acceso a todas las funciones sin importar el plan.
  bool get esAdmin => _esAdmin;

  PlanTipo get planActual =>
      (!_suscripcionesHabilitadas || _esAdmin) ? PlanTipo.premium : _planActual;
  Suscripcione? get suscripcionActual => _suscripcionActual;
  UsosDiario? get usosHoy => _usosHoy;

  bool get suscripcionesHabilitadas => _suscripcionesHabilitadas;

  LimitesPlan get limites {
    if (!_suscripcionesHabilitadas) return LimitesPlan.premium();
    return switch (planActual) {
      PlanTipo.gratis => LimitesPlan.gratis(),
      PlanTipo.plus => LimitesPlan.plus(),
      PlanTipo.premium => LimitesPlan.premium(),
    };
  }

  bool get esGratis =>
      _suscripcionesHabilitadas && !_esAdmin && _planActual == PlanTipo.gratis;
  bool get esPlus =>
      !_suscripcionesHabilitadas || (!_esAdmin && _planActual == PlanTipo.plus);
  bool get esPremium =>
      !_suscripcionesHabilitadas || _esAdmin || _planActual == PlanTipo.premium;

  bool get tienePlus =>
      !_suscripcionesHabilitadas ||
      _esAdmin ||
      _planActual.index >= PlanTipo.plus.index;
  bool get tienePremium =>
      !_suscripcionesHabilitadas ||
      _esAdmin ||
      _planActual == PlanTipo.premium;

  bool get meGustasDisponiblesHoy =>
      limites.meGustasPorDia.isNegative ||
      (_usosHoy?.meGustasUsados ?? 0) < limites.meGustasPorDia;

  bool get superlikesDisponiblesHoy =>
      limites.superlikesPorDia.isNegative ||
      (_usosHoy?.superlikesUsados ?? 0) < limites.superlikesPorDia;

  Future<void> cargarSuscripcion() async {
    final userList = await (_db.select(_db.usuarios)
          ..where((u) => u.esPerfilPropio.equals(true))
          ..limit(1))
        .get();
    final id = userList.isNotEmpty ? userList.first.uuid : null;
    if (id == null) return;

    await _cargarDesdeLocal(id);
    // Online-first: refresca plan y usos desde Supabase sin bloquear la UI;
    // al terminar vuelve a leer lo local y notifica.
    if (ConnectivityService.instancia.hayConexion) {
      unawaited(_refrescarDesdeRemoto(id));
    }
  }

  Future<void> _refrescarDesdeRemoto(String userId) async {
    await _sync.sincronizarSuscripciones(userId);
    await _sync.sincronizarUsosDiarios(userId);
    await _cargarDesdeLocal(userId);
  }

  /// Plan en reserva (pila de profundidad 1) y su vencimiento, si existen.
  String? get planReserva => _suscripcionActual?.planReserva;
  DateTime? get venceReserva => _suscripcionActual?.venceReserva;

  /// Momento en que se aparcó la reserva: restante = venceReserva - inicioReserva.
  DateTime? get inicioReserva => _suscripcionActual?.inicioReserva;

  /// Días restantes pausados en la reserva (null si no hay reserva válida).
  int? get diasReservaRestantes {
    final sub = _suscripcionActual;
    final inicio = sub?.inicioReserva;
    final vence = sub?.venceReserva;
    if (sub?.planReserva == null || inicio == null || vence == null) return null;
    final dias = vence.difference(inicio).inDays;
    return dias > 0 ? dias : 0;
  }

  /// true si hay reserva con tiempo restante esperando a activarse.
  /// La reserva está pausada: restante = venceReserva - inicioReserva.
  bool get tieneReservaVigente =>
      _reservaVigente(_suscripcionActual, DateTime.now());

  static bool _reservaVigente(Suscripcione? sub, DateTime ahora) {
    if (sub?.planReserva == null) return false;
    final inicio = sub!.inicioReserva;
    final vence = sub.venceReserva;
    // Pausada: el restante se fijó al cambiar de plan, no se erosiona.
    if (inicio != null && vence != null) return vence.isAfter(inicio);
    // Legacy sin inicio_reserva: criterio viejo (vence futuro).
    if (vence != null) return vence.isAfter(ahora);
    return true;
  }

  Future<dynamic> _supabaseRpc(String fn, Map<String, dynamic> params) =>
      Supabase.instance.client.rpc(fn, params: params);

  Future<void> _cargarDesdeLocal(String id) async {
    final perfil = await (_db.select(_db.usuarios)..where((u) => u.uuid.equals(id))).getSingleOrNull();
    _esAdmin = perfil?.isAdmin ?? false;
    var sub = await (_db.select(_db.suscripciones)..where((s) => s.usuarioId.equals(id))).getSingleOrNull();
    // Pila de planes: si el plan actual venció pero hay reserva con tiempo
    // restante, se promueve vía RPC (el usuario no puede escribir
    // suscripciones directo) y se recarga desde el servidor.
    final ahora = DateTime.now();
    final vigente = sub != null && sub.activa && (sub.vence == null || sub.vence!.isAfter(ahora));
    if (!vigente && _reservaVigente(sub, ahora)) {
      try {
        if (ConnectivityService.instancia.hayConexion && !kUsarServidorLocal) {
          await _supabaseRpc('promover_reserva', {});
          await _sync.sincronizarSuscripciones(id);
          sub = await (_db.select(_db.suscripciones)..where((s) => s.usuarioId.equals(id))).getSingleOrNull();
        }
      } catch (_) {}
    }
    _suscripcionActual = sub;
    final actual = sub;
    if (actual != null && actual.activa && (actual.vence == null || actual.vence!.isAfter(DateTime.now()))) {
      _planActual = PlanTipo.values.firstWhere(
        (p) => p.name == actual.plan,
        orElse: () => PlanTipo.gratis,
      );
    } else {
      _planActual = PlanTipo.gratis;
    }
    await _cargarUsosHoy(id);
    notifyListeners();
  }

  Future<void> _cargarUsosHoy(String userId) async {
    final hoy = DateTime.now();
    final inicioDia = DateTime(hoy.year, hoy.month, hoy.day);
    _usosHoy = await (_db.select(_db.usosDiarios)
          ..where((u) => u.usuarioId.equals(userId) & u.fecha.equals(inicioDia)))
        .getSingleOrNull();
    if (_usosHoy == null) {
      _usosHoy = UsosDiario(
        usuarioId: userId,
        fecha: inicioDia,
        meGustasUsados: 0,
        deshacerUsados: 0,
        superlikesUsados: 0,
        boostsUsados: 0,
        vistasCercaUsadas: 0,
      );
      await _db.into(_db.usosDiarios).insertOnConflictUpdate(_usosHoy!);
    }
  }

  /// Revalida de inmediato el espejo de usos contra el servidor (best-effort:
  /// sin conexión o error, se queda con lo local). El servidor es la fuente
  /// de verdad (el RPC valida el límite diario); el contador local es solo
  /// un espejo para no depender de la red en la UI.
  Future<void> _refrescarUsosDesdeRemoto(String userId) async {
    try {
      await _sync.sincronizarUsosDiarios(userId);
      await _cargarUsosHoy(userId);
    } catch (_) {}
  }

  Future<bool> puedeUsarMeGusta({bool revalidar = false}) async {
    if (revalidar) await _revalidarSiNecesario();
    if (!limites.meGustasPorDia.isNegative) {
      return (_usosHoy?.meGustasUsados ?? 0) < limites.meGustasPorDia;
    }
    return true;
  }

  Future<bool> puedeUsarDeshacer() async {
    if (!limites.deshacerPorDia.isNegative) {
      return (_usosHoy?.deshacerUsados ?? 0) < limites.deshacerPorDia;
    }
    return true;
  }

  Future<bool> puedeUsarSuperlike({bool revalidar = false}) async {
    if (revalidar) await _revalidarSiNecesario();
    if (!limites.superlikesPorDia.isNegative) {
      return (_usosHoy?.superlikesUsados ?? 0) < limites.superlikesPorDia;
    }
    return true;
  }

  Future<bool> puedeVerCerca() async {
    if (!limites.vistasCercaPorDia.isNegative) {
      return (_usosHoy?.vistasCercaUsadas ?? 0) < limites.vistasCercaPorDia;
    }
    return true;
  }

  Future<void> _revalidarSiNecesario() async {
    final userList = await (_db.select(_db.usuarios)
          ..where((u) => u.esPerfilPropio.equals(true))
          ..limit(1))
        .get();
    final userId = userList.isNotEmpty ? userList.first.uuid : null;
    if (userId == null) return;
    // Revalida solo si el espejo local dice "sin cupo", para no bloquear
    // por un contador rancio (p. ej. tras limpiar el remoto de pruebas).
    final meGustasBloqueadoPorEspejo =
        !limites.meGustasPorDia.isNegative &&
            (_usosHoy?.meGustasUsados ?? 0) >= limites.meGustasPorDia;
    final superlikesBloqueadoPorEspejo =
        !limites.superlikesPorDia.isNegative &&
            (_usosHoy?.superlikesUsados ?? 0) >= limites.superlikesPorDia;
    if (meGustasBloqueadoPorEspejo || superlikesBloqueadoPorEspejo) {
      await _refrescarUsosDesdeRemoto(userId);
    }
  }

  Future<bool> puedeVerVisitas(int visitasActuales) async {
    if (!limites.verVisitas) return false;
    if (limites.visitasLimite.isNegative) return true;
    return visitasActuales < limites.visitasLimite;
  }

  Future<bool> puedeVerHistorialLikes(int likesActuales) async {
    if (!limites.historialLikes) return false;
    if (limites.historialLikesLimite.isNegative) return true;
    return likesActuales < limites.historialLikesLimite;
  }

  Future<void> registrarMeGusta() async => _incrementar((u) => u.copyWith(meGustasUsados: u.meGustasUsados + 1));
  Future<void> registrarDeshacer() async => _incrementar((u) => u.copyWith(deshacerUsados: u.deshacerUsados + 1));
  Future<void> registrarSuperlike() async => _incrementar((u) => u.copyWith(superlikesUsados: u.superlikesUsados + 1));
  Future<void> registrarVistaCerca() async => _incrementar((u) => u.copyWith(vistasCercaUsadas: u.vistasCercaUsadas + 1));

  Future<void> _incrementar(UsosDiario Function(UsosDiario) actualizar) async {
    final userList = await (_db.select(_db.usuarios)
          ..where((u) => u.esPerfilPropio.equals(true))
          ..limit(1))
        .get();
    final userId = userList.isNotEmpty ? userList.first.uuid : null;
    if (userId == null || _usosHoy == null) return;
    final nuevo = actualizar(_usosHoy!);
    await _db.into(_db.usosDiarios).insertOnConflictUpdate(nuevo);
    _usosHoy = nuevo;
    notifyListeners();
    // Write-through: intenta subir los usos a Supabase de inmediato.
    unawaited(_sync.sincronizarUsosDiarios(userId));
  }

  /// Helper SOLO local (tests/servidor local): no es el flujo de compra real
  /// (ese pasa por solicitar_pago/verificar_pago en Supabase). Con el sync
  /// solo-descarga, lo que se active aquí se sobrescribe con el servidor en
  /// el próximo sync si difiere.
  Future<void> activarPlan(PlanTipo plan, {Duration? duracion}) async {
    final userList = await (_db.select(_db.usuarios)
          ..where((u) => u.esPerfilPropio.equals(true))
          ..limit(1))
        .get();
    final userId = userList.isNotEmpty ? userList.first.uuid : null;
    if (userId == null) return;

    final inicio = DateTime.now();
    final vence = duracion != null ? inicio.add(duracion) : null;

    final comp = SuscripcionesCompanion(
      usuarioId: Value(userId),
      plan: Value(plan.name),
      inicio: Value(inicio),
      vence: Value(vence),
      activa: const Value(true),
      // Una activación fresca no hereda reservas rancias.
      planReserva: const Value(null),
      venceReserva: const Value(null),
      inicioReserva: const Value(null),
    );
    await _db.into(_db.suscripciones).insertOnConflictUpdate(comp);
    _planActual = plan;
    notifyListeners();
    // Write-through: intenta subir el plan a Supabase de inmediato.
    await _sync.sincronizarSuscripciones(userId);
  }

  Future<void> renovarSiVencio() async {
    if (_suscripcionActual != null &&
        _suscripcionActual!.vence != null &&
        _suscripcionActual!.vence!.isBefore(DateTime.now())) {
      await activarPlan(PlanTipo.gratis);
    }
  }
}

extension IntNullableExt on int {
  bool get isNegative => this < 0;
}