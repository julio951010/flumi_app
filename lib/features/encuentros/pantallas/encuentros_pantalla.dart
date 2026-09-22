import 'dart:async';

import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../core/utilidades/fotos_perfil.dart';
import 'package:swipe_cards/draggable_card.dart';
import 'package:swipe_cards/swipe_cards.dart';
import '../../../core/base_datos_local/database.dart';
import '../../../config/env.dart';
import '../../../core/constantes/constantes.dart';
import '../../../core/servicios/connectivity_service.dart';
import '../../../core/servicios/notificacion_local_servicio.dart';
import '../../../core/servicios/notificacion_servicio.dart';
import '../../../core/servicios/suscripcion_servicio.dart';
import '../../../core/servicios/sync_service.dart';
import '../../../core/servicios/visitas_historial_servicio.dart';
import '../../../core/servicios/votos_servicio.dart';
import '../../../widgets_comunes/barra_progreso_rio.dart';
import '../../../widgets_comunes/estado_vacio_encuentros.dart';
import '../../../widgets_comunes/shimmer_caja.dart';
import '../../../widgets_comunes/tarjeta_detalle_usuario.dart';
import '../../chat/chat_repositorio.dart';
import '../../chat/pantallas/chat_pantalla.dart';
import '../../suscripcion/suscripcion_sheet.dart';
import 'filtros_encuentros_sheet.dart';
import 'match_pantalla.dart';
import '../../perfiles/pantallas/detalle_plan_pantalla.dart';

class EncuentrosPantalla extends StatefulWidget {
  final AppDatabase db;
  final String miId;
  final FiltrosEncuentros filtros;
  final ValueNotifier<int> undoSignal;
  final SyncService syncService;
  final SuscripcionServicio suscripcionServicio;
  final VisitasServicio visitasServicio;
  final HistorialLikesServicio historialLikesServicio;
  final VotosServicio votosServicio;
  final VoidCallback? onAmpliarBusqueda;
  final VoidCallback? onMatchPerdido;

  const EncuentrosPantalla({
    super.key,
    required this.db,
    required this.miId,
    required this.filtros,
    required this.undoSignal,
    required this.syncService,
    required this.suscripcionServicio,
    required this.visitasServicio,
    required this.historialLikesServicio,
    required this.votosServicio,
    this.onAmpliarBusqueda,
    this.onMatchPerdido,
  });

  @override
  State<EncuentrosPantalla> createState() => _EncuentrosPantallaState();
}

class _EncuentrosPantallaState extends State<EncuentrosPantalla> {
  static const _loteTamanio = 10;
  static const _umbralCola = 3;

  List<Usuario> _usuarios = [];
  List<Usuario> _filtrados = [];
  Usuario? _propio;
  Set<String> _idsGustados = {};
  Set<String> _idsRecibidos = {};
  Set<String> _idsSuperRecibidos = {};
  bool _cargando = true;
  int _progresoFoto = 0;
  int _motorBase = 0;
  bool _agotado = false;
  int _motorId = 0;
  int _consumidasEnMotor = 0;
  int _offset = 0;
  bool _hayMasRemoto = true;
  bool _cargandoMas = false;
  bool _amplitudAplicada = false;
  bool _reciclando = false;
  MatchEngine? _matchEngine;
  late final ChatRepositorio _chatRepo = ChatRepositorio(widget.db);
  late final SuscripcionServicio _suscripcion = widget.suscripcionServicio;
  late final VisitasServicio _visitas = widget.visitasServicio;
  late final HistorialLikesServicio _historialLikes = widget.historialLikesServicio;

  @override
  void initState() {
    super.initState();
    widget.undoSignal.addListener(_undo);
    _suscripcion.addListener(_alCambiarSuscripcion);
    // NOTA: no escuchamos a votosServicio aquí a propósito. Cada nope
    // llamaba a _alCambiarVotos, que recreaba el MatchEngine con índice 0 y
    // expulsaba el perfil del _filtrados: rewindMatch() quedaba sin historial
    // (su guard `_currentItemIndex != 0` fallaba) y el deshacer "no hacía nada".
    // El avance tras un nope lo hace el propio engine vía cycleMatch; la
    // recomposición solo se invoca explícitamente tras cargar más (_cargarMas)
    // o al reinsertar en _undo.
    _cargar();
  }

  @override
  void dispose() {
    _timerBloqueo?.cancel();
    _matchEngine?.removeListener(_alCambiarCarta);
    widget.undoSignal.removeListener(_undo);
    _suscripcion.removeListener(_alCambiarSuscripcion);
    super.dispose();
  }

  MatchEngine _crearMotor(List<Usuario> lista) {
    _consumidasEnMotor = 0;
    return MatchEngine(
      swipeItems: [
        for (final u in lista)
          SwipeItem(
            content: u,
            likeAction: () => _aplicarMeGusta(u),
            superlikeAction: () => _superlike(u),
            nopeAction: () {
              widget.votosServicio.registrarRechazo(u.uuid);
              // Nopear a alguien que ya te dio Me Gusta = match perdido.
              unawaited(_avisarMatchPerdido(u));
            },
            onSlideUpdate: (region) async => _gestoSeguimiento(region),
          ),
      ],
    )..addListener(_alCambiarCarta);
}

/// Si [usuario] ya te dio Me Gusta al momento del Nope, avisa que se
  /// perdió un match. Rechequea contra la BD local por si el like llegó
  /// después de cargar el mazo (realtime), que `_idsRecibidos` no habría
  /// capturado; si la BD aún no lo tiene y hay red, refresca el historial
  /// desde el servidor antes de decidir.
  Future<void> _avisarMatchPerdido(Usuario usuario) async {
    var leDioLike = _idsRecibidos.contains(usuario.uuid);
    debugPrint('[MatchPerdido] ${usuario.nombre}: enIdsRecibidos=$leDioLike');
    if (!leDioLike) {
      try {
        final miId = widget.miId;
        var filas =
            await (widget.db.select(widget.db.historialLikes)
                  ..where((h) =>
                      h.usuarioLikeadoId.equals(miId) &
                      h.usuarioId.equals(usuario.uuid)))
                .get();
        if (filas.isEmpty &&
            (ConnectivityService.instancia.hayConexion || kUsarServidorLocal)) {
          await widget.syncService.sincronizarHistorialLikes();
          filas =
              await (widget.db.select(widget.db.historialLikes)
                    ..where((h) =>
                        h.usuarioLikeadoId.equals(miId) &
                        h.usuarioId.equals(usuario.uuid)))
                  .get();
        }
        leDioLike = filas.isNotEmpty;
        debugPrint(
            '[MatchPerdido] rechequeo BD -> $leDioLike (${filas.length} filas)');
      } catch (e) {
        debugPrint('[MatchPerdido] error al rechequear: $e');
        leDioLike = false;
      }
    }
    if (leDioLike) {
      _idsRecibidos.add(usuario.uuid);
      // El aviso se muestra como tooltip sobre el botón Deshacer (header).
      widget.onMatchPerdido?.call();
    }
  }

  /// Recomposición explícita tras cargar más perfiles (llamada manual desde
  /// [_cargarMas]). Ya NO es listener automático de votos (ver initState).
  void _alCambiarVotos() {
    if (!mounted || _cargando) return;
    final engine = _matchEngine;
    final actual = engine?.currentItem?.content as Usuario?;
    final referente = (actual != null &&
            !widget.votosServicio.esRechazado(actual.uuid))
        ? actual
        : engine?.nextItem?.content as Usuario?;
    // Se suelta el listener del motor viejo antes de reemplazarlo para no
    // acumular conteos de _consumidasEnMotor.
    _matchEngine?.removeListener(_alCambiarCarta);
    setState(() {
      final sinRechazados = widget.votosServicio.componerDeck(_filtrados);
      if (sinRechazados.isEmpty) {
        _filtrados = sinRechazados;
        _agotado = true;
        return;
      }
      _filtrados = sinRechazados;
      _agotado = false;
      _motorBase = _filtrados.indexWhere((u) => u.uuid == referente?.uuid);
      if (_motorBase < 0) _motorBase = 0;
      _progresoFoto = 0;
      _motorId++;
      _matchEngine = _crearMotor(_filtrados.sublist(_motorBase));
    });
  }

  void _alCambiarSuscripcion() {
    if (mounted) setState(() {});
  }

  int get _totalFotosActual {
    final actual = _matchEngine?.currentItem?.content as Usuario?;
    if (actual == null) return 4;
    final fotos = fotosParaMostrar(actual);
    return fotos.isEmpty ? 4 : fotos.length;
  }

  bool _avisadoBloqueo = false;
  Timer? _timerBloqueo;

  void _gestoSeguimiento(SlideRegion? region) {
    final meGustaBloqueado = region == SlideRegion.inLikeRegion &&
        !_suscripcion.meGustasDisponiblesHoy;
    final superlikeBloqueado = region == SlideRegion.inSuperLikeRegion &&
        !_suscripcion.superlikesDisponiblesHoy;
    if (meGustaBloqueado || superlikeBloqueado) {
      if (_avisadoBloqueo) return;
      _avisadoBloqueo = true;
      final esSuperlike = superlikeBloqueado;
      _timerBloqueo?.cancel();
      _timerBloqueo = Timer(const Duration(milliseconds: 300), () {
        _timerBloqueo = null;
        if (!mounted) return;
        if (esSuperlike) {
          _mostrarBloqueoSuperlike();
        } else {
          _mostrarBloqueoMeGusta();
        }
      });
    } else if (region == null) {
      _avisadoBloqueo = false;
    }
  }

  void _alCambiarCarta() {
    if (mounted) {
      setState(() {
        _progresoFoto = 0;
      });
    }
    // Fase 2: carga predictiva. Cuando quedan pocas cartas por consumir,
    // pedimos el siguiente lote en segundo plano para que la cola nunca se
    // sienta vacía.
    _consumidasEnMotor++;
    if (_cargandoMas || !_hayMasRemoto || _cargando) return;
    final restantes = _filtrados.length - _motorBase - _consumidasEnMotor;
    if (restantes <= _umbralCola) {
      unawaited(_cargarMas());
    }
  }

  bool _deshaciendo = false;

  Future<void> _undo() async {
    if (_deshaciendo) {
      debugPrint('[Deshacer] bloqueado: ya en curso');
      return;
    }
    final revividoId = widget.votosServicio.tomarUltimoNope();
    debugPrint('[Deshacer] tomarUltimoNope -> $revividoId');
    if (revividoId == null) {
      if (mounted) {
        NotificacionServicio.alerta(
            context, 'No hay movimientos que deshacer.');
      }
      return;
    }

    _deshaciendo = true;
    // Feedback inmediato en móvil (sin esperar red).
    if (mounted) {
      // Pequeño haptic si está disponible en el dispositivo.
      try {
        // ignore: avoid_print
        debugPrint('[Deshacer] iniciando para $revividoId');
      } catch (_) {}
    }
    try {
      final concedido = await widget.votosServicio
          .quitarRechazo(revividoId)
          .timeout(const Duration(seconds: 7), onTimeout: () {
        debugPrint('[Deshacer] timeout quitarRechazo, fallback local');
        return true;
      });
      if (!concedido) {
        // No se consumió nada: se devuelve el id al historial para poder
        // reintentar cuando haya cupo.
        widget.votosServicio.reponerNope(revividoId);
        if (mounted) {
          // Defensa: si la app ya lo considera Plus/Premium/Admin, el
          // "límite" es un desajuste con el servidor (p. ej. RPC sin
          // desplegar), no un motivo de upsell. Se refresca la suscripción
          // y se avisa sin ofrecerle Plus a quien ya lo tiene.
          if (_suscripcion.tienePlus) {
            unawaited(_suscripcion.cargarSuscripcion());
            NotificacionServicio.advertencia(
              context,
              'No se pudo validar tu plan con el servidor. '
              'Revisa tu conexión e inténtalo de nuevo.',
            );
          } else {
            mostrarBloqueoSuscripcion(
              context,
              funcionalidad: 'Deshacer',
              planMinimo: PlanTipo.plus,
              descripcion:
                  'Has alcanzado el límite diario de deshacer (${_suscripcion.limites.deshacerPorDia}). Suscríbete a Flumi Plus para deshacer ilimitado.',
              onSuscribir: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DetallePlanPantalla(
                    nombre: 'Flumi Plus',
                    periodo: 'mensual',
                    precio: '250 cup',
                    icono: Icons.auto_awesome,
                    detalle: 'Funciones extra',
                    destacado: true,
                  ),
                ),
              ),
            );
          }
        }
        return;
      }

      try {
        await _suscripcion.registrarDeshacer().timeout(
            const Duration(seconds: 5), onTimeout: () {
          debugPrint('[Deshacer] timeout registrarDeshacer local');
        });
      } catch (e) {
        debugPrint('[Deshacer] registrarDeshacer error $e (ignorado)');
      }

      // Busca el perfil revivido: primero en la fuente completa (_usuarios),
      // luego en la BD local, luego intenta refrescar remoto (móvil con
      // memoria baja puede haber purgado la tabla).
      Usuario? revivido;
      for (final u in _usuarios) {
        if (u.uuid == revividoId) {
          revivido = u;
          break;
        }
      }
      revivido ??= await (widget.db.select(widget.db.usuarios)
            ..where((u) => u.uuid.equals(revividoId))
            ..limit(1))
          .getSingleOrNull();
      if (revivido == null && ConnectivityService.instancia.hayConexion) {
        try {
          await widget.syncService.refrescarPerfilRemoto(revividoId);
          revivido = await (widget.db.select(widget.db.usuarios)
                ..where((u) => u.uuid.equals(revividoId))
                ..limit(1))
              .getSingleOrNull();
        } catch (_) {}
      }
      if (revivido == null) {
        debugPrint('[Deshacer] no se encontró perfil $revividoId, reponiendo');
        widget.votosServicio.reponerNope(revividoId);
        if (mounted) {
          NotificacionServicio.advertencia(
              context, 'No se pudo recuperar el perfil deshecho.');
        }
        return;
      }
      final perfil = revivido;

      // Garantiza que la fuente completa lo conserve para futuras
      // recomposiciones (filtros, más lotes).
      if (!_usuarios.any((u) => u.uuid == perfil.uuid)) {
        _usuarios.insert(0, perfil);
      }

      if (!mounted) return;
      setState(() {
        _agotado = false;
        // Inserta el revivido justo delante de la carta actual para que sea
        // lo próximo que se vea. Si el mazo estaba vacío o agotado, queda
        // como única carta.
        final actual = _matchEngine?.currentItem?.content as Usuario?;
        var indiceInsercion = _filtrados
            .indexWhere((u) => actual != null && u.uuid == actual.uuid);
        if (indiceInsercion < 0) indiceInsercion = 0;
        _filtrados.removeWhere((u) => u.uuid == perfil.uuid);
        // Re-calcula por si el removeWhere movió el índice.
        if (indiceInsercion > _filtrados.length) {
          indiceInsercion = _filtrados.length;
        }
        _filtrados.insert(indiceInsercion, perfil);
        _motorBase = indiceInsercion;
        _progresoFoto = 0;
        _motorId++;
        _matchEngine?.removeListener(_alCambiarCarta);
        _matchEngine = _crearMotor(_filtrados.sublist(_motorBase));
      });
      if (mounted) {
        NotificacionServicio.exito(context, 'Deshecho.');
      }
    } finally {
      _deshaciendo = false;
    }
  }

  @override
  void didUpdateWidget(EncuentrosPantalla old) {
    super.didUpdateWidget(old);
    if (widget.filtros != old.filtros) {
      _aplicarFiltros();
    }
  }

  Future<void> _cargar() async {
    try {
      _offset = 0;
      _hayMasRemoto = true;
      _amplitudAplicada = false;
      _cargandoMas = false;

      // Fase 5: datos reales de interacción (adiós al mock) para no repetir
      // perfiles ya votados.
      final gustados = await widget.historialLikesServicio.obtenerIdsGustados();
      final recibidos = await widget.historialLikesServicio.obtenerLikesRecibidos();
      final superRecibidos =
          await widget.historialLikesServicio.obtenerIdsSuperRecibidos();
      _idsGustados = gustados;
      _idsRecibidos = recibidos;
      _idsSuperRecibidos = superRecibidos;

      // Criterios base del perfil propio: "interesado en" y "rango de edad".
      final propio = await (widget.db.select(widget.db.usuarios)
            ..where((u) => u.esPerfilPropio.equals(true))
            ..limit(1))
          .getSingleOrNull();
      _propio = propio;

      // Fase 1: primer lote del RPC + llenado hasta el tamaño mínimo de
      // cola para mostrar cartas de inmediato. Fase 2: si el RPC vuelve
      // vacío con los filtros actuales, se reintenta con ampliación en el
      // servidor (sin distancia, edad ni filtros del usuario) antes de
      // rendirse; las exclusiones (rechazos, gustados, bloqueos) se
      // mantienen en ambos modos.
      final acumulados = <Usuario>[];
      // Tope de llamadas remotas por carga (igual que en Cerca de ti).
      var intentos = 0;
      while (acumulados.length < _loteTamanio &&
          _hayMasRemoto &&
          intentos < 4) {
        intentos++;
        final lote = await _siguienteLote(conAmpliacion: _amplitudAplicada);
        if (lote.isEmpty) {
          if (!_amplitudAplicada) {
            _amplitudAplicada = true;
            _offset = 0;
            continue;
          }
          _hayMasRemoto = false;
          break;
        }
        _offset += lote.length;
        _hayMasRemoto = lote.length == _loteTamanio;
        acumulados.addAll(_filtrar(lote, conAmpliacion: _amplitudAplicada));
      }

      if (mounted) {
        setState(() {
          _usuarios = acumulados;
          _cargando = false;
        });
        _aplicarFiltros();
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  double get _miLat => _propio?.ubicacionLat ?? 0;
  double get _miLon => _propio?.ubicacionLon ?? 0;

  /// Siguiente lote desde el RPC `perfiles_cercanos` (paginación por offset
  /// en el servidor). Con `conAmpliacion` el servidor relaja todo menos las
  /// exclusiones (sin distancia, edad ni filtros del usuario).
  Future<List<Usuario>> _siguienteLote({bool conAmpliacion = false}) async {
    final f = widget.filtros;
    final radioMetros = conAmpliacion
        ? -1
        : (f.distanciaKm > 0
            ? (f.distanciaKm * 1000).round()
            : feedRadioMetrosDefault);
    return widget.syncService.consultarFeedRemoto(
      lat: _miLat,
      lon: _miLon,
      radioMetros: radioMetros,
      filtros: SyncService.filtrosARpcJson(
        generos: f.generos,
        edadMin: f.edadRango.start,
        edadMax: f.edadRango.end,
        enLineaAhora: f.enLineaAhora,
        perfilesVerificados: f.perfilesVerificados,
        ciudad: f.ubicacion,
        ampliar: conAmpliacion,
        orden: 'score',
      ),
      desde: _offset,
      cuantos: _loteTamanio,
    );
  }

  /// Carga predictiva en segundo plano (Fase 2): trae más perfiles cuando la
  /// cola se acerca al final y los encola sin interrumpir al usuario.
  Future<void> _cargarMas() async {
    if (_cargandoMas || !_hayMasRemoto || _cargando) return;
    _cargandoMas = true;
    try {
      var intentos = 0;
      while (_hayMasRemoto && intentos < 4) {
        intentos++;
        final lote = await _siguienteLote(conAmpliacion: _amplitudAplicada);
        if (lote.isEmpty) {
          if (!_amplitudAplicada) {
            _amplitudAplicada = true;
            _offset = 0;
            continue;
          }
          _hayMasRemoto = false;
          break;
        }
        _offset += lote.length;
        _hayMasRemoto = lote.length == _loteTamanio;
        final nuevas = _filtrar(lote, conAmpliacion: _amplitudAplicada);
        if (nuevas.isEmpty) continue;
        if (!mounted) return;
        final existentes = _usuarios.map((u) => u.uuid).toSet();
        _usuarios.addAll(nuevas.where((u) => !existentes.contains(u.uuid)));
        break;
      }
      // Reconstruye el motor preservando la posición del usuario. Primero
      // incorporamos el lote nuevo a la lista visible y luego el motor
      // re-deriva los rechazados y re-encola desde la carta actual.
      if (mounted && _cargandoMas) {
        setState(() => _filtrados = List.of(_usuarios));
        _alCambiarVotos();
      }
    } finally {
      _cargandoMas = false;
    }
  }

  /// Segunda vuelta al agotar el mazo: reencola los perfiles rechazados
  /// (más antiguo primero) para reconsiderarlos. Los gustados no vuelven
  /// (viven en Me Gusta/Matches). Si no hay nada que repasar, marca agotado.
  Future<void> _reciclarRechazados() async {
    if (!mounted || _cargando || _cargandoMas || _reciclando) return;
    _reciclando = true;
    try {
      final orden = widget.votosServicio.rechazadosPorAntiguedad();
      if (orden.isEmpty) {
        if (mounted) setState(() => _agotado = true);
        return;
      }
      final porId = {for (final u in _usuarios) u.uuid: u};
      // Completa desde la BD local por si el mazo se recargó.
      if (porId.length < orden.length) {
        try {
          final filas = await (widget.db.select(widget.db.usuarios)
                ..where((u) => u.uuid.isIn(orden)))
              .get();
          for (final u in filas) {
            porId.putIfAbsent(u.uuid, () => u);
            if (!_usuarios.any((e) => e.uuid == u.uuid)) _usuarios.add(u);
          }
        } catch (_) {}
      }
      var candidatos =
          _filtrar(orden.map((id) => porId[id]).nonNulls.toList(),
              conAmpliacion: _amplitudAplicada);
      // Sin los gustados: ya tienen su lugar en Me Gusta/Matches.
      candidatos.removeWhere((u) => _idsGustados.contains(u.uuid));
      // Si con los filtros actuales no queda nada, reintenta sin filtros
      // estrictos (solo criterios base del perfil) para cumplir el requisito:
      // "cuando no hay más perfiles, cargar los rechazados".
      if (candidatos.isEmpty && !_amplitudAplicada) {
        candidatos = _filtrar(
            orden.map((id) => porId[id]).nonNulls.toList(),
            conAmpliacion: true);
        candidatos.removeWhere((u) => _idsGustados.contains(u.uuid));
      }
      if (!mounted) return;
      if (candidatos.isEmpty) {
        setState(() => _agotado = true);
        return;
      }
      _matchEngine?.removeListener(_alCambiarCarta);
      setState(() {
        _filtrados = candidatos;
        _motorBase = 0;
        _agotado = false;
        _progresoFoto = 0;
        _motorId++;
        _matchEngine = _crearMotor(candidatos);
      });
    } finally {
      _reciclando = false;
    }
  }

  /// Aplica los filtros a [entrada]. Con `conAmpliacion` se relaja la
  /// búsqueda (sin distancia, en línea, rango de edad del filtro, etc.)
  /// tal y como exige el estado límite de la Fase 3; el género y el rango
  /// de edad ideal del perfil nunca se relajan.
  List<Usuario> _filtrar(List<Usuario> entrada, {bool conAmpliacion = false}) {
    final f = widget.filtros;
    var lista = List<Usuario>.from(entrada);

    // Criterios base del perfil ("¿A quién quieres conocer?" y rango de edad
    // ideal): se respetan SIEMPRE, también en la ampliación de la Fase 3.
    final propio = _propio;
    if (propio != null) {
      lista.removeWhere((u) => !cumpleCriteriosPerfil(propio, u));
    }

    if (!conAmpliacion && f.generos.isNotEmpty) {
      lista.removeWhere((u) => !f.generos
          .any((g) => normalizarGenero(u.genero) == normalizarGenero(g)));
    }

    final edadMin = conAmpliacion ? 18 : f.edadRango.start.toInt();
    final edadMax = conAmpliacion ? 99 : f.edadRango.end.toInt();
    lista.removeWhere((u) => u.edad < edadMin || u.edad > edadMax);

    if (!conAmpliacion && f.enLineaAhora) {
      lista.removeWhere((u) => !_estaEnLinea(u));
    }

    if (!conAmpliacion && f.perfilesVerificados) {
      lista.removeWhere((u) => !u.verificadoStatus);
    }

    final ubicacion = f.ubicacion.trim().toLowerCase();
    if (!conAmpliacion && ubicacion.isNotEmpty) {
      lista.removeWhere((u) => !u.ciudad.toLowerCase().contains(ubicacion));
    }

    if (!conAmpliacion) {
      lista.removeWhere((u) => !cumpleFiltrosAvanzados(f, u));
    }

    lista.removeWhere((u) => _idsGustados.contains(u.uuid));

    return lista;
  }

  void _aplicarFiltros() {
    var lista = _filtrar(_usuarios, conAmpliacion: _amplitudAplicada);

    // Fase 3: si se agotó la BD con el filtro actual, ampliamos
    // automáticamente (sin distancia ni rango de edad) antes de rendirnos.
    if (lista.isEmpty &&
        _usuarios.isNotEmpty &&
        !_hayMasRemoto &&
        !_amplitudAplicada) {
      final ampliados = _filtrar(_usuarios, conAmpliacion: true);
      if (ampliados.isNotEmpty) {
        _amplitudAplicada = true;
        lista = ampliados;
      }
    }

    // Regla de reciclaje de Nopes: nuevos primero; si quedan menos de 5 se
    // agregan al final los rechazos reciclables (más antiguos primero).
    lista = widget.votosServicio.componerDeck(lista);

    _matchEngine?.removeListener(_alCambiarCarta);
    setState(() {
      _filtrados = lista;
      _motorBase = 0;
      _agotado = false;
      _progresoFoto = 0;
      _motorId++;
      _matchEngine = _crearMotor(lista);
    });
  }

  void _ampliarBusqueda() {
    widget.onAmpliarBusqueda?.call();
    setState(() => _cargando = true);
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: _cuerpo(),
    );
  }

  Widget _cuerpo() {
    if (_cargando) return _esqueleto();
    if (_filtrados.isEmpty || _agotado) {
      if (_hayMasRemoto) {
        unawaited(_cargarMas());
      } else if (!_cargandoMas &&
          !_reciclando &&
          !_agotado &&
          widget.votosServicio.rechazadosPorAntiguedad().isNotEmpty) {
        // Sin más perfiles nuevos: segunda vuelta con los rechazados
        // (más antiguo primero). Se programa post-frame para no hacer
        // setState durante el build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _filtrados.isEmpty && !_agotado && !_hayMasRemoto) {
            unawaited(_reciclarRechazados());
          }
        });
        // Muestra carga mientras se recicla en vez del vacío inmediato.
        return _esqueleto();
      }
      return EstadoVacioEncuentros(
        mensaje: _filtrados.isEmpty
            ? 'No hay perfiles que coincidan con tus filtros'
            : 'No hay m\u00e1s perfiles por ahora',
        icono: Icons.person_search,
        onAmpliarBusqueda: widget.onAmpliarBusqueda != null
            ? () async => _ampliarBusqueda()
            : null,
        onRecargar: () async {
          setState(() => _cargando = true);
          await _cargar();
        },
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: BarraProgresoRio(
            progreso: (_progresoFoto + 1) / _totalFotosActual,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            child: SwipeCards(
              key: ValueKey(_motorId),
              matchEngine: _matchEngine!,
              onStackFinished: () {
                // Si aún quedan lotes en la BD, precargamos el siguiente en
                // vez de mostrar el vacío de inmediato.
                if (_hayMasRemoto && !_cargandoMas) {
                  unawaited(_cargarMas());
                  return;
                }
                // Sin más perfiles nuevos: segunda vuelta con los rechazados
                // para reconsiderar, del más antiguo al más reciente.
                unawaited(_reciclarRechazados());
              },
              itemBuilder: (context, index) {
                // El índice interno del engine (_currentItemIndex) puede quedar
                // desfasado al recomponer el mazo (Nope, votos, más lotes): nunca
                // indexamos fuera del rango real de _filtrados.
                if (_filtrados.isEmpty) return const SizedBox.shrink();
                final maxIndex = _filtrados.length - 1 - _motorBase;
                final seguro = index.clamp(0, maxIndex < 0 ? 0 : maxIndex);
                return _tarjeta(_filtrados[_motorBase + seguro]);
              },
              upSwipeAllowed: _suscripcion.superlikesDisponiblesHoy,
              rightSwipeAllowed: _suscripcion.meGustasDisponiblesHoy,
              fillSpace: true,
              likeTag: _suscripcion.meGustasDisponiblesHoy
                  ? _badgeSwipe(Icons.favorite, Colors.redAccent)
                  : null,
              nopeTag: _badgeSwipe(Icons.close, Colors.grey),
              superLikeTag: _suscripcion.superlikesDisponiblesHoy
                  ? _badgeSwipe(Icons.star, Colors.blueAccent)
                  : null,
              likeGradient: _suscripcion.meGustasDisponiblesHoy
                  ? _overlaySwipe(Colors.redAccent)
                  : null,
              nopeGradient: _overlaySwipe(Colors.grey),
              superLikeGradient: _suscripcion.superlikesDisponiblesHoy
                  ? _overlaySwipe(Colors.blueAccent)
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _tarjeta(Usuario usuario) {
    final gustado = _idsGustados.contains(usuario.uuid);
    return TarjetaDetalleUsuario(
      usuario: usuario,
      onRechazar: () => _nopeUsuario(usuario),
      onChat: () => _abrirChat(usuario),
      onMeGusta: () => _meGusta(usuario),
      mostrarProgreso: false,
      onFotoCambio: (i) => setState(() => _progresoFoto = i),
      onVerDetalles: () {
        try {
          _visitas.registrarVisita(usuario.uuid);
        } catch (_) {}
      },
      esMatch: gustado && _idsRecibidos.contains(usuario.uuid),
      esMeGusta: gustado,
      esSuperRecibido: _idsSuperRecibidos.contains(usuario.uuid),
    );
  }

  Future<void> _nopeUsuario(Usuario usuario) async {
    // El boton sigue el mismo camino que el gesto: decision=nope para que la
    // carta se anime a la izquierda y cycleMatch avance. Antes se llamaba a
    // rewindMatch(), que retrocede (y no hace nada en la primera carta), por
    // eso el boton parecia no funcionar.
    final engine = _matchEngine;
    final actual = engine?.currentItem?.content as Usuario?;
    if (actual != null && actual.uuid == usuario.uuid) {
      engine!.currentItem!.nope();
      return;
    }
    // Fallback: la carta no es la actual. Registra el rechazo y la quita de
    // la lista visible sin tocar _idsGustados (ese set es solo para likes).
    widget.votosServicio.registrarRechazo(usuario.uuid);
    unawaited(_avisarMatchPerdido(usuario));
    if (!mounted) return;
    setState(() {
      _filtrados.removeWhere((u) => u.uuid == usuario.uuid);
      if (!_agotado && _filtrados.length < 5 && _hayMasRemoto) {
        unawaited(_cargarMas());
      } else if (_filtrados.isEmpty) {
        _agotado = true;
      }
    });
  }

  Future<void> _meGusta(Usuario usuario) async {
    final puede = await _suscripcion.puedeUsarMeGusta(revalidar: true);
    if (!puede && mounted) {
      _mostrarBloqueoMeGusta();
      return;
    }
    _matchEngine?.currentItem?.like();
  }

  void _mostrarBloqueoMeGusta() {
    mostrarBloqueoSuscripcion(
      context,
      funcionalidad: 'Dar Me Gusta',
      planMinimo: PlanTipo.plus,
      descripcion:
          'Has alcanzado el límite diario de Me Gusta (${_suscripcion.limites.meGustasPorDia}). Suscríbete a Flumi Plus para Me Gustas ilimitados.',
      onSuscribir: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const DetallePlanPantalla(
            nombre: 'Flumi Plus',
            periodo: 'mensual',
            precio: '250 cup',
            icono: Icons.auto_awesome,
            detalle: 'Funciones extra',
            destacado: true,
          ),
        ),
      ),
    );
  }

  /// Devuelve la carta actual al mazo (el gesto ya la había avanzado pero
  /// el voto no quedó registrado).
  void _rebobinarCarta() {
    try {
      _matchEngine?.rewindMatch();
    } catch (_) {}
    if (mounted) setState(() => _progresoFoto = 0);
  }

  Future<void> _aplicarMeGusta(Usuario usuario) async {
    // Fase 3: el RPC valida el límite diario y confirma el match.
    final resultado = await _historialLikes.registrarLike(usuario.uuid);
    if (resultado?.limite == true) {
      _rebobinarCarta();
      if (mounted) _mostrarBloqueoMeGusta();
      return;
    }
    if (resultado == null && ConnectivityService.instancia.hayConexion) {
      // RPC falló teniendo red: el Me Gusta no se guardó ni se encoló.
      _rebobinarCarta();
      if (mounted) {
        NotificacionServicio.advertencia(context,
            'Fallo de conexión: el Me Gusta no se guardó. Inténtalo de nuevo.');
      }
      return;
    }
    _suscripcion.registrarMeGusta();
    widget.votosServicio.quitarRechazo(usuario.uuid, comoDeshacer: false);
    // El perfil gustado no vuelve a salir en el mazo (ni en el actual si se
    // recomponen las cartas).
    setState(() {
      _idsGustados.add(usuario.uuid);
      _filtrados.removeWhere((u) => u.uuid == usuario.uuid);
    });
    final matchSeguro =
        resultado?.match ?? _idsRecibidos.contains(usuario.uuid);
    if (matchSeguro && mounted) {
      _abrirMatch(usuario);
    }

    // Notificación inteligente: local si foreground, push si background
    unawaited(NotificacionLocalServicio.instancia.notificarInteligente(
      titulo: '¡Nuevo Me Gusta!',
      cuerpo: 'Le gustaste a ${usuario.nombre}',
      usuarioIdDestino: usuario.uuid,
      categoria: 'lesGusto',
    ));
  }

  bool _estaEnLinea(Usuario usuario) {
    if (usuario.ocultarEnLinea) return false;
    final conexion = usuario.ultimaConexion;
    if (conexion == null) return false;
    return DateTime.now().difference(conexion).inMinutes < 5;
  }

  void _abrirChat(Usuario usuario) {
    if (!_suscripcion.tienePremium &&
        !(_idsGustados.contains(usuario.uuid) &&
            _idsRecibidos.contains(usuario.uuid))) {
      mostrarBloqueoSuscripcion(
        context,
        funcionalidad: 'Enviar mensaje',
        planMinimo: PlanTipo.premium,
        descripcion:
            'Solo puedes chatear con personas con las que tengas match. Con Flumi Premium puedes enviar mensajes sin necesidad de match.',
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
      );
      return;
    }
Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPantalla(
            repositorio: _chatRepo,
            otroUsuarioId: usuario.uuid,
            miId: widget.miId,
            nombreOtro: usuario.nombre,
            online: _estaEnLinea(usuario),
            suscripcionServicio: widget.suscripcionServicio,
          ),
        ),
      );
  }

  void _superlike(Usuario usuario) async {
    final puede = await _suscripcion.puedeUsarSuperlike(revalidar: true);
    if (!puede && mounted) {
      _mostrarBloqueoSuperlike();
      return;
    }
    // Fase 3: el RPC valida el cupo de superlikes y confirma el match.
    final resultado =
        await _historialLikes.registrarLike(usuario.uuid, esSuper: true);
    if (resultado?.limite == true) {
      _rebobinarCarta();
      if (mounted) _mostrarBloqueoSuperlike();
      return;
    }
    if (resultado == null && ConnectivityService.instancia.hayConexion) {
      // RPC falló teniendo red: el Superlike no se guardó ni se encoló.
      _rebobinarCarta();
      if (mounted) {
        NotificacionServicio.advertencia(context,
            'Fallo de conexión: el Superlike no se guardó. Inténtalo de nuevo.');
      }
      return;
    }
    await _suscripcion.registrarSuperlike();
    // El perfil superlikeado no vuelve a salir en el mazo.
    setState(() {
      _idsGustados.add(usuario.uuid);
      _filtrados.removeWhere((u) => u.uuid == usuario.uuid);
    });
    if ((resultado?.match ?? _idsRecibidos.contains(usuario.uuid)) && mounted) {
      _abrirMatch(usuario);
    } else if (mounted) {
      NotificacionServicio.exito(context, 'Superlike enviado a ${usuario.nombre}');
    }
  }

  void _mostrarBloqueoSuperlike() {
    mostrarBloqueoSuscripcion(
      context,
      funcionalidad: 'Superlike',
      planMinimo: PlanTipo.plus,
      descripcion:
          'Has alcanzado el límite diario de Superlikes (${_suscripcion.limites.superlikesPorDia}). Suscríbete a Flumi Plus para más Superlikes diarios.',
      onSuscribir: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const DetallePlanPantalla(
            nombre: 'Flumi Plus',
            periodo: 'mensual',
            precio: '250 cup',
            icono: Icons.auto_awesome,
            detalle: 'Funciones extra',
            destacado: true,
          ),
        ),
      ),
    );
  }

  void _abrirMatch(Usuario usuario) {
    setState(() => _idsGustados.add(usuario.uuid));
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MatchPantalla(
          usuario: usuario,
          miId: widget.miId,
          chatRepo: _chatRepo,
          suscripcionServicio: widget.suscripcionServicio,
        ),
      ),
    );
  }

  Widget _badgeSwipe(IconData icono, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3),
        color: Colors.white.withValues(alpha: 0.95),
      ),
      child: Icon(icono, color: color, size: 26),
    );
  }

  Widget _overlaySwipe(Color color) {
    return Container(
      color: color.withValues(alpha: 0.35),
    );
  }

  Widget _esqueleto() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      child: Column(
        children: [
          Expanded(
            child: Container(
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  const Positioned.fill(child: ShimmerCaja(radius: 0)),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 140,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 20,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerCaja(width: 180, height: 22, radius: 6),
                        SizedBox(height: 8),
                        ShimmerCaja(width: 120, height: 18, radius: 9),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 110,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.65),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _fabEsqueleto(),
                        const SizedBox(width: 28),
                        _fabEsqueleto(),
                        const SizedBox(width: 28),
                        _fabEsqueleto(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fabEsqueleto() => Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: const ShimmerCaja(radius: 26),
      );
}
