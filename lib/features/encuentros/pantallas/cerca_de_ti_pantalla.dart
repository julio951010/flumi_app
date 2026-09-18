import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/base_datos_local/database.dart';
import '../../../core/constantes/constantes.dart';
import '../../../core/servicios/connectivity_service.dart';
import '../../../core/servicios/notificacion_servicio.dart';
import '../../../core/servicios/suscripcion_servicio.dart';
import '../../../core/servicios/sync_service.dart';
import '../../../core/servicios/visitas_historial_servicio.dart';
import '../../../core/servicios/votos_servicio.dart';
import '../../../core/utilidades/perfil_mapeo.dart';
import '../../chat/chat_repositorio.dart';
import '../../chat/pantallas/chat_pantalla.dart';
import '../../../widgets_comunes/banner_gradiente.dart';
import '../../../widgets_comunes/estado_vacio_encuentros.dart';
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
  final SyncService syncService;
  final SuscripcionServicio suscripcionServicio;
  final VisitasServicio visitasServicio;
  final HistorialLikesServicio historialLikesServicio;
  final VotosServicio votosServicio;
  final VoidCallback? onAmpliarBusqueda;

  const CercaDeTiPantalla({
    super.key,
    required this.db,
    required this.miId,
    required this.filtros,
    required this.syncService,
    required this.suscripcionServicio,
    required this.visitasServicio,
    required this.historialLikesServicio,
    required this.votosServicio,
    this.onAmpliarBusqueda,
  });

  @override
  State<CercaDeTiPantalla> createState() => _CercaDeTiPantallaState();
}

class _CercaDeTiPantallaState extends State<CercaDeTiPantalla> {
  static const _loteTamanio = 10;
  static const _umbralScroll = 400.0;

  List<Usuario> _usuarios = [];
  List<Usuario> _filtrados = [];
  Usuario? _propio;
  Set<String> _idsGustados = {};
  Set<String> _idsRecibidos = {};
  Set<String> _idsSuperRecibidos = {};
  double _miLat = 0;
  double _miLon = 0;
  bool _cargando = true;
  int _offset = 0;
  bool _hayMasRemoto = true;
  bool _cargandoMas = false;
  bool _amplitudAplicada = false;
  final ScrollController _scrollCtrl = ScrollController();
  late final ChatRepositorio _chatRepo = ChatRepositorio(widget.db);
  late final SuscripcionServicio _suscripcion = widget.suscripcionServicio;
  late final VisitasServicio _visitas = widget.visitasServicio;
  late final HistorialLikesServicio _historialLikes =
      widget.historialLikesServicio;

  @override
  void initState() {
    super.initState();
    widget.votosServicio.addListener(_aplicarFiltros);
    _scrollCtrl.addListener(_alHacerScroll);
    _cargar();
  }

  @override
  void dispose() {
    widget.votosServicio.removeListener(_aplicarFiltros);
    _scrollCtrl
      ..removeListener(_alHacerScroll)
      ..dispose();
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
      _offset = 0;
      _hayMasRemoto = true;
      _cargandoMas = false;
      _amplitudAplicada = false;

      final propio = await (widget.db.select(widget.db.usuarios)
            ..where((u) => u.esPerfilPropio.equals(true))
            ..limit(1))
          .getSingleOrNull();

      // Fase 5: datos reales de interacción (adiós al mock).
      final gustados = await widget.historialLikesServicio.obtenerIdsGustados();
      final recibidos = await widget.historialLikesServicio.obtenerLikesRecibidos();
      final superRecibidos =
          await widget.historialLikesServicio.obtenerIdsSuperRecibidos();
      _idsGustados = gustados;
      _idsRecibidos = recibidos;
      _idsSuperRecibidos = superRecibidos;

      // Fase 1: primer lote del RPC + llenado mínimo para mostrar la grilla
      // pronto. Fase 2: si el RPC vuelve vacío con los filtros actuales, se
      // reintenta con ampliación en el servidor antes de rendirse; las
      // exclusiones (rechazos, gustados, bloqueos) se mantienen en ambos
      // modos.
      final acumulados = <Usuario>[];
      // Tope de intentos: con filtros duros no se pagina sin fin.
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
          _propio = propio;
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

  /// Siguiente lote desde el RPC `perfiles_cercanos` (paginación por offset
  /// en el servidor, ordenado por distancia). Con `conAmpliacion` el servidor
  /// relaja todo menos las exclusiones (sin distancia, edad ni filtros).
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
        orden: 'distancia',
      ),
      desde: _offset,
      cuantos: _loteTamanio,
    );
  }

  /// Carga predictiva: al acercarse al final del scroll se trae el siguiente
  /// lote en segundo plano (Fase 2).
  Future<void> _cargarMas() async {
    if (_cargandoMas || !_hayMasRemoto || _cargando) return;
    _cargandoMas = true;
    try {
      // Mismo tope que la carga inicial: no paginar sin fin si todo se filtra.
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
      if (mounted && _cargandoMas) _aplicarFiltros();
    } finally {
      _cargandoMas = false;
    }
  }

  void _alHacerScroll() {
    if (_cargandoMas || !_hayMasRemoto || _cargando) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - _umbralScroll) {
      unawaited(_cargarMas());
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
      lista.removeWhere((u) =>
          !f.generos.any((g) => normalizarGenero(u.genero) == normalizarGenero(g)));
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

    if (!conAmpliacion &&
        f.distanciaKm > 0 &&
        _miLat != 0 &&
        _miLon != 0) {
      lista.removeWhere((u) {
        if (u.ubicacionLat == 0 && u.ubicacionLon == 0) return false;
        return distanciaKmEntre(_miLat, _miLon, u.ubicacionLat, u.ubicacionLon) >
            f.distanciaKm;
      });
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

    // El orden por distancia ya lo aplica el servidor (orden='distancia').
    // Regla de reciclaje de Nopes: nuevos primero; si quedan menos de 5 se
    // agregan al final los rechazos reciclables (más antiguos primero). Los
    // reciclados ya pasaron el filtro de distancia de _filtrar.

    if (mounted) setState(() => _filtrados = widget.votosServicio.componerDeck(lista));
  }

  void _ampliarBusqueda() {
    widget.onAmpliarBusqueda?.call();
    setState(() => _cargando = true);
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return _esqueleto();
    if (_filtrados.isEmpty) {
      if (_hayMasRemoto) {
        unawaited(_cargarMas());
      }
      return EstadoVacioEncuentros(
        mensaje: 'No hay usuarios cerca con tus filtros',
        icono: Icons.people_outline,
        onAmpliarBusqueda: widget.onAmpliarBusqueda != null
            ? () async => _ampliarBusqueda()
            : null,
        onRecargar: () async {
          setState(() => _cargando = true);
          await _cargar();
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: CustomScrollView(
        controller: _scrollCtrl,
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
                  final esSuperRecibido =
                      _idsSuperRecibidos.contains(_filtrados[i].uuid);
                  if (_esBorrosa(i)) {
                    return TarjetaUsuario(
                      usuario: _filtrados[i],
                      esSuperRecibido: esSuperRecibido,
                      badge: _distanciaBadge(_filtrados[i]),
                      imagenBorrosa: true,
                      imagenOverlay: Container(
                        color: Colors.black.withValues(alpha: 0.15),
                        alignment: Alignment.center,
                        child: const Icon(Icons.lock_outline,
                            color: Colors.white, size: 26),
                      ),
                      onTap: _mostrarBloqueoCerca,
                      esquinaDerecha: esMatch
                          ? const Icon(Icons.whatshot,
                              color: Colors.orangeAccent, size: 18)
                          : gustado
                              ? const Icon(Icons.favorite,
                                  color: Colors.redAccent, size: 18)
                              : null,
                    );
                  }
                  return TarjetaUsuario(
                    usuario: _filtrados[i],
                    esSuperRecibido: esSuperRecibido,
                    badge: _distanciaBadge(_filtrados[i]),
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
                childCount: _filtrados.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  int get _limiteCerca => _suscripcion.limites.vistasCercaPorDia;

  /// Badge de distancia ("850 m" / "1.2 km"), mismo estilo que el tiempo
  /// en Le gustas. Null si no hay coordenadas para calcularla.
  Widget? _distanciaBadge(Usuario u) {
    if ((_miLat == 0 && _miLon == 0) ||
        (u.ubicacionLat == 0 && u.ubicacionLon == 0)) {
      return null;
    }
    final km = distanciaKmEntre(_miLat, _miLon, u.ubicacionLat, u.ubicacionLon);
    final texto =
        km < 1 ? '~ ${(km * 1000).round()} m' : '~ ${km.toStringAsFixed(1)} km';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.place, color: Colors.white, size: 10),
          const SizedBox(width: 2),
          Text(
            texto,
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ],
      ),
    );
  }

  /// True si el perfil en [indice] está por encima del límite del plan:
  /// se muestra con blur + candado.
  bool _esBorrosa(int indice) =>
      _limiteCerca >= 0 && indice >= _limiteCerca;

  void _mostrarBloqueoCerca() {
    final esGratis = !_suscripcion.tienePlus;
    final plan = esGratis ? PlanTipo.plus : PlanTipo.premium;
    final nombrePlan = esGratis ? 'Flumi Plus' : 'Flumi Premium';
    mostrarBloqueoSuscripcion(
      context,
      funcionalidad: 'Ver perfiles cerca de ti',
      planMinimo: plan,
      descripcion:
          'Tu plan incluye ${_limiteCerca} perfiles cerca de ti al día. Suscríbete a $nombrePlan para verlos todos.',
      onSuscribir: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetallePlanPantalla(
            nombre: nombrePlan,
            periodo: 'mensual',
            precio: esGratis ? '250 cup' : '500 cup',
            icono: esGratis ? Icons.auto_awesome : Icons.workspace_premium,
            detalle: esGratis ? 'Funciones extra' : 'Acceso total',
            destacado: esGratis,
          ),
        ),
      ),
    );
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
            // El "No me gusta" en Cerca de ti no registra rechazo: el perfil
            // se mantiene en el feed (los rechazos solo aplican al mazo).
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Future<bool> _meGusta(Usuario usuario) async {
    final puede = await _suscripcion.puedeUsarMeGusta(revalidar: true);
    if (!puede) {
      _mostrarBloqueoMeGusta();
      return false;
    }
    // Fase 3: el RPC valida el límite diario y confirma el match.
    final resultado = await _historialLikes.registrarLike(usuario.uuid);
    if (resultado?.limite == true) {
      _mostrarBloqueoMeGusta();
      return false;
    }
    if (resultado == null && ConnectivityService.instancia.hayConexion) {
      // RPC falló teniendo red: el Me Gusta no se guardó ni se encoló.
      if (mounted) {
        NotificacionServicio.advertencia(context,
            'Fallo de conexión: el Me Gusta no se guardó. Inténtalo de nuevo.');
      }
      return false;
    }
    // El feed en vivo no persiste perfiles ajenos: los cacheamos aquí para
    // que, si esto termina en match, la conversación ya tenga nombre/foto
    // desde el primer instante (sin esperar un refetch en chat_repositorio).
    unawaited(PerfilMapeo.cachearPerfilVisto(widget.db, usuario));
    _suscripcion.registrarMeGusta();
    widget.votosServicio.quitarRechazo(usuario.uuid, comoDeshacer: false);
    if (mounted) {
      setState(() => _idsGustados.add(usuario.uuid));
      // Quita el perfil gustado de la grilla de inmediato.
      _aplicarFiltros();
    }
    if (!mounted) return true;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    if (resultado?.match ?? _idsRecibidos.contains(usuario.uuid)) {
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
          suscripcionServicio: widget.suscripcionServicio,
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
            suscripcionServicio: widget.suscripcionServicio,
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
          'Llega a m\u00e1s personas cerca de ti (${_suscripcion.limites.vistasCercaPorDia} perfiles con Gratis)',
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
}
class PerfilDetallePage extends StatefulWidget {
  final Usuario usuario;
  final bool gusta;
  final bool esMatch;
  final bool esMeGusta;
  final bool soloVista;

  /// Título opcional en la cabecera (p. ej. 'Vista previa').
  final String? titulo;
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
    this.titulo,
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
              right: 16,
              child: Row(
                children: [
                  GestureDetector(
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
                  if (widget.titulo != null) ...[
                    Expanded(
                      child: Text(
                        widget.titulo!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
