import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/env.dart';
import '../../../core/base_datos_local/database.dart';
import '../../../core/servicios/connectivity_service.dart';
import '../../../core/servicios/suscripcion_servicio.dart';
import '../../../core/servicios/visitas_historial_servicio.dart';
import '../../../core/utilidades/perfil_mapeo.dart';
import '../../chat/chat_repositorio.dart';
import '../../chat/pantallas/chat_pantalla.dart';
import '../../../widgets_comunes/banner_gradiente.dart';
import '../../../widgets_comunes/shimmer_caja.dart';
import '../../../widgets_comunes/tarjeta_usuario.dart';
import 'cerca_de_ti_pantalla.dart' show PerfilDetallePage;
import 'match_pantalla.dart';
import '../../suscripcion/suscripcion_sheet.dart';
import '../../perfiles/pantallas/detalle_plan_pantalla.dart';

class MeGustaPantalla extends StatefulWidget {
  final AppDatabase db;
  final String miId;
  final ContadorMeGusta contador;
  final SuscripcionServicio suscripcionServicio;
  final VisitasServicio visitasServicio;
  final HistorialLikesServicio historialLikesServicio;
  final int indiceInicial;

  const MeGustaPantalla({
    super.key,
    required this.db,
    required this.miId,
    required this.contador,
    required this.suscripcionServicio,
    required this.visitasServicio,
    required this.historialLikesServicio,
    this.indiceInicial = 0,
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
  Set<String> _idsSuperRecibidos = {};
  bool _cargando = true;
  Timer? _recargaTimer;

  /// Completa [mapa] con los perfiles que faltan (visitantes/likers aún no
  /// descargados) en una sola consulta, para que las grillas muestren
  /// tarjetas reales en vez de descartarlos.
  Future<void> _enriquecerPerfiles(
      Map<String, Usuario> mapa, List<String> ids) async {
    final faltantes =
        ids.where((id) => !mapa.containsKey(id)).toSet().take(100).toList();
    if (faltantes.isEmpty) return;
    if (!ConnectivityService.instancia.hayConexion || kUsarServidorLocal) {
      return;
    }
    try {
      final remoto = await Supabase.instance.client
          .from('profiles')
          .select()
          .inFilter('id', faltantes);
      for (final r in remoto as List) {
        final m = Map<String, dynamic>.from(r as Map);
        final id = m['id'] as String?;
        if (id == null) continue;
        mapa[id] = PerfilMapeo.perfilRemotoAUsuario(m, esPropio: false);
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.indiceInicial,
    );
    // Fase 3: los likes/visitas llegan por Realtime; se refresca la lista
    // cuando el contador cambia (sin tocar nada).
    widget.contador.addListener(_alCambiarContador);
    _cargar();
  }

  void _alCambiarContador() {
    // Debounce: los eventos llegan en ráfagas (realtime + watch); recargar
    // solo local, sin golpear la red en cada uno.
    if (!mounted || _cargando) return;
    _recargaTimer?.cancel();
    _recargaTimer = Timer(
      const Duration(milliseconds: 1500),
      () {
        if (mounted && !_cargando) unawaited(_cargar(sincronizar: false));
      },
    );
  }

  @override
  void dispose() {
    widget.contador.removeListener(_alCambiarContador);
    _recargaTimer?.cancel();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar({bool sincronizar = true}) async {
    setState(() => _cargando = true);
    try {
      final todos = await widget.db.select(widget.db.usuarios).get();
      final mapa = {for (final u in todos) u.uuid: u};

      final recibidos = await _historialLikesServicio.obtenerLikesRecibidosDetalle(
          sincronizar: sincronizar);
      final gustados = await _historialLikesServicio.obtenerHistorial(
          sincronizar: sincronizar);
      final visitas = await _visitasServicio.obtenerVisitas(
          sincronizar: sincronizar);

      // Enriquece likers/visitantes sin perfil local (una sola consulta).
      await _enriquecerPerfiles(mapa, [
        ...recibidos.map((h) => h.usuarioId),
        ...gustados.map((h) => h.usuarioLikeadoId),
        ...visitas.map((v) => v.visitanteId),
      ]);

      _idsGustados = gustados.map((h) => h.usuarioLikeadoId).toSet();
      _idsRecibidos = recibidos.map((h) => h.usuarioId).toSet();
      _idsSuperRecibidos =
          recibidos.where((h) => h.esSuper).map((h) => h.usuarioId).toSet();

      // Los matches viven solo en su pestaña: se quitan de Le gustas,
      // Visitas y Me gustan para no repetirlos.
      final idsMatch = _idsGustados.intersection(_idsRecibidos);

      _likes = recibidos
          .map((h) => _ItemInteraccion(
              usuario: mapa[h.usuarioId], timestamp: h.timestamp))
          .where((i) =>
              i.usuario != null && !idsMatch.contains(i.usuario!.uuid))
          .toList();

      _visitas = visitas
          .map((v) => _ItemInteraccion(
              usuario: mapa[v.visitanteId], timestamp: v.timestamp))
          .where((i) =>
              i.usuario != null && !idsMatch.contains(i.usuario!.uuid))
          .toList();

      _misLikes = gustados
          .map((h) => _ItemInteraccion(
              usuario: mapa[h.usuarioLikeadoId], timestamp: h.timestamp))
          .where((i) =>
              i.usuario != null && !idsMatch.contains(i.usuario!.uuid))
          .toList();

      final timestampsRecibidos = {
        for (final h in recibidos) h.usuarioId: h.timestamp
      };
      _matches = idsMatch
          .map((id) => _ItemInteraccion(
              usuario: mapa[id],
              timestamp: timestampsRecibidos[id] ?? DateTime.now()))
          .where((i) => i.usuario != null)
          .toList();
      // Chips = interacciones no vistas. Se cuentan los ids crudos (sin
      // match) aunque el perfil aún no esté descargado: el chip cuenta
      // interacciones, la grilla solo muestra perfiles conocidos.
      widget.contador.reconciliar(
        likes: recibidos
            .where((h) => !idsMatch.contains(h.usuarioId))
            .map((h) => h.usuarioId)
            .toSet()
            .toList(),
        visitas: visitas
            .where((v) => !idsMatch.contains(v.visitanteId))
            .map((v) => v.visitanteId)
            .toSet()
            .toList(),
        misLikes: gustados
            .where((h) => !idsMatch.contains(h.usuarioLikeadoId))
            .map((h) => h.usuarioLikeadoId)
            .toSet()
            .toList(),
        matches: idsMatch.toList(),
      );
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
    // "Me gustan" siempre muestra las fotos claras (sin requisito de plan).

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
                    // Sin contenido cargado no hay chip: el contador global
                    // puede traer una foto provisional (inicializar) antes de
                    // que termine _cargar()/reconciliar().
                    cantidad: _cargando
                        ? 0
                        : widget.contador.likesNoLeidos,
                  ),
                ),
                Tab(
                  child: _tabConBadge(
                    etiqueta: 'Visitas',
                    cantidad: _cargando
                        ? 0
                        : widget.contador.visitasNoLeidas,
                  ),
                ),
                Tab(
                  child: _tabConBadge(
                    etiqueta: 'Me gustan',
                    cantidad: _cargando
                        ? 0
                        : widget.contador.misLikesNoLeidos,
                  ),
                ),
                Tab(
                  child: _tabConBadge(
                    etiqueta: 'Matches',
                    cantidad: _cargando
                        ? 0
                        : widget.contador.matchesNoLeidos,
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
                    _grilla(_visitas, puedeVerVisitas,
                        CategoriaMeGusta.visitas),
                    _grilla(_misLikes, true, CategoriaMeGusta.misLikes,
                        bloquearDetallesSinPlan: true),
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
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                  child: const ShimmerCaja(radius: 20),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ShimmerCaja(width: 80, height: 14),
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
        titulo: 'Sin l\u00edmites en Visitas',
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
      titulo: 'Desbloquea Le gustas y Visitas',
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
          suscripcionServicio: _suscripcion,
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
    final puede = await _suscripcion.puedeUsarMeGusta(revalidar: true);
    if (!puede) {
      _mostrarBloqueoMeGusta();
      return false;
    }
    // Fase 3: el RPC valida el límite diario y confirma el match.
    final resultado =
        await _historialLikesServicio.registrarLike(usuario.uuid);
    if (resultado?.limite == true) {
      _mostrarBloqueoMeGusta();
      return false;
    }
    // El feed en vivo no persiste perfiles ajenos: los cacheamos aquí para
    // que, si esto termina en match, la conversación ya tenga nombre/foto
    // desde el primer instante (sin esperar un refetch en chat_repositorio).
    unawaited(PerfilMapeo.cachearPerfilVisto(widget.db, usuario));
    _suscripcion.registrarMeGusta();
    if (mounted) {
      setState(() => _idsGustados.add(usuario.uuid));
      if (resultado?.match ?? _idsRecibidos.contains(usuario.uuid)) {
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
          suscripcionServicio: _suscripcion,
        ),
      ),
    );
  }

  Widget _grilla(
      List<_ItemInteraccion> items,
      bool puedeVer,
      CategoriaMeGusta categoria, {
      bool bloquearDetallesSinPlan = false,
    }) {
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
            final esNuevo = widget.contador.esNuevo(categoria, usuario.uuid);
            final esSuperRecibido = _idsSuperRecibidos.contains(usuario.uuid);

            return TarjetaUsuario(
              usuario: usuario,
              nuevo: esNuevo,
              esSuperRecibido: esSuperRecibido,
              onTap: () {
                // Me gustan: la foto se ve nítida, pero el detalle del
                // perfil solo se desbloquea con un plan.
                if (bloquearDetallesSinPlan && !_suscripcion.tienePlus) {
                  mostrarBloqueoSuscripcion(
                    context,
                    funcionalidad: _tituloCategoria(categoria),
                    planMinimo: PlanTipo.plus,
                    descripcion: _textoBloqueo(categoria),
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
            final esNuevo = widget.contador.esNuevo(categoria, usuario.uuid);
            final esSuperRecibido = _idsSuperRecibidos.contains(usuario.uuid);
            return TarjetaUsuario(
              usuario: usuario,
              nuevo: esNuevo,
              esSuperRecibido: esSuperRecibido,
              imagenBorrosa: true,
              imagenOverlay: Container(
                color: Colors.black.withValues(alpha: 0.15),
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
        return 'Ver los detalles de los perfiles que te gustan';
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
        return 'Suscríbete a Flumi Plus para ver los detalles de los perfiles que te gustan.';
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
  static const String _prefijoPersistencia = 'mgvn|';

  final AppDatabase? _db;
  int _likes = 0;
  int _visitas = 0;
  int _misLikes = 0;
  int _matches = 0;
  final Set<String> _vistos = <String>{};
  List<String> _ultLikes = const [];
  List<String> _ultVisitas = const [];
  List<String> _ultMisLikes = const [];
  List<String> _ultMatches = const [];

  ContadorMeGusta({AppDatabase? db}) : _db = db;

  int get likesNoLeidos => _likes;
  int get visitasNoLeidas => _visitas;
  int get misLikesNoLeidos => _misLikes;
  int get matchesNoLeidos => _matches;
  int get total => _likes + _visitas;

  /// Carga del disco las tarjetas ya vistas; al terminar recalcula los
  /// conteos con las últimas listas reconciliadas para corregir la carrera
  /// contra la primera carga de la página.
  Future<void> cargarVistos() async {
    final db = _db;
    if (db == null) return;
    try {
      final filas = await (db.select(db.notificacionesAbiertas)).get();
      for (final f in filas) {
        final clave = f.notificacionId;
        if (clave.startsWith(_prefijoPersistencia)) {
          _vistos.add(clave.substring(_prefijoPersistencia.length));
        }
      }
      _recalcularConteos();
    } catch (_) {}
  }

  void _persistirVistos(Iterable<String> claves) {
    final db = _db;
    final nuevas = claves.toList();
    if (db == null || nuevas.isEmpty) return;
    unawaited(() async {
      await db.batch((b) {
        for (final c in nuevas) {
          b.insert(
            db.notificacionesAbiertas,
            NotificacionesAbiertasCompanion.insert(
              notificacionId: '$_prefijoPersistencia$c',
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
      });
    }());
  }

  void _marcar(Set<String> claves) {
    for (final c in claves) {
      _vistos.add(c);
    }
    _persistirVistos(claves);
  }

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

  void incrementarLikes() {
    _likes++;
    notifyListeners();
  }

  void incrementarVisitas() {
    _visitas++;
    notifyListeners();
  }

  void incrementarMisLikes() {
    _misLikes++;
    notifyListeners();
  }

  void incrementarMatches(int cantidad) {
    _matches += cantidad;
    notifyListeners();
  }

  /// Un match nuevo saca a esa persona de Le gustas, Visitas y Me gustan
  /// (ahí solo se muestran no-matches): su conteo deja de pesar en el chip.
  void marcarMatch(String otroId) {
    for (final c in CategoriaMeGusta.values) {
      if (c == CategoriaMeGusta.matches) continue;
      if (_vistos.contains('${c.name}|$otroId')) continue;
      switch (c) {
        case CategoriaMeGusta.likes:
          if (_likes > 0) _likes--;
        case CategoriaMeGusta.visitas:
          if (_visitas > 0) _visitas--;
        case CategoriaMeGusta.misLikes:
          if (_misLikes > 0) _misLikes--;
        case CategoriaMeGusta.matches:
          break;
      }
    }
    notifyListeners();
  }

  void marcarVista(CategoriaMeGusta categoria, String usuarioId) {
    final clave = '${categoria.name}|$usuarioId';
    if (_vistos.contains(clave)) return;
    _marcar({clave});
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
    // Marca también como vistos los items visibles de la última carga:
    // sin esto, la siguiente reconciliación los volvería a contar.
    final claves = <String>{
      ..._ultLikes.map((id) => '${CategoriaMeGusta.likes.name}|$id'),
      ..._ultVisitas.map((id) => '${CategoriaMeGusta.visitas.name}|$id'),
      ..._ultMisLikes.map((id) => '${CategoriaMeGusta.misLikes.name}|$id'),
      ..._ultMatches.map((id) => '${CategoriaMeGusta.matches.name}|$id'),
    };
    _marcar(claves.where((c) => !_vistos.contains(c)).toSet());
    _likes = 0;
    _visitas = 0;
    _misLikes = 0;
    _matches = 0;
    notifyListeners();
  }

  /// Fuente de verdad final: ajusta los chips al número de tarjetas
  /// VISIBLES y no vistas de cada grilla (las listas ya vienen filtradas
  /// sin matches). Se llama después de cada carga, así cualquier carrera
  /// entre eventos (like + match) converge al conteo correcto.
  /// True si la tarjeta de [categoria]/[usuarioId] todavía no se ha visto
  /// (es decir, es un registro "nuevo"). Se usa para la etiqueta "Nuevo".
  bool esNuevo(CategoriaMeGusta categoria, String usuarioId) =>
      !_vistos.contains('${categoria.name}|$usuarioId');

  void reconciliar({
    required List<String> likes,
    required List<String> visitas,
    required List<String> misLikes,
    required List<String> matches,
  }) {
    _ultLikes = likes;
    _ultVisitas = visitas;
    _ultMisLikes = misLikes;
    _ultMatches = matches;
    _recalcularConteos();
  }

  void _recalcularConteos() {
    int nuevos(List<String> ids, CategoriaMeGusta categoria) =>
        ids.where((id) => !_vistos.contains('${categoria.name}|$id')).length;
    final nLikes = nuevos(_ultLikes, CategoriaMeGusta.likes);
    final nVisitas = nuevos(_ultVisitas, CategoriaMeGusta.visitas);
    final nMisLikes = nuevos(_ultMisLikes, CategoriaMeGusta.misLikes);
    final nMatches = nuevos(_ultMatches, CategoriaMeGusta.matches);
    if (nLikes == _likes &&
        nVisitas == _visitas &&
        nMisLikes == _misLikes &&
        nMatches == _matches) {
      return;
    }
    _likes = nLikes;
    _visitas = nVisitas;
    _misLikes = nMisLikes;
    _matches = nMatches;
    notifyListeners();
  }
}
