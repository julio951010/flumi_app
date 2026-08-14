import 'package:flutter/material.dart';
import '../../../core/api/mock_data.dart';
import '../../../core/base_datos_local/database.dart';
import '../../../core/servicios/suscripcion_servicio.dart';
import '../../../core/servicios/visitas_historial_servicio.dart';
import '../../../core/servicios/votos_servicio.dart';
import '../../chat/chat_repositorio.dart';
import '../../chat/pantallas/chat_pantalla.dart';
import '../../../widgets_comunes/banner_gradiente.dart';
import '../../../widgets_comunes/shimmer_caja.dart';
import '../../../widgets_comunes/tarjeta_detalle_usuario.dart';
import '../../../widgets_comunes/tarjeta_usuario.dart';
import 'filtros_encuentros_sheet.dart';
import '../../suscripcion/suscripcion_sheet.dart';
import '../../perfiles/pantallas/detalle_plan_pantalla.dart';
import 'match_pantalla.dart';

class CercaDeTiPantalla extends StatefulWidget {
  final AppDatabase db;
  final String miId;
  final FiltrosEncuentros filtros;
  final SuscripcionServicio suscripcionServicio;
  final VisitasServicio visitasServicio;
  final HistorialLikesServicio historialLikesServicio;
  final VotosServicio votosServicio;

  const CercaDeTiPantalla({
    super.key,
    required this.db,
    required this.miId,
    required this.filtros,
    required this.suscripcionServicio,
    required this.visitasServicio,
    required this.historialLikesServicio,
    required this.votosServicio,
  });

  @override
  State<CercaDeTiPantalla> createState() => _CercaDeTiPantallaState();
}

class _CercaDeTiPantallaState extends State<CercaDeTiPantalla> {
  List<Usuario> _usuarios = [];
  List<Usuario> _filtrados = [];
  Set<String> _idsGustados = {};
  Set<String> _idsRecibidos = {};
  double _miLat = 0;
  double _miLon = 0;
  bool _cargando = true;
  late final ChatRepositorio _chatRepo = ChatRepositorio(widget.db);
  late final SuscripcionServicio _suscripcion = widget.suscripcionServicio;
  late final VisitasServicio _visitas = widget.visitasServicio;
  late final HistorialLikesServicio _historialLikes =
      widget.historialLikesServicio;

  @override
  void initState() {
    super.initState();
    widget.votosServicio.addListener(_aplicarFiltros);
    _cargar();
  }

  @override
  void dispose() {
    widget.votosServicio.removeListener(_aplicarFiltros);
    super.dispose();
  }

  @override
  void didUpdateWidget(CercaDeTiPantalla old) {
    super.didUpdateWidget(old);
    if (widget.filtros != old.filtros) {
      _aplicarFiltros();
    }
  }

  Future<void> _cargar() async {
    try {
      final todos = await (widget.db.select(widget.db.usuarios)).get();
      final propios =
          todos.where((u) => u.uuid == widget.miId || u.esPerfilPropio).toList();
      final propio = propios.isEmpty ? null : propios.first;
      todos.removeWhere((u) => u.uuid == widget.miId || u.esPerfilPropio);
      final idsGustados =
          GeneradorMock.obtenerMisLikes().map((i) => i.usuarioId).toSet();
      final idsRecibidos = GeneradorMock.obtenerLikesRecibidos()
          .map((i) => i.usuarioId)
          .toSet();
      todos.removeWhere((u) => idsGustados.contains(u.uuid));
      if (mounted) {
        setState(() {
          _usuarios = todos;
          _idsGustados = idsGustados;
          _idsRecibidos = idsRecibidos;
          _miLat = propio?.ubicacionLat ?? 0;
          _miLon = propio?.ubicacionLon ?? 0;
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
      lista.removeWhere((u) =>
          !f.generos.any((g) => normalizarGenero(u.genero) == normalizarGenero(g)));
    }

    lista.removeWhere((u) => u.edad < f.edadRango.start.toInt() ||
        u.edad > f.edadRango.end.toInt());

    if (f.enLineaAhora) {
      lista.removeWhere((u) => !_estaEnLinea(u));
    }

    if (f.perfilesVerificados) {
      lista.removeWhere((u) => !u.verificadoStatus);
    }

    if (f.distanciaKm > 0 && _miLat != 0 && _miLon != 0) {
      lista.removeWhere((u) {
        if (u.ubicacionLat == 0 && u.ubicacionLon == 0) return false;
        return distanciaKmEntre(_miLat, _miLon, u.ubicacionLat, u.ubicacionLon) >
            f.distanciaKm;
      });
    }

    lista.removeWhere((u) => !cumpleFiltrosAvanzados(f, u));

    lista.removeWhere((u) => widget.votosServicio.esRechazado(u.uuid));

    if (mounted) setState(() => _filtrados = lista);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return _esqueleto();
    if (_filtrados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No hay usuarios cerca',
                style: TextStyle(fontSize: 18, color: Colors.grey[500])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _bannerAd()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.72,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final gustado = _idsGustados.contains(_filtrados[i].uuid);
                  final esMatch =
                      gustado && _idsRecibidos.contains(_filtrados[i].uuid);
                  return TarjetaUsuario(
                    usuario: _filtrados[i],
                    onTap: () {
                      _abrirPerfil(_filtrados[i], gustado, esMatch);
                    },
                    esquinaDerecha: esMatch
                        ? const Icon(Icons.whatshot,
                            color: Colors.orangeAccent, size: 18)
                        : gustado
                            ? const Icon(Icons.favorite,
                                color: Colors.redAccent, size: 18)
                            : null,
                  );
                },
                childCount: _perfilesVisibles,
              ),
            ),
          ),
        ],
      ),
    );
  }

  int get _perfilesVisibles {
    final limite = _suscripcion.limites.vistasCercaPorDia;
    if (limite < 0 || _filtrados.length <= limite) return _filtrados.length;
    return limite;
  }

  void _abrirPerfil(Usuario usuario, bool gustado, bool esMatch) {
    try {
      _visitas.registrarVisita(usuario.uuid);
    } catch (_) {}
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PerfilDetallePage(
          usuario: usuario,
          esMeGusta: gustado,
          esMatch: esMatch,
          onChat: () => _abrirChat(usuario),
          onMeGusta: () => _meGusta(usuario),
          onRechazar: () {
            widget.votosServicio.registrarRechazo(usuario.uuid);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Future<bool> _meGusta(Usuario usuario) async {
    final puede = await _suscripcion.puedeUsarMeGusta();
    if (!puede) {
      _mostrarBloqueoMeGusta();
      return false;
    }
    _suscripcion.registrarMeGusta();
    _historialLikes.registrarLike(usuario.uuid);
    widget.votosServicio.quitarRechazo(usuario.uuid);
    if (mounted) {
      setState(() => _idsGustados.add(usuario.uuid));
    }
    if (!mounted) return true;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    if (_idsRecibidos.contains(usuario.uuid)) {
      _abrirMatch(usuario);
    }
    return true;
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

  bool _tieneMatch(Usuario usuario) =>
      _idsGustados.contains(usuario.uuid) &&
      _idsRecibidos.contains(usuario.uuid);

  void _abrirChat(Usuario usuario) {
    if (!_suscripcion.tienePremium && !_tieneMatch(usuario)) {
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

  bool _estaEnLinea(Usuario usuario) {
    if (usuario.ocultarEnLinea) return false;
    final conexion = usuario.ultimaConexion;
    if (conexion == null) return false;
    return DateTime.now().difference(conexion).inMinutes < 5;
  }

  Widget _bannerAd() {
    if (_suscripcion.tienePremium) return const SizedBox.shrink();
    if (_suscripcion.tienePlus) {
      return BannerGradiente(
        titulo: 'Ve todos los perfiles',
        subtitulo: 'Sin l\u00edmites de perfiles cerca de ti con Flumi Premium',
        etiquetaBoton: 'Ver plan',
        onTapBoton: () => Navigator.push(
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
    }
    return BannerGradiente(
      titulo: 'Impulsa tu perfil',
      subtitulo:
          'Llega a m\u00e1s personas cerca de ti (10 perfiles con Gratis)',
      etiquetaBoton: 'Ver plan',
      onTapBoton: () => Navigator.push(
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

  Widget _esqueleto() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.72,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
          ),
          child: const Column(
            children: [
              Expanded(child: ShimmerCaja(radius: 0)),
              Padding(
                padding: EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerCaja(width: 80, height: 14),
                    SizedBox(height: 4),
                    ShimmerCaja(width: 60, height: 11),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class PerfilDetallePage extends StatefulWidget {
  final Usuario usuario;
  final bool gusta;
  final bool esMatch;
  final bool esMeGusta;
  final bool soloVista;
  final VoidCallback? onChat;
  final VoidCallback? onRechazar;
  final Future<bool> Function()? onMeGusta;

  const PerfilDetallePage({
    super.key,
    required this.usuario,
    this.gusta = false,
    this.esMatch = false,
    this.esMeGusta = false,
    this.soloVista = false,
    this.onChat,
    this.onRechazar,
    this.onMeGusta,
  });

  @override
  State<PerfilDetallePage> createState() => _PerfilDetallePageState();
}

class _PerfilDetallePageState extends State<PerfilDetallePage> {
  late bool _esMeGusta = widget.esMeGusta;
  late bool _esMatch = widget.esMatch;
  late bool _gusta = widget.gusta;

  Future<void> _manejarMeGusta() async {
    final aplicar = widget.onMeGusta;
    if (aplicar == null) return;
    final aplicado = await aplicar();
    if (aplicado && mounted) {
      setState(() {
        _esMeGusta = true;
        _gusta = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 56, 16, 28),
                child: TarjetaDetalleUsuario(
                  usuario: widget.usuario,
                  esMatch: _esMatch,
                  esMeGusta: _esMeGusta,
                  onRechazar: widget.onRechazar ??
                      () => Navigator.pop(context),
                  onChat: widget.onChat,
                  gusta: _gusta,
                  soloVista: widget.soloVista,
                  onMeGusta: widget.soloVista ? null : _manejarMeGusta,
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: const Icon(Icons.arrow_back,
                      color: Colors.black87, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
