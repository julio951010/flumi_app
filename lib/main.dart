import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/base_datos_local/database.dart';
import 'core/constantes/constantes.dart';
import 'core/estilos/tema.dart';
import 'core/servicios/connectivity_service.dart';
import 'core/servicios/sync_service.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/pantallas/login_pantalla.dart';
import 'features/auth/pantallas/olvide_contrasena_pantalla.dart';
import 'features/auth/pantallas/codigo_verificacion_pantalla.dart';
import 'features/auth/pantallas/registro_pantalla.dart';
import 'features/auth/pantallas/restablecer_contrasena_pantalla.dart';
import 'features/chat/chat_repositorio.dart';
import 'features/chat/pantallas/chat_pantalla.dart';
import 'features/matches/matches_repositorio.dart';
import 'features/matches/pantallas/matches_pantalla.dart';
import 'features/onboarding/onboarding_servicio.dart';
import 'features/onboarding/pantallas/onboarding_pantalla.dart';
import 'features/perfiles/perfil_repositorio.dart';
import 'features/perfiles/pantallas/perfil_pantalla.dart';
import 'widgets_comunes/animacion_agua.dart';
import 'widgets_comunes/barra_navegacion.dart';
import 'widgets_comunes/indicador_conexion.dart';
import 'widgets_comunes/logo_flotante.dart';
import 'widgets_comunes/encabezado_pagina.dart';

late final AppDatabase database;
late final SyncService syncService;
late final AuthService authService;
late final PerfilRepositorio perfilRepositorio;
late final MatchesRepositorio matchesRepositorio;
late final ChatRepositorio chatRepositorio;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  database = AppDatabase();

  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);

  authService = AuthService();

  syncService = SyncService(database);

  await ConnectivityService.instancia.iniciar();
  ConnectivityService.instancia.stream.listen((estado) {
    if (estado == EstadoConexion.conectado) {
      syncService.sincronizarTodo();
    }
  });

  perfilRepositorio = PerfilRepositorio(database);
  matchesRepositorio = MatchesRepositorio(database);
  chatRepositorio = ChatRepositorio(database);

  runApp(const FlumiApp());
}

class FlumiApp extends StatelessWidget {
  const FlumiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appNombre,
      debugShowCheckedModeBanner: false,
      theme: FlumiTema.tema,
      home: const _InicioRouter(),
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

  void _iniciar() {
    _autenticado = authService.estaAutenticado;
    authService.estadoStream.listen((estado) {
      if (!mounted) return;
      setState(() {
        _autenticado = estado.session != null;
        if (estado.event == AuthChangeEvent.passwordRecovery) {
          _recoveryMode = true;
        }
      });
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
    final mostrarAguaYLogo =
        !_listo || (_onboardingCompletado && (_autenticado == false || _recoveryMode));

    return Scaffold(
      body: Container(
        height: screenHeight,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFB3D9FF), Color(0xFFD6EAFF), Color(0xFFF2F8FF)],
          ),
        ),
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
              child: AnimacionAgua(color: const Color(0xff4A7AC9)),
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
              child: AnimacionAgua(color: const Color(0xff5A8AD8)),
            ),

            // Auth/app: se revela con _formAparecerAnim.
            // Cuando es formulario de auth, se posiciona debajo de la
            // cabecera y puede hacer scroll si excede el espacio.
            if (_listo && _onboardingCompletado)
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

  Widget _buildPaginaAuth() {
    if (_autenticado == null ||
        (_autenticado! && authService.usuarioActual == null)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_autenticado!) {
      return const _AuthWrapper();
    }
    if (_recoveryMode) {
      return RestablecerContrasenaPantalla(
        authService: authService,
        onCompletado: () {
          setState(() => _recoveryMode = false);
        },
      );
    }
    return IndicadorConexion(child: const _NavegacionPrincipal());
  }
}

enum _AuthPage { login, registro, olvideContrasena, codigoVerificacion }

class _AuthWrapper extends StatefulWidget {
  const _AuthWrapper({super.key});

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
          onExito: () {},
        );
      case _AuthPage.registro:
        return RegistroPantalla(
          authService: authService,
          onLogin: () => _alternar(_AuthPage.login),
          onExito: () {},
          onCodigoVerificacion: () =>
              _alternar(_AuthPage.codigoVerificacion),
        );
      case _AuthPage.olvideContrasena:
        return OlvideContrasenaPantalla(
          authService: authService,
          onLogin: () => _alternar(_AuthPage.login),
        );
      case _AuthPage.codigoVerificacion:
        return CodigoVerificacionPantalla(
          onLogin: () => _alternar(_AuthPage.login),
          onRegistro: () => _alternar(_AuthPage.registro),
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

  static const _nombresPaginas = [
    'Cerca',
    'Encuentros',
    'Me Gusta',
    'Chat',
    'Perfil',
  ];

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;
    final miId = authService.usuarioActual!.id;
    final nombre = _nombresPaginas[_indice];

    final pantallas = <Widget>[
      const Center(child: Text('Cerca — Fase 3')),
      const Center(child: Text('Encuentros — Fase 3')),
      MatchesPantalla(repositorio: matchesRepositorio),
      ChatPantalla(
        repositorio: chatRepositorio,
        otroUsuarioId: '',
        miId: miId,
      ),
      PerfilPantalla(repositorio: perfilRepositorio),
    ];

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Column(
            children: [
              EncabezadoPagina(titulo: nombre),
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
      bottomNavigationBar: BarraNavegacion(
        indiceActual: _indice,
        onCambio: (i) => setState(() => _indice = i),
      ),
    );
  }
}