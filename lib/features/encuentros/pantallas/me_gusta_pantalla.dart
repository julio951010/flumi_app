import 'package:flutter/material.dart';
import '../../../core/api/mock_data.dart';
import '../../../core/base_datos_local/database.dart';
import '../../../core/servicios/suscripcion_servicio.dart';
import '../../../core/servicios/visitas_historial_servicio.dart';
import '../../chat/chat_repositorio.dart';
import '../../chat/pantallas/chat_pantalla.dart';
import '../../../widgets_comunes/banner_gradiente.dart';
import '../../../widgets_comunes/shimmer_caja.dart';
import '../../../widgets_comunes/tarjeta_usuario.dart';
import 'cerca_de_ti_pantalla.dart' show PerfilDetallePage;
import 'match_pantalla.dart';
import '../../suscripcion/suscripcion_sheet.dart';
import '../../perfiles/pantallas/detalle_plan_pantalla.dart';
import '../../perfiles/pantallas/quien_te_vio_pantalla.dart';
import '../../perfiles/pantallas/historial_likes_pantalla.dart';

class MeGustaPantalla extends StatefulWidget {
  final AppDatabase db;
  final String miId;
  final ContadorMeGusta contador;
  final SuscripcionServicio suscripcionServicio;
  final VisitasServicio visitasServicio;
  final HistorialLikesServicio historialLikesServicio;

  const MeGustaPantalla({
    super.key,
    required this.db,
    required this.miId,
    required this.contador,
    required this.suscripcionServicio,
    required this.visitasServicio,
    required this.historialLikesServicio,
  });

  @override
  State<MeGustaPantalla> createState() => _MeGustaPantallaState();
}

class _MeGustaPantallaState extends State<MeGustaPantalla>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late final ChatRepositorio _chatRepo = ChatRepositorio(widget.db);
  late final SuscripcionServicio _suscripcion = widget.suscripcionServicio;
  late final VisitasServicio _visitasServicio = widget.visitasServicio;
  late final HistorialLikesServicio _historialLikesServicio = widget.historialLikesServicio;
  List<_ItemInteraccion> _likes = [];
  List<_ItemInteraccion> _visitas = [];
  List<_ItemInteraccion> _misLikes = [];
  List<_ItemInteraccion> _matches = [];
  Set<String> _idsGustados = {};
  Set<String> _idsRecibidos = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _cargar();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final todos = await widget.db.select(widget.db.usuarios).get();
      final mapa = {for (final u in todos) u.uuid: u};

      _likes = GeneradorMock.obtenerLikesRecibidos()
          .map((i) => _ItemInteraccion(usuario: mapa[i.usuarioId], timestamp: i.timestamp))
          .where((i) => i.usuario != null)
          .toList();

      _visitas = GeneradorMock.obtenerVisitas()
          .map((i) => _ItemInteraccion(usuario: mapa[i.usuarioId], timestamp: i.timestamp))
          .where((i) => i.usuario != null)
          .toList();

      _misLikes = GeneradorMock.obtenerMisLikes()
          .map((i) => _ItemInteraccion(usuario: mapa[i.usuarioId], timestamp: i.timestamp))
          .where((i) => i.usuario != null)
          .toList();

      _idsGustados =
          GeneradorMock.obtenerMisLikes().map((i) => i.usuarioId).toSet();
      _idsRecibidos = GeneradorMock.obtenerLikesRecibidos()
          .map((i) => i.usuarioId)
          .toSet();

      _matches = _idsGustados
          .intersection(_idsRecibidos)
          .map((id) => _ItemInteraccion(
              usuario: mapa[id], timestamp: DateTime.now()))
          .where((i) => i.usuario != null)
          .toList();
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _formatoTiempo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays < 2) return 'Ayer';
    return 'Hace ${diff.inDays} d\u00edas';
  }

  @override
  Widget build(BuildContext context) {
    final puedeVerLikes = _suscripcion.tienePlus;
    final puedeVerVisitas = _suscripcion.tienePlus;
    final puedeVerMisLikes = _suscripcion.tienePlus;

    final hayContenido = _likes.isNotEmpty ||
        _visitas.isNotEmpty ||
        _misLikes.isNotEmpty ||
        _matches.isNotEmpty;
    final banner = hayContenido ? _bannerPlan() : null;

    return Column(
      children: [
        if (banner != null) banner,
        SizedBox(
          height: 42,
          child: ListenableBuilder(
            listenable: widget.contador,
            builder: (context, _) => TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: Colors.black87,
              labelColor: Colors.black87,
              unselectedLabelColor: Colors.grey,
              labelStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              padding: const EdgeInsets.only(left: 12),
              tabs: [
                Tab(
                  child: _tabConBadge(
                    etiqueta: 'Le gustas',
                    cantidad: widget.contador.likesNoLeidos,
                  ),
                ),
                Tab(
                  child: _tabConBadge(
                    etiqueta: 'Visitas',
                    cantidad: widget.contador.visitasNoLeidas,
                  ),
                ),
                Tab(
                  child: _tabConBadge(
                    etiqueta: 'Mis Likes',
                    cantidad: widget.contador.misLikesNoLeidos,
                  ),
                ),
                Tab(
                  child: _tabConBadge(
                    etiqueta: 'Matches',
                    cantidad: widget.contador.matchesNoLeidos,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _cargando
              ? _esqueleto()
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _grilla(_likes, puedeVerLikes, CategoriaMeGusta.likes),
                    puedeVerVisitas
                        ? QuienTeVioPantalla(
                            visitasServicio: _visitasServicio,
                            suscripcionServicio: _suscripcion,
                          )
                        : _grilla(_visitas, false, CategoriaMeGusta.visitas),
                    puedeVerMisLikes
                        ? HistorialLikesPantalla(
                            historialServicio: _historialLikesServicio,
                            suscripcionServicio: _suscripcion,
                          )
                        : _grilla(_misLikes, false, CategoriaMeGusta.misLikes),
                    _grilla(_matches, true, CategoriaMeGusta.matches),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _tabConBadge(
      {required String etiqueta, required int cantidad}) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(etiqueta,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              )),
          if (cantidad > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(10),
              ),
            child: Text(
              '$cantidad',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _esqueleto() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 70),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.72,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
            ],
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

  Widget? _bannerPlan() {
    if (_suscripcion.tienePremium) return null;
    if (_suscripcion.tienePlus) {
      return BannerGradiente(
        titulo: 'Sin l\u00edmites en Visitas y Mis Likes',
        subtitulo: 'Ilimitado con Flumi Premium',
        etiquetaBoton: 'Mejorar',
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
      titulo: 'Desbloquea Le gustas, Visitas y tu historial',
      subtitulo: 'Requiere Flumi Plus',
      etiquetaBoton: 'Ver planes',
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

  void _abrirChat(Usuario usuario) {
    if (!widget.suscripcionServicio.tienePremium &&
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

  bool _estaEnLinea(Usuario usuario) {
    if (usuario.ocultarEnLinea) return false;
    final conexion = usuario.ultimaConexion;
    if (conexion == null) return false;
    return DateTime.now().difference(conexion).inMinutes < 5;
  }

  Future<bool> _meGusta(Usuario usuario) async {
    final puede = await _suscripcion.puedeUsarMeGusta();
    if (!puede) {
      _mostrarBloqueoMeGusta();
      return false;
    }
    _suscripcion.registrarMeGusta();
    _historialLikesServicio.registrarLike(usuario.uuid);
    if (mounted) {
      setState(() => _idsGustados.add(usuario.uuid));
      if (_idsRecibidos.contains(usuario.uuid)) {
        _abrirMatch(usuario);
      }
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

  Widget _grilla(
      List<_ItemInteraccion> items, bool puedeVer, CategoriaMeGusta categoria) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Sin actividad por aqu\u00ed',
          style: TextStyle(color: Colors.grey[400], fontSize: 15),
        ),
      );
    }
    if (!puedeVer) {
      return _grillaBorrosa(items, categoria);
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 70),
        child: GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.72,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final usuario = item.usuario!;
            final tiempo = _formatoTiempo(item.timestamp);
            final gustado = _idsGustados.contains(usuario.uuid);
            final esMatch = gustado && _idsRecibidos.contains(usuario.uuid);

            return TarjetaUsuario(
              usuario: usuario,
              onTap: () {
                widget.contador.marcarVista(categoria, usuario.uuid);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PerfilDetallePage(
                      usuario: usuario,
                      esMeGusta: gustado,
                      esMatch: esMatch,
                      onChat: () => _abrirChat(usuario),
                      onMeGusta: () => _meGusta(usuario),
                    ),
                  ),
                );
              },
              imagenOverlay: null,
              esquinaDerecha: esMatch
                  ? const Icon(Icons.whatshot,
                      color: Colors.orangeAccent, size: 18)
                  : gustado
                      ? const Icon(Icons.favorite,
                          color: Colors.redAccent, size: 18)
                      : null,
              badge: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tiempo,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _grillaBorrosa(
      List<_ItemInteraccion> items, CategoriaMeGusta categoria) {
    return RefreshIndicator(
      onRefresh: _cargar,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 70),
        child: GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.72,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final usuario = item.usuario!;
            return TarjetaUsuario(
              usuario: usuario,
              imagenBorrosa: true,
              imagenOverlay: Container(
                color: Colors.black.withValues(alpha: 0.35),
                alignment: Alignment.center,
                child: const Icon(Icons.lock_outline,
                    color: Colors.white, size: 26),
              ),
              badge: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatoTiempo(item.timestamp),
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
              onTap: () => mostrarBloqueoSuscripcion(
                context,
                funcionalidad: _tituloCategoria(categoria),
                planMinimo: PlanTipo.plus,
                descripcion: _textoBloqueo(categoria),
              ),
            );
          },
        ),
      ),
    );
  }

  String _tituloCategoria(CategoriaMeGusta categoria) {
    switch (categoria) {
      case CategoriaMeGusta.likes:
        return 'Ver quién te dio Me Gusta';
      case CategoriaMeGusta.visitas:
        return 'Ver quién visitó tu perfil';
      case CategoriaMeGusta.misLikes:
        return 'Ver tu historial de likes';
      case CategoriaMeGusta.matches:
        return 'Chatear con tus matches';
    }
  }

  String _textoBloqueo(CategoriaMeGusta categoria) {
    switch (categoria) {
      case CategoriaMeGusta.likes:
        return 'Suscríbete a Flumi Plus para ver quién te dio Me Gusta.';
      case CategoriaMeGusta.visitas:
        return 'Suscríbete a Flumi Plus para ver quién visitó tu perfil (20 visitas/día).';
      case CategoriaMeGusta.misLikes:
        return 'Suscríbete a Flumi Plus para ver tu historial de likes (últimos 15).';
      case CategoriaMeGusta.matches:
        return 'Suscríbete a Flumi Plus para chatear con tus matches.';
    }
  }
}

class _ItemInteraccion {
  final Usuario? usuario;
  final DateTime timestamp;
  _ItemInteraccion({required this.usuario, required this.timestamp});
}

enum CategoriaMeGusta { likes, visitas, misLikes, matches }

class ContadorMeGusta extends ChangeNotifier {
  int _likes = 0;
  int _visitas = 0;
  int _misLikes = 0;
  int _matches = 0;
  final Set<String> _vistos = <String>{};

  int get likesNoLeidos => _likes;
  int get visitasNoLeidas => _visitas;
  int get misLikesNoLeidos => _misLikes;
  int get matchesNoLeidos => _matches;
  int get total => _likes + _visitas;

  void inicializar({
    required int likes,
    required int visitas,
    required int misLikes,
    required int matches,
  }) {
    _likes = likes;
    _visitas = visitas;
    _misLikes = misLikes;
    _matches = matches;
    notifyListeners();
  }

  void marcarVista(CategoriaMeGusta categoria, String usuarioId) {
    final clave = '${categoria.name}|$usuarioId';
    if (!_vistos.add(clave)) return;
    switch (categoria) {
      case CategoriaMeGusta.likes:
        if (_likes > 0) _likes--;
      case CategoriaMeGusta.visitas:
        if (_visitas > 0) _visitas--;
      case CategoriaMeGusta.misLikes:
        if (_misLikes > 0) _misLikes--;
      case CategoriaMeGusta.matches:
        if (_matches > 0) _matches--;
        break;
    }
    notifyListeners();
  }

  void marcarTodasVistas() {
    _likes = 0;
    _visitas = 0;
    _misLikes = 0;
    _matches = 0;
    notifyListeners();
  }
}
