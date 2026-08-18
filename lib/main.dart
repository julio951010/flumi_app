import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/env.dart';
import 'core/base_datos_local/database.dart';
import 'core/constantes/constantes.dart';
import 'core/estilos/tema.dart';
import 'core/servicios/connectivity_service.dart';
import 'core/servicios/estado_servidor_servicio.dart';
import 'core/servicios/notificacion_servicio.dart';
import 'core/servicios/sync_service.dart';
import 'widgets_comunes/shimmer_caja.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/pantallas/login_pantalla.dart';
import 'features/auth/pantallas/olvide_contrasena_pantalla.dart';
import 'features/auth/pantallas/registro_pantalla.dart';
import 'features/auth/pantallas/restablecer_contrasena_pantalla.dart';
import 'features/chat/chat_repositorio.dart';
import 'features/chat/pantallas/chats_pantalla.dart';
import 'features/onboarding/onboarding_servicio.dart';
import 'features/onboarding/pantallas/onboarding_pantalla.dart';
import 'features/onboarding/pantallas/onboarding_perfil_pantalla.dart';
import 'features/onboarding/pantallas/cuestionario_perfil_pantalla.dart';
import 'features/encuentros/pantallas/cerca_de_ti_pantalla.dart';
import 'features/encuentros/pantallas/encuentros_pantalla.dart';
import 'features/encuentros/pantallas/filtros_encuentros_sheet.dart';
import 'features/encuentros/pantallas/me_gusta_pantalla.dart';
import 'features/perfiles/perfil_repositorio.dart';
import 'features/perfiles/pantallas/perfil_pantalla.dart';
import 'features/perfiles/pantallas/editar_perfil_pantalla.dart';
import 'features/notificaciones/pantallas/bandeja_notificaciones_pantalla.dart';
import 'features/configuracion/pantallas/configuracion_pantalla.dart';
import 'widgets_comunes/animacion_agua.dart';
import 'widgets_comunes/barra_navegacion.dart';
import 'core/servicios/suscripcion_servicio.dart';
import 'core/servicios/visitas_historial_servicio.dart';
import 'core/servicios/votos_servicio.dart';
import 'core/utilidades/notificacion_navegador.dart';
import 'widgets_comunes/indicador_conexion.dart';
import 'widgets_comunes/logo_flotante.dart';
import 'widgets_comunes/encabezado_pagina.dart';

late final AppDatabase database;
late final SyncService syncService;
late final AuthService authService;
late final SuscripcionServicio suscripcionServicio;
late final VisitasServicio visitasServicio;
late final HistorialLikesServicio historialLikesServicio;
late final VotosServicio votosServicio;
late final PerfilRepositorio perfilRepositorio;
late final ChatRepositorio chatRepositorio;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  database = AppDatabase();

  if (!kUsarServidorLocal) {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
  }

  authService = AuthService();
  AuthService.initDb(database);
  await authService.inicializar();

  syncService = SyncService(database);

  await ConnectivityService.instancia.iniciar();
  EstadoServidorServicio.instancia.iniciarSondeo();
  // Push móvil (FCM): no bloquea el arranque y no lanza si Firebase aún no
  // está configurado.
  unawaited(inicializarPush());
  ConnectivityService.instancia.stream.listen((estado) {
    if (estado == EstadoConexion.conectado) {
      syncService.sincronizarTodo(alIniciarSesion: true);
    }
  });

  perfilRepositorio = PerfilRepositorio(database, syncService);
  chatRepositorio = ChatRepositorio(database, syncService);
  suscripcionServicio = SuscripcionServicio(database, syncService);
  visitasServicio = VisitasServicio(database, syncService);
  historialLikesServicio = HistorialLikesServicio(database, syncService);
  votosServicio = VotosServicio(database, syncService);
  await suscripcionServicio.cargarSuscripcion();

  runApp(const FlumiApp());
}

class FlumiApp extends StatelessWidget {
  const FlumiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      title: appNombre,
      debugShowCheckedModeBanner: false,
      theme: FlumiTema.tema,
      // En web el drag por defecto ignora el ratón: sin esto, el carrusel de
      // planes (PageView) y los scrollables no se pueden arrastrar con mouse.
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
        },
      ),
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: FlumiTema.estiloBarras,
        child: child!,
      ),
      home: const _InicioRouter(),
    );

    if (!kIsWeb) return app;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A3A55), Color(0xFF1B1B2F)],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 40,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: app,
            ),
          ),
        ),
      ),
    );
  }
}

class _InicioRouter extends StatefulWidget {
  const _InicioRouter();

  @override
  State<_InicioRouter> createState() => _InicioRouterState();
}

class _InicioRouterState extends State<_InicioRouter>
    with TickerProviderStateMixin {
  static const _alturaAguaSplash = 0.35;
  static const _alturaAguaHeader = 0.25;
  static const _logoSize = 130.0;

  bool _listo = false;
  bool _onboardingCompletado = false;
  bool? _autenticado;
  bool _recoveryMode = false;
  bool _perfilCompletado = true;
  bool _mostrarCuestionario = false;
  bool _syncArranqueHecho = false;

  /// True mientras el usuario ya tiene sesión (login OK o sesión restaurada)
  /// pero el sync inicial aún corre: oculta el formulario, baja el agua y el
  /// logo al centro (sin subtítulo) hasta revelar la app.
bool _esperandoSincronizacion = false;
  // Transición splash -> contenido, en dos fases SEPARADAS y
  // SECUENCIALES (no la misma controller repartida con Interval):
  // 1) _transCtrl mueve el logo hacia el header y baja el agua.
  // 2) Solo cuando (1) termina, arranca _formCtrl y recién ahí
  //    aparece el formulario. La flotación propia del logo vive
  //    dentro de LogoFlotante (independiente, como AnimacionAgua).
  late final AnimationController _transCtrl;
  late final Animation<double> _logoPosicionAnim;
  late final Animation<double> _aguaAlturaAnim;

  late final AnimationController _formCtrl;
  late final Animation<double> _formAparecerAnim;

  @override
  void initState() {
    super.initState();

    _transCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoPosicionAnim = CurvedAnimation(
      parent: _transCtrl,
      curve: Curves.easeInOutCubic,
    );
    _aguaAlturaAnim = Tween<double>(
      begin: _alturaAguaSplash,
      end: _alturaAguaHeader,
    ).animate(_logoPosicionAnim);

    _formCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _formAparecerAnim = CurvedAnimation(
      parent: _formCtrl,
      curve: Curves.easeOutCubic,
    );

    _iniciar();
  }

  @override
  void dispose() {
    _transCtrl.dispose();
    _formCtrl.dispose();
    super.dispose();
  }

  // Sesión creada (login OK) pero sync en curso: oculta formulario y
  // subtítulo, y baja el logo a su posición central sobre el agua mientras
  // la app sincroniza con Supabase.
  void _iniciarEsperaSincronizacion() {
    setState(() => _esperandoSincronizacion = true);
    _formCtrl.reverse();
    _transCtrl.reverse();
  }

  void _terminarEsperaSincronizacion() {
    _esperandoSincronizacion = false;
    _transCtrl.forward();
    _formCtrl.forward();
    setState(() {});
  }

  void _iniciar() {
    _autenticado = authService.estaAutenticado;
    authService.estadoStream.listen((estado) async {
      if (!mounted) return;
      if (estado.user != null &&
          (estado.event == 'SIGNED_IN' ||
           estado.event == 'INITIAL_SESSION' ||
           estado.event == 'USER_UPDATED' ||
           estado.event == 'TOKEN_REFRESHED')) {
        // Usamos el id del evento (no auth.currentUser, que puede ir un paso
        // atrás justo tras iniciar sesión) para detectar un cambio de cuenta.
        final idSesion = estado.user!['id'] as String?;
        if (estado.event == 'INITIAL_SESSION') {
          // La sesión restaurada puede llegar aquí o capturarse antes en el
          // arranque del splash; si ya sincronizamos, no repetimos la descarga.
          if (_syncArranqueHecho) {
            await _verificarPerfilCompletado(idSesion);
            setState(() {
              _autenticado = true;
              _esperandoSincronizacion = false;
            });
            _formCtrl.forward();
            return;
          }
          _syncArranqueHecho = true;
          // Sesión restaurada: en vez de una pantalla blanca, mostramos el
          // agua + logo mientras se sincroniza. La espera se termina aquí,
          // cuando el sync DE ESTA ruta acaba (nunca antes, para que el
          // logo centrado se vea durante todo el proceso).
          _iniciarEsperaSincronizacion();
          await syncService.sincronizarTodo(userId: idSesion, alIniciarSesion: true);
          await _verificarPerfilCompletado(idSesion);
          unawaited(registrarTokenPush());
          _terminarEsperaSincronizacion();
          return;
        }
        await syncService.sincronizarTodo(userId: idSesion, alIniciarSesion: true);
        await _verificarPerfilCompletado(idSesion);
        unawaited(registrarTokenPush());
      }
      if (estado.event == 'SIGNED_OUT') {
        unawaited(eliminarTokenPush());
      }
      setState(() {
        _autenticado = estado.user != null;
        if (estado.event == 'PASSWORD_RECOVERY') {
          _recoveryMode = true;
        }
      });
      if (_esperandoSincronizacion) {
        _terminarEsperaSincronizacion();
      }
    });

    // Esperar a que los procesos necesarios terminen,
    // con un mínimo visual para que el splash se vea.
    Future.wait([
      OnboardingServicio.estaCompletado(),
      Future.delayed(const Duration(milliseconds: 1500)),
    ]).then((resultados) async {
      if (!mounted) return;
      _onboardingCompletado = resultados[0] as bool;
      setState(() => _listo = true);

      await _transCtrl.forward();
      if (!mounted) return;

      if (_onboardingCompletado) {
        if (authService.estaAutenticado) {
          // La sesión se restauró: descargamos el perfil desde Supabase antes
          // de mostrar la app, para que el Home nunca se pinte con datos de
          // otra cuenta o de una caché vieja.
          if (!_syncArranqueHecho) {
            _syncArranqueHecho = true;
            // Visible = agua + logo en centro mientras se sincroniza.
            _iniciarEsperaSincronizacion();
            await syncService.sincronizarTodo(
              userId: authService.usuarioActual?['id'] as String?,
              alIniciarSesion: true,
            );
            await _verificarPerfilCompletado(
                authService.usuarioActual?['id'] as String?);
            // Solo esta ruta termina la espera si fue la que sincronizó:
            // si el listener ganó la carrera, el faro es ese otro bloque.
            _terminarEsperaSincronizacion();
          } else {
            // El listener ya está sincronizando (o terminó): no tocamos
            // la espera aquí.
            await _verificarPerfilCompletado(
                authService.usuarioActual?['id'] as String?);
          }
        }
        await _formCtrl.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final headerHeight = screenHeight * 0.08 + _logoSize + 28;

    // El agua y el logo se ocultan (pero NUNCA se desmontan) cuando ya
    // estamos en la app autenticada: así, si el usuario cierra sesión,
    // reaparecen sin haber perdido el ritmo de su animación interna.
    final mostrarAguaYLogo = !_listo ||
        _esperandoSincronizacion ||
        (_onboardingCompletado && (_autenticado == false || _recoveryMode));

    return Scaffold(
      body: Container(
        height: screenHeight,
        color: Colors.white,
        child: Stack(
          children: [
            // Onboarding: aparece en CUANTO termina el splash,
            // simultáneamente con la transición del logo y el agua
            // que ocurre por detrás.
            if (_listo && !_onboardingCompletado)
              OnboardingPantalla(
                onCompletado: () {
                  setState(() => _onboardingCompletado = true);
                  _formCtrl.forward();
                },
              ),

            // Agua: tres capas superpuestas con distinto color y altura
            // para dar profundidad al efecto de agua.
            AnimatedBuilder(
              animation: _aguaAlturaAnim,
              builder: (context, child) => Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: screenHeight * _aguaAlturaAnim.value,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: mostrarAguaYLogo ? 1 : 0,
                    duration: const Duration(milliseconds: 400),
                    child: child!,
                  ),
                ),
              ),
              child: const AnimacionAgua(),
            ),

            // Segunda capa de agua (más clara, un poco más baja)
            AnimatedBuilder(
              animation: _aguaAlturaAnim,
              builder: (context, child) => Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: screenHeight * _aguaAlturaAnim.value * 0.85,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: mostrarAguaYLogo ? 0.7 : 0,
                    duration: const Duration(milliseconds: 400),
                    child: child!,
                  ),
                ),
              ),
              child: AnimacionAgua(color: const Color(0xFF1FA0F0)),
            ),

            // Tercera capa de agua (la más clara, la más baja)
            AnimatedBuilder(
              animation: _aguaAlturaAnim,
              builder: (context, child) => Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: screenHeight * _aguaAlturaAnim.value * 0.7,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: mostrarAguaYLogo ? 0.5 : 0,
                    duration: const Duration(milliseconds: 400),
                    child: child!,
                  ),
                ),
              ),
              child: AnimacionAgua(color: const Color(0xFF30B0FF)),
            ),

            // Auth/app: se revela con _formAparecerAnim.
            // Cuando es formulario de auth, se posiciona debajo de la
            // cabecera y puede hacer scroll si excede el espacio.
            if (_listo && _onboardingCompletado && !_esperandoSincronizacion)
              AnimatedBuilder(
                animation: _formAparecerAnim,
                builder: (context, child) {
                  final t = _formAparecerAnim.value.clamp(0.0, 1.0);
                  Widget content = Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, 24 * (1 - t)),
                      child: child,
                    ),
                  );
                  if (_autenticado == false || _recoveryMode) {
                    content = Positioned(
                      top: headerHeight + 20,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SingleChildScrollView(child: content),
                    );
                  }
                  return content;
                },
                child: _buildPaginaAuth(),
              ),

            // Logo
            AnimatedBuilder(
              animation: _logoPosicionAnim,
              builder: (context, _) => LogoFlotante(
                progreso: _logoPosicionAnim.value,
                topCentro: (screenHeight - _logoSize) / 2 - screenHeight * 0.10,
                topHeader: screenHeight * 0.08,
                tamano: _logoSize,
                visible: mostrarAguaYLogo,
                subtitulo: appTagline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verificarPerfilCompletado([String? userId]) async {
    // App real (Supabase): garantizamos el perfil local y leemos si está
    // completado para decidir si mostrar el onboarding de perfil/cuestionario.
    try {
      await syncService.asegurarPerfilPropio(userId);
      final propio = await perfilRepositorio.obtenerPerfilPropio();
      if (mounted) {
        setState(() => _perfilCompletado = propio?.perfilCompletado ?? false);
      }
    } catch (_) {
      if (mounted) setState(() => _perfilCompletado = false);
    }
  }

  Widget _buildPaginaAuth() {
    if (_autenticado == null ||
        (_autenticado! && authService.usuarioActual == null)) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: ShimmerCaja(width: 120, height: 120, radius: 24)),
      );
    }
    if (!_autenticado!) {
      return _AuthWrapper(onLoginExitoso: _iniciarEsperaSincronizacion);
    }
    if (_recoveryMode) {
      return RestablecerContrasenaPantalla(
        authService: authService,
        onCompletado: () {
          setState(() => _recoveryMode = false);
        },
      );
    }
    // Mostrar cuestionario opcional después del onboarding
    if (_mostrarCuestionario) {
      final uuid = authService.usuarioActual?['id'] as String? ?? '';
      return CuestionarioPerfilPantalla(
        db: database,
        usuarioUuid: uuid,
        onCompletado: () => setState(() {
          _mostrarCuestionario = false;
          _perfilCompletado = true;
        }),
      );
    }
    // Mostrar onboarding de perfil si no está completo
    if (!_perfilCompletado) {
      final uuid = authService.usuarioActual?['id'] as String? ?? '';
      return OnboardingPerfilPantalla(
        db: database,
        usuarioUuid: uuid,
        onCompletado: () async {
          final uuid = authService.usuarioActual?['id'] as String? ?? '';
          await (database.update(database.usuarios)
                ..where((u) => u.uuid.equals(uuid)))
              .write(UsuariosCompanion(perfilCompletado: const Value(true)));
          setState(() => _mostrarCuestionario = true);
          _verificarPerfilCompletado(uuid);
        },
      );
    }
    return IndicadorConexion(child: const _NavegacionPrincipal());
  }
}

enum _AuthPage { login, registro, olvideContrasena }

class _AuthWrapper extends StatefulWidget {
  final VoidCallback? onLoginExitoso;

  const _AuthWrapper({super.key, this.onLoginExitoso});

  @override
  State<_AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<_AuthWrapper>
    with SingleTickerProviderStateMixin {
  _AuthPage _paginaActual = _AuthPage.login;
  _AuthPage _paginaAnterior = _AuthPage.login;
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _buildForm(_AuthPage pagina) {
    switch (pagina) {
      case _AuthPage.login:
        return LoginPantalla(
          authService: authService,
          onRegistro: () => _alternar(_AuthPage.registro),
          onOlvide: () => _alternar(_AuthPage.olvideContrasena),
          onExito: widget.onLoginExitoso ?? () {},
        );
      case _AuthPage.registro:
        return RegistroPantalla(
          authService: authService,
          onLogin: () => _alternar(_AuthPage.login),
          onExito: () => _alternar(_AuthPage.login),
        );
      case _AuthPage.olvideContrasena:
        return OlvideContrasenaPantalla(
          authService: authService,
          onLogin: () => _alternar(_AuthPage.login),
          onExito: () => _alternar(_AuthPage.login),
        );
    }
  }

  void _alternar(_AuthPage destino) {
    if (_ctrl.isAnimating) return;
    _paginaAnterior = _paginaActual;
    _paginaActual = destino;
    _ctrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final valor = _ctrl.value;
        if (!_ctrl.isAnimating) {
          return _buildForm(_paginaActual);
        }

        final angulo = valor * pi;
        final mostrarAntiguo = valor <= 0.5;
        final formulario = _buildForm(
          mostrarAntiguo ? _paginaAnterior : _paginaActual,
        );

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angulo),
          child: mostrarAntiguo
              ? formulario
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(pi),
                  child: formulario,
                ),
        );
      },
    );
  }
}

class _NavegacionPrincipal extends StatefulWidget {
  const _NavegacionPrincipal();

  @override
  State<_NavegacionPrincipal> createState() => _NavegacionPrincipalState();
}

class _NavegacionPrincipalState extends State<_NavegacionPrincipal> {
  int _indice = 1;
  int _indiceMeGusta = 0;
  FiltrosEncuentros _filtros = FiltrosEncuentros();
  final ValueNotifier<int> _undoSignal = ValueNotifier<int>(0);
  final ValueNotifier<int> _notificacionesNoLeidas = ValueNotifier<int>(0);
  /// Pendientes REALES (mensajes + sociales): alimenta el chip de la campana
  /// dentro de la página de Chats, que nunca se apaga al entrar.
  final ValueNotifier<int> _notificacionesPendientes = ValueNotifier<int>(0);
  final ValueNotifier<int> _socialesNoLeidas = ValueNotifier<int>(0);
  int _chatsNoLeidos = 0;
  final ValueNotifier<int> _meGustaNoLeidas = ValueNotifier<int>(0);
  final ContadorMeGusta _contadorMeGusta = ContadorMeGusta(db: database);
  StreamSubscription? _convSub;
  StreamSubscription? _likesRealtimeSub;
  StreamSubscription? _visitasRealtimeSub;
  StreamSubscription? _likesWatchSub;
  StreamSubscription? _visitasWatchSub;
  StreamSubscription? _matchesSub;
  final Set<String> _badgeLikes = <String>{};
  final Set<String> _badgeVisitas = <String>{};
  final Set<String> _badgeMatches = <String>{};
  final Set<String> _badgeMisLikes = <String>{};
  final Set<String> _idsMatch = <String>{};
  bool _likesSembrado = false;
  bool _visitasSembrado = false;
  bool _matchesSembrado = false;
  bool _misLikesSembrado = false;
  int _genRealtime = 0;
  int _reintentosRealtime = 0;
  static const int _realtimeMaxReintentos = 10;

  static const _nombresPaginas = [
    'Cerca de ti',
    'Encuentros',
    'Me Gusta',
    'Chats',
    'Perfil',
  ];

  @override
  void initState() {
    super.initState();
    final miId = authService.usuarioActual!['id'] as String;
    _convSub = chatRepositorio.observarConversaciones(miId).listen((resumenes) {
      _chatsNoLeidos =
          resumenes.fold<int>(0, (acc, r) => acc + r.noLeidos);
      _actualizarBadgeNotificaciones();
    });
    // Fase 5: los badges de Me Gusta se derivan de la BD local (dedupe por
    // uuid), así funcionan aunque el socket de Realtime de este navegador se
    // caiga o tarde: lo que llegue por sync también incrementa.
    _observarInteraccionesLocales(miId);
    _iniciarRealtimeInteracciones(miId);
    // Fase 4: chat en vivo app-wide (mensajes y matches); la conexión de
    // cada pantalla de chat es redundante e idempotente (upsert por uuid).
    chatRepositorio.suscribirseARealtime(miId);
    chatRepositorio.iniciarPresencia(miId);
    unawaited(votosServicio.inicializar());
    unawaited(_inicializarContadoresMeGusta(miId));
    unawaited(solicitarPermisoNotificaciones());
    // Se restaura el feedback cuando el servidor vuelve a responder.
    EstadoServidorServicio.instancia.addListener(_alCambiarEstadoServidor);
  }

  bool _servidorAvisoRestaurado = false;

  void _alCambiarEstadoServidor() {
    if (!mounted) return;
    if (EstadoServidorServicio.instancia.servidorDisponible) {
      if (_servidorAvisoRestaurado) {
        _servidorAvisoRestaurado = false;
        NotificacionServicio.exito(
            context, 'Conexión con el servidor restablecida');
      }
    } else {
      if (!_servidorAvisoRestaurado) {
        _servidorAvisoRestaurado = true;
        NotificacionServicio.advertencia(
          context,
          'Fallo de conexión con el servidor. '
          'Los cambios se guardarán cuando se recupere.',
        );
      }
    }
  }

  /// Badge de la pestaña Chats = mensajes no leídos + notificaciones nuevas
  /// (likes, visitas y matches) que aún no se revisaron en la bandeja.
  void _actualizarBadgeNotificaciones() {
    final total = _chatsNoLeidos + _socialesNoLeidas.value;
    _notificacionesPendientes.value = total;
    // Mientras se está viendo la pestaña Chats el indicador del nav queda
    // apagado; el chip de la campana (pendientes reales) se mantiene.
    _notificacionesNoLeidas.value = _indice == 3 ? 0 : total;
  }

  /// Registra una notificación social nueva: sube el badge de Chats, refresca
  /// la pestaña Me Gusta y avisa con una notificación del navegador si el
  /// usuario no está mirando la app.
  Future<void> _registrarNotificacionSocial(
      String tipo, String usuarioId) async {
    _socialesNoLeidas.value++;
    _actualizarBadgeNotificaciones();
    final u = await (database.select(database.usuarios)
          ..where((u) => u.uuid.equals(usuarioId))
          ..limit(1))
        .getSingleOrNull();
    final nombre = u?.nombre ?? 'Un usuario';
    final texto = switch (tipo) {
      'like' => '$nombre le dio Me Gusta a tu perfil',
      'visita' => '$nombre visit\u00f3 tu perfil',
      _ => '\u00a1Hiciste match con $nombre!',
    };
    await notificarNavegador('Flumi', texto);
  }

  /// Observa la BD local (alimentada por Realtime y por sync) e incrementa
  /// el badge solo con interacciones NUEVAS (dedupe por uuid). El primer
  /// evento de cada watch siembra el estado previo sin contar nada.
  void _observarInteraccionesLocales(String miId) {
    _likesWatchSub =
        database.select(database.historialLikes).watch().listen((filas) {
      final recibidos =
          filas.where((h) => h.usuarioLikeadoId == miId).toList();
      // Mis likes enviados: incrementan el badge de la sección "Mis Likes"
      // en vivo, cuando le doy Me Gusta a alguien.
      final enviados = filas.where((h) => h.usuarioId == miId).toList();
      if (!_likesSembrado) {
        _likesSembrado = true;
        _misLikesSembrado = true;
        _badgeLikes.addAll(recibidos.map((h) => h.uuid));
        _badgeMisLikes.addAll(enviados.map((h) => h.uuid));
        return;
      }
      for (final h in recibidos) {
        if (_badgeLikes.add(h.uuid)) {
          // Si ya es match su tarjeta vive en Matches: no cuenta aquí.
          if (_idsMatch.contains(h.usuarioId)) continue;
          _meGustaNoLeidas.value++;
          _contadorMeGusta.incrementarLikes();
          unawaited(_registrarNotificacionSocial('like', h.usuarioId));
        }
      }
      if (_misLikesSembrado) {
        for (final h in enviados) {
          if (_badgeMisLikes.add(h.uuid)) {
            _contadorMeGusta.incrementarMisLikes();
          }
        }
      } else {
        _misLikesSembrado = true;
        _badgeMisLikes.addAll(enviados.map((h) => h.uuid));
      }
    });
    _visitasWatchSub = database.select(database.visitas).watch().listen((filas) {
      final recibidas = filas.where((v) => v.visitadoId == miId).toList();
      if (!_visitasSembrado) {
        _visitasSembrado = true;
        _badgeVisitas.addAll(recibidas.map((v) => v.uuid));
        return;
      }
      for (final v in recibidas) {
        if (_badgeVisitas.add(v.uuid)) {
          // Visitas de un match no cuentan: su tarjeta está en Matches.
          if (_idsMatch.contains(v.visitanteId)) continue;
          _meGustaNoLeidas.value++;
          _contadorMeGusta.incrementarVisitas();
          unawaited(_registrarNotificacionSocial('visita', v.visitanteId));
        }
      }
    });
    _matchesSub = database.select(database.matches).watch().listen((filas) {
      final mios =
          filas.where((m) => m.usuarioAId == miId || m.usuarioBId == miId);
      if (!_matchesSembrado) {
        _matchesSembrado = true;
        _badgeMatches.addAll(mios.map((m) => m.uuid));
        _idsMatch.addAll(mios.map((m) =>
            m.usuarioAId == miId ? m.usuarioBId : m.usuarioAId));
        return;
      }
      for (final m in mios) {
        if (_badgeMatches.add(m.uuid)) {
          _meGustaNoLeidas.value++;
          _contadorMeGusta.incrementarMatches(1);
          final otroId = m.usuarioAId == miId ? m.usuarioBId : m.usuarioAId;
          _idsMatch.add(otroId);
          _contadorMeGusta.marcarMatch(otroId);
          unawaited(_registrarNotificacionSocial('match', otroId));
        }
      }
    });
  }

  /// Fase 3: recibe en vivo los Me Gusta recibidos y las visitas. Solo
  /// persiste en SQLite (el badge lo actualiza el watch de la BD). Si el
  /// socket se cae (pestaña vieja, navegador dormido), se reconecta solo.
  void _iniciarRealtimeInteracciones(String miId) {
    if (kUsarServidorLocal) return;
    final gen = ++_genRealtime;
    final client = Supabase.instance.client;
    final likesSub = client
        .from('historial_likes')
        .stream(primaryKey: ['id'])
        .eq('usuario_likeado_id', miId)
        .listen((eventos) async {
      for (final fila in eventos) {
        final id = fila['id'] as String?;
        if (id == null) continue;
        try {
          await database.into(database.historialLikes).insertOnConflictUpdate(
                HistorialLikesCompanion.insert(
                  uuid: id,
                  usuarioId: fila['usuario_id'] as String,
                  usuarioLikeadoId: miId,
                  timestamp: Value(DateTime.parse(fila['timestamp'] as String)),
                  pendienteDeSincronizar: const Value(false),
                ),
              );
        } catch (_) {}
      }
    }, onError: (Object _) => _reconectarRealtime(miId, gen));
    if (gen != _genRealtime) {
      likesSub.cancel();
      return;
    }
    _likesRealtimeSub?.cancel();
    _likesRealtimeSub = likesSub;

    final visitasSub = client
        .from('visitas')
        .stream(primaryKey: ['id'])
        .eq('visitado_id', miId)
        .listen((eventos) async {
      for (final fila in eventos) {
        final id = fila['id'] as String?;
        if (id == null) continue;
        try {
          await database.into(database.visitas).insertOnConflictUpdate(
                VisitasCompanion.insert(
                  uuid: id,
                  visitanteId: fila['visitante_id'] as String,
                  visitadoId: miId,
                  timestamp: Value(DateTime.parse(fila['timestamp'] as String)),
                  pendienteDeSincronizar: const Value(false),
                ),
              );
        } catch (_) {}
      }
    }, onError: (Object _) => _reconectarRealtime(miId, gen));
    if (gen != _genRealtime) {
      visitasSub.cancel();
      return;
    }
    _visitasRealtimeSub?.cancel();
    _visitasRealtimeSub = visitasSub;
  }

  void _reconectarRealtime(String miId, int gen) {
    if (gen != _genRealtime) return;
    if (_reintentosRealtime >= _realtimeMaxReintentos) return;
    _reintentosRealtime++;
    Timer(const Duration(seconds: 3), () {
      if (mounted && gen == _genRealtime) {
        _iniciarRealtimeInteracciones(miId);
      }
    });
  }

  /// Amplía la búsqueda cuando no hay resultados: quita distancia, amplía el
  /// rango de edad al máximo y pide un radio mayor al servidor.
  void _ampliarBusqueda() {
    setState(() {
      _filtros = FiltrosEncuentros(
        edadRango: const RangeValues(18, 99),
        distanciaKm: 0,
      );
    });
    (database.select(database.usuarios)
          ..where((u) => u.esPerfilPropio.equals(true))
          ..limit(1))
        .getSingleOrNull()
        .then((p) {
          if (p != null && (p.ubicacionLat != 0 || p.ubicacionLon != 0)) {
            return syncService.sincronizarFeedCercano(
              lat: p.ubicacionLat,
              lon: p.ubicacionLon,
              radioMetros: 50000,
              filtros: SyncService.filtrosARpcJson(ampliar: true),
            );
          }
        })
        .catchError((_) {});
  }

  Future<void> _inicializarContadoresMeGusta(String miId) async {
    // Restaura las tarjetas ya vistas para que al recargar no vuelvan a
    // contar como nuevas en los chips de la página Me Gusta.
    unawaited(_contadorMeGusta.cargarVistos());
    // Refresca el espejo local para que el watch de la BD tenga la foto real
    // y el badge cuente los likes/visitas pendientes desde la última vista.
    try {
      await syncService.sincronizarHistorialLikes(miId);
      await syncService.sincronizarVisitas(miId);
    } catch (_) {}
    final gustados = await historialLikesServicio.obtenerHistorial(limite: 1000);
    // Quita del conteo de Me gustan los que ya son match (viven en su pestaña).
    final matchesLocales = await database.select(database.matches).get();
    final otrosMatch = <String>{
      for (final m in matchesLocales)
        if (m.usuarioAId == miId || m.usuarioBId == miId)
          m.usuarioAId == miId ? m.usuarioBId : m.usuarioAId,
    };
    final gustadosSinMatch =
        gustados.where((h) => !otrosMatch.contains(h.usuarioLikeadoId)).length;
    // Si llega en vivo un like/visita/match mientras este inicializador hace
    // sus awaits (p. ej. match justo al arrancar), no debe pisar lo contado:
    // aplica la foto inicial solo para categorías que el watch aún no maneja.
    _contadorMeGusta.inicializar(
      likes: (_likesSembrado || _badgeLikes.isNotEmpty)
          ? _contadorMeGusta.likesNoLeidos
          : 0,
      visitas: (_visitasSembrado || _badgeVisitas.isNotEmpty)
          ? _contadorMeGusta.visitasNoLeidas
          : 0,
      misLikes: gustadosSinMatch,
      matches: (_matchesSembrado || _badgeMatches.isNotEmpty)
          ? _contadorMeGusta.matchesNoLeidos
          : 0,
    );
  }

  @override
  void dispose() {
    chatRepositorio.cancelarRealtime();
    _convSub?.cancel();
    _convSub = null;
    _likesRealtimeSub?.cancel();
    _likesRealtimeSub = null;
    _visitasRealtimeSub?.cancel();
    _visitasRealtimeSub = null;
    _likesWatchSub?.cancel();
    _likesWatchSub = null;
    _visitasWatchSub?.cancel();
    _visitasWatchSub = null;
    _matchesSub?.cancel();
    _matchesSub = null;
    _undoSignal.dispose();
    _contadorMeGusta.dispose();
    _meGustaNoLeidas.dispose();
    _socialesNoLeidas.dispose();
    _notificacionesNoLeidas.dispose();
    _notificacionesPendientes.dispose();
    EstadoServidorServicio.instancia.removeListener(_alCambiarEstadoServidor);
    super.dispose();
  }

  void _abrirBandejaNotificaciones() {
    // Chrome ignora requestPermission() sin gesto de usuario: el tap sobre la
    // campana es el momento natural para pedirlo.
    unawaited(solicitarPermisoNotificaciones());
    final miId = authService.usuarioActual!['id'] as String;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BandejaNotificacionesPantalla(
          db: database,
          miId: miId,
          visitasServicio: visitasServicio,
          historialLikesServicio: historialLikesServicio,
          suscripcionServicio: suscripcionServicio,
          onAbierto: _marcarBandejaVista,
          onNavegarA: (tab, subindice) {
            setState(() {
              _indice = tab;
              _indiceMeGusta = subindice;
            });
            if (tab == 2) _meGustaNoLeidas.value = 0;
            _actualizarBadgeNotificaciones();
          },
        ),
      ),
    );
  }

  void _marcarBandejaVista() {
    // Solo la bandeja de notificaciones: sus notificaciones sociales se
    // revisan aquí. El corazón de Me Gusta no se toca (se limpia al
    // revisar la página o con "Marcar todos como vistos").
    _socialesNoLeidas.value = 0;
    _actualizarBadgeNotificaciones();
  }

  void _marcarNotificacionesVistas() {
    // Solo limpia lo de la página Me gusta (chips del contador e indicador
    // del corazón en el bottom nav). Los chats y la bandeja de
    // notificaciones se limpian al abrirlos.
    _contadorMeGusta.marcarTodasVistas();
    _meGustaNoLeidas.value = 0;
  }

  void _manejarOpcionNotificaciones(String opcion) {
    if (opcion == 'marcar_vistos') {
      // Desde la página Me Gusta: limpia solo su página.
      _marcarNotificacionesVistas();
    } else if (opcion == 'marcar_leidos') {
      // Desde la pestaña Chats: marca solo las conversaciones como leídas.
      final miId = authService.usuarioActual!['id'] as String;
      unawaited(chatRepositorio.marcarTodasConversacionesLeidas(miId));
    }
  }

  Future<void> _abrirFiltros() async {
    final resultado = await mostrarFiltrosEncuentros(
      context,
      actuales: _filtros,
      estaEnCercaDeTi: _indice == 0,
      suscripcionServicio: suscripcionServicio,
    );
    if (resultado != null) {
      setState(() => _filtros = resultado);
    }
  }

  Future<void> _editarPerfil() async {
    final perfil = await perfilRepositorio.obtenerPerfilPropio();
    if (perfil == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa tu perfil para editarlo'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditarPerfilPantalla(perfil: perfil, repositorio: perfilRepositorio),
      ),
    );
  }

  void _abrirConfiguracion(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConfiguracionPantalla(
          authService: authService,
          repositorio: perfilRepositorio,
          db: database,
          suscripcionServicio: suscripcionServicio,
          syncService: syncService,
          onCerrarSesion: _cerrarSesion,
        ),
      ),
    );
  }

  Future<void> _cerrarSesion() async {
    try {
      await authService.cerrarSesion();
    } catch (_) {
      // Si falla la red, igual cerramos la sesión en la app.
    }
    // No borramos la tabla local `usuarios` aquí: el perfil propio se conserva
    // en el dispositivo para que, al volver a iniciar sesión con la misma
    // cuenta, los datos carguen de inmediato. SyncService se encarga de
    // descartar el perfil local si quien entra es una cuenta distinta.
    // El cambio a login lo hace el listener de auth en _InicioRouterState.
    // La navegación (cerrar Configuración) la maneja ConfiguracionPantalla.
  }

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;
    final miId = authService.usuarioActual!['id'] as String;
    final nombre = _nombresPaginas[_indice];

    final pantallas = <Widget>[
      CercaDeTiPantalla(
        db: database,
        miId: miId,
        filtros: _filtros,
        syncService: syncService,
        suscripcionServicio: suscripcionServicio,
        visitasServicio: visitasServicio,
        historialLikesServicio: historialLikesServicio,
        votosServicio: votosServicio,
        onAmpliarBusqueda: _ampliarBusqueda,
      ),
      EncuentrosPantalla(
        db: database,
        miId: miId,
        filtros: _filtros,
        undoSignal: _undoSignal,
        syncService: syncService,
        suscripcionServicio: suscripcionServicio,
        visitasServicio: visitasServicio,
        historialLikesServicio: historialLikesServicio,
        votosServicio: votosServicio,
        onAmpliarBusqueda: _ampliarBusqueda,
      ),
      MeGustaPantalla(
        db: database,
        miId: miId,
        contador: _contadorMeGusta,
        suscripcionServicio: suscripcionServicio,
        visitasServicio: visitasServicio,
        historialLikesServicio: historialLikesServicio,
        indiceInicial: _indiceMeGusta,
      ),
      ChatsPantalla(
        db: database,
        repositorio: chatRepositorio,
        miId: miId,
        suscripcionServicio: suscripcionServicio,
      ),
      PerfilPantalla(
        repositorio: perfilRepositorio,
        onConfiguracion: () => _abrirConfiguracion(context),
        suscripcionServicio: suscripcionServicio,
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Column(
            children: [
              EncabezadoPagina(
                titulo: nombre,
                accion: _indice <= 1
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_indice == 1)
                            IconButton(
                              icon: Icon(Icons.undo, color: primario, size: 24),
                              onPressed: () => _undoSignal.value++,
                              tooltip: 'Deshacer',
                            ),
                          IconButton(
                            icon: Icon(Icons.tune, color: primario, size: 24),
                            onPressed: _abrirFiltros,
                            tooltip: 'Filtros',
                          ),
                        ],
                      )
                    : _indice == 2
                        ? ValueListenableBuilder<int>(
                            valueListenable: _meGustaNoLeidas,
                            builder: (context, total, _) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert,
                                      color: primario, size: 24),
                                  tooltip: 'Opciones',
                                  onSelected: _manejarOpcionNotificaciones,
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 'marcar_vistos',
                                      child: Text('Marcar todos como vistos'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        : _indice == 3
                        ? ValueListenableBuilder<int>(
                            valueListenable: _notificacionesPendientes,
                            builder: (context, total, _) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Badge(
                                    isLabelVisible: total > 0,
                                    label: Text(
                                      '$total',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    child: Icon(Icons.notifications_none,
                                        color: primario, size: 24),
                                  ),
                                  onPressed: _abrirBandejaNotificaciones,
                                  tooltip: 'Notificaciones',
                                ),
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert,
                                      color: primario, size: 24),
                                  tooltip: 'Opciones',
                                  onSelected: _manejarOpcionNotificaciones,
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 'marcar_leidos',
                                      child: Text('Marcar todos como leídos'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        : _indice == 4
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.settings_outlined,
                                        color: primario, size: 24),
                                    onPressed: () => _abrirConfiguracion(context),
                                    tooltip: 'Configuración',
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.edit_outlined,
                                        color: primario, size: 24),
                                    onPressed: _editarPerfil,
                                    tooltip: 'Editar perfil',
                                  ),
                                ],
                              )
                        : null,
              ),
              // Feedback de fallos de conexión/timeout con el servidor:
              // aviso transitorio (notificación flotante) cuando Supabase no
              // responde; al recuperarse se avisa con la notificación de éxito.
              Expanded(child: pantallas[_indice]),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 70,
            child: Container(color: primario),
          ),
        ],
      ),
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: _meGustaNoLeidas,
        builder: (context, meGustaCount, _) {
          return ValueListenableBuilder<int>(
            valueListenable: _notificacionesNoLeidas,
            builder: (context, chatsCount, _) {
              return BarraNavegacion(
                indiceActual: _indice,
                onCambio: (i) {
                  setState(() => _indice = i);
                  // Al abrir cada página se limpia su indicador del nav:
                  // Me Gusta → corazón; Chats → mensajes no leídos.
                  if (i == 2) {
                    // Desde el nav se vuelve a la sub-pestaña inicial; la
                    // sub-pestaña exacta solo la eligen las notificaciones.
                    _indiceMeGusta = 0;
                    _meGustaNoLeidas.value = 0;
                  }
                  if (i == 3) {
                    // Solo se apaga el indicador del nav: los chats NO se
                    // marcan leídos (eso ocurre al abrir la conversación).
                    _notificacionesNoLeidas.value = 0;
                  } else {
                    _actualizarBadgeNotificaciones();
                  }
                },
                meGustaNoLeidas: meGustaCount,
                chatsNoLeidos: chatsCount,
              );
            },
          );
        },
      ),
    );
  }
}