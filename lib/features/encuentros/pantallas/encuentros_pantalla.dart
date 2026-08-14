import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/utilidades/fotos_perfil.dart';
import 'package:swipe_cards/draggable_card.dart';
import 'package:swipe_cards/swipe_cards.dart';
import '../../../core/api/mock_data.dart';
import '../../../core/base_datos_local/database.dart';
import '../../../core/estilos/tema.dart';
import '../../../core/servicios/notificacion_servicio.dart';
import '../../../core/servicios/suscripcion_servicio.dart';
import '../../../core/servicios/visitas_historial_servicio.dart';
import '../../../core/servicios/votos_servicio.dart';
import '../../../widgets_comunes/barra_progreso_rio.dart';
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
  final SuscripcionServicio suscripcionServicio;
  final VisitasServicio visitasServicio;
  final HistorialLikesServicio historialLikesServicio;
  final VotosServicio votosServicio;

  const EncuentrosPantalla({
    super.key,
    required this.db,
    required this.miId,
    required this.filtros,
    required this.undoSignal,
    required this.suscripcionServicio,
    required this.visitasServicio,
    required this.historialLikesServicio,
    required this.votosServicio,
  });

  @override
  State<EncuentrosPantalla> createState() => _EncuentrosPantallaState();
}

class _EncuentrosPantallaState extends State<EncuentrosPantalla> {
  List<Usuario> _usuarios = [];
  List<Usuario> _filtrados = [];
  Set<String> _idsGustados = {};
  Set<String> _idsRecibidos = {};
  bool _cargando = true;
  int _progresoFoto = 0;
  int _motorBase = 0;
  bool _agotado = false;
  int _motorId = 0;
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
    widget.votosServicio.addListener(_alCambiarVotos);
    _cargar();
  }

  @override
  void dispose() {
    _timerBloqueo?.cancel();
    _matchEngine?.removeListener(_alCambiarCarta);
    widget.undoSignal.removeListener(_undo);
    _suscripcion.removeListener(_alCambiarSuscripcion);
    widget.votosServicio.removeListener(_alCambiarVotos);
    super.dispose();
  }

  MatchEngine _crearMotor(List<Usuario> lista) {
    return MatchEngine(
      swipeItems: [
        for (final u in lista)
          SwipeItem(
            content: u,
            likeAction: () => _aplicarMeGusta(u),
            superlikeAction: () => _superlike(u),
            nopeAction: () => widget.votosServicio.registrarRechazo(u.uuid),
            onSlideUpdate: (region) async => _gestoSeguimiento(region),
          ),
      ],
    )..addListener(_alCambiarCarta);
  }

  void _alCambiarVotos() {
    if (!mounted || _cargando) return;
    final engine = _matchEngine;
    final actual = engine?.currentItem?.content as Usuario?;
    final referente = (actual != null &&
            !widget.votosServicio.esRechazado(actual.uuid))
        ? actual
        : engine?.nextItem?.content as Usuario?;
    setState(() {
      final sinRechazados = _filtrados
          .where((u) => !widget.votosServicio.esRechazado(u.uuid))
          .toList();
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
  }

  Future<void> _undo() async {
    final engine = _matchEngine;
    if (engine == null) return;
    if (_agotado) {
      if (_filtrados.isEmpty) return;
      final puede = await _suscripcion.puedeUsarDeshacer();
      if (!puede && mounted) {
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
        return;
      }
      await _suscripcion.registrarDeshacer();
      setState(() {
        _agotado = false;
        _motorBase = _filtrados.length - 1;
        _progresoFoto = 0;
        _motorId++;
        _matchEngine = _crearMotor(_filtrados.sublist(_motorBase));
      });
      if (_filtrados.isNotEmpty) {
        widget.votosServicio.quitarRechazo(_filtrados[_motorBase].uuid);
      }
    } else if (engine.currentItem != null) {
      final puede = await _suscripcion.puedeUsarDeshacer();
      if (!puede && mounted) {
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
        return;
      }
      await _suscripcion.registrarDeshacer();
      engine.rewindMatch();
      setState(() => _progresoFoto = 0);
      final revivido = engine.currentItem?.content as Usuario?;
      if (revivido != null) {
        widget.votosServicio.quitarRechazo(revivido.uuid);
      }
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
      final todos = await (widget.db.select(widget.db.usuarios)).get();
      todos.removeWhere((u) => u.uuid == widget.miId || u.esPerfilPropio);
      if (mounted) {
        setState(() {
          _usuarios = todos;
          _idsGustados =
              GeneradorMock.obtenerMisLikes().map((i) => i.usuarioId).toSet();
          _idsRecibidos = GeneradorMock.obtenerLikesRecibidos()
              .map((i) => i.usuarioId)
              .toSet();
          _cargando = false;
        });
        _aplicarFiltros();
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _aplicarFiltros() {
    final f = widget.filtros;
    var lista = List<Usuario>.from(_usuarios);

    if (f.generos.isNotEmpty) {
      lista.removeWhere((u) => !f.generos
          .any((g) => normalizarGenero(u.genero) == normalizarGenero(g)));
    }

    lista.removeWhere(
        (u) => u.edad < f.edadRango.start.toInt() || u.edad > f.edadRango.end.toInt());

    if (f.enLineaAhora) {
      lista.removeWhere((u) => !_estaEnLinea(u));
    }

    if (f.perfilesVerificados) {
      lista.removeWhere((u) => !u.verificadoStatus);
    }

    final ubicacion = f.ubicacion.trim().toLowerCase();
    if (ubicacion.isNotEmpty) {
      lista.removeWhere((u) => !u.ciudad.toLowerCase().contains(ubicacion));
    }

    lista.removeWhere((u) => !cumpleFiltrosAvanzados(f, u));

    lista.removeWhere((u) => _idsGustados.contains(u.uuid));

    lista.removeWhere((u) => widget.votosServicio.esRechazado(u.uuid));

    setState(() {
      _filtrados = lista;
      _motorBase = 0;
      _agotado = false;
      _progresoFoto = 0;
      _motorId++;
      _matchEngine = _crearMotor(lista);
    });
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No hay m\u00e1s perfiles',
                style: TextStyle(fontSize: 18, color: Colors.grey[500])),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() => _cargando = true);
                _cargar();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: FlumiTema.colorPrimario,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
                minimumSize: const Size(200, 48),
              ),
              child: const Text('Recargar'),
            ),
          ],
        ),
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
              itemBuilder: (context, index) =>
                  _tarjeta(_filtrados[_motorBase + index]),
              onStackFinished: () => setState(() => _agotado = true),
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
      onRechazar: () => _matchEngine?.currentItem?.nope(),
      onChat: () => _abrirChat(usuario),
      onMeGusta: () => _meGusta(usuario),
      mostrarProgreso: false,
      onFotoCambio: (i) => setState(() => _progresoFoto = i),
      esMatch: gustado && _idsRecibidos.contains(usuario.uuid),
      esMeGusta: gustado,
    );
  }

  Future<void> _meGusta(Usuario usuario) async {
    final puede = await _suscripcion.puedeUsarMeGusta();
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

  void _aplicarMeGusta(Usuario usuario) {
    _suscripcion.registrarMeGusta();
    _historialLikes.registrarLike(usuario.uuid);
    widget.votosServicio.quitarRechazo(usuario.uuid);
    if (_idsRecibidos.contains(usuario.uuid) && mounted) {
      _abrirMatch(usuario);
    }
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
        ),
      ),
    );
  }

  void _superlike(Usuario usuario) async {
    final puede = await _suscripcion.puedeUsarSuperlike();
    if (!puede && mounted) {
      _mostrarBloqueoSuperlike();
      return;
    }
    await _suscripcion.registrarSuperlike();
    await _historialLikes.registrarLike(usuario.uuid);
    if (_idsRecibidos.contains(usuario.uuid)) {
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: const Column(
          children: [
            Expanded(
              flex: 7,
              child: ShimmerCaja(radius: 0),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShimmerCaja(width: 200, height: 22),
                      SizedBox(height: 12),
                      ShimmerCaja(width: 100, height: 16),
                      SizedBox(height: 12),
                      ShimmerCaja(width: 200, height: 14),
                      SizedBox(height: 6),
                      ShimmerCaja(width: 160, height: 14),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
