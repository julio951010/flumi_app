import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/base_datos_local/database.dart';
import 'core/constantes/constantes.dart';
import 'core/estilos/tema.dart';
import 'core/servicios/connectivity_service.dart';
import 'core/servicios/sync_service.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/pantallas/login_pantalla.dart';
import 'features/auth/pantallas/registro_pantalla.dart';
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
  bool _listo = false;
  bool _onboardingCompletado = false;
  bool? _autenticado;
  late AnimationController _logoFlotar;
  late Animation<double> _logoFlotarAnim;
  late AnimationController _transCtrl;
  late Animation<double> _logoSubirAnim;
  late Animation<double> _formAparecerAnim;

  @override
  void initState() {
    super.initState();
    _logoFlotar = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _logoFlotarAnim = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _logoFlotar, curve: Curves.easeInOutSine),
    );
    _logoFlotar
      ..forward()
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _logoFlotar.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _logoFlotar.forward();
        }
      });
    _logoFlotar.addListener(() => setState(() {}));

    _transCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoSubirAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _transCtrl, curve: Curves.easeInOut),
    );
    _formAparecerAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _transCtrl,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOutBack),
      ),
    );
    _transCtrl.addListener(() => setState(() {}));
    _iniciar();
  }

  @override
  void dispose() {
    _logoFlotar.dispose();
    _transCtrl.dispose();
    super.dispose();
  }

  void _iniciar() {
    _autenticado = authService.estaAutenticado;
    authService.estadoStream.listen((estado) {
      if (mounted) setState(() => _autenticado = estado.session != null);
    });

    OnboardingServicio.estaCompletado().then((v) {
      if (mounted) setState(() => _onboardingCompletado = v);
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _listo = true);
        _transCtrl.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final mostrarAnimacion =
        !_listo || (_listo && _onboardingCompletado && _autenticado == false);

    final float = _logoFlotarAnim.value;
    final progress = _logoSubirAnim.value;

    // Splash separado (garantiza que se vea)
    if (!_listo) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFB3D9FF), Color(0xFFD6EAFF), Color(0xFFF2F8FF)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                bottom: 0, left: 0, right: 0,
                height: screenHeight * 0.35,
                child: const AnimacionAgua(),
              ),
              Center(
                child: Transform.translate(
                  offset: Offset(0, float),
                  child: Image.asset(
                    'assets/images/flumi_logo_down.png',
                    width: 100, height: 100,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFB3D9FF), Color(0xFFD6EAFF), Color(0xFFF2F8FF)],
          ),
        ),
        child: Stack(
          children: [
            if (mostrarAnimacion)
              Positioned(
                bottom: 0, left: 0, right: 0,
                height: screenHeight * 0.35,
                child: const AnimacionAgua(),
              ),
            // Logo en parte superior
            if (_onboardingCompletado)
              Positioned(
                top: screenHeight * 0.08 + float * (1 - progress),
                left: 0, right: 0,
                child: Center(
                  child: Image.asset(
                    'assets/images/flumi_logo_down.png',
                    width: 100, height: 100,
                  ),
                ),
              ),
            // Onboarding
            if (!_onboardingCompletado)
              OnboardingPantalla(
                onCompletado: () =>
                    setState(() => _onboardingCompletado = true),
              ),
            // Auth pages: aparecen desde abajo
            if (_onboardingCompletado && !_transCtrl.isCompleted)
              AnimatedBuilder(
                animation: _transCtrl,
                builder: (context, _) {
                  final formP = _formAparecerAnim.value;
                  return Transform.translate(
                    offset: Offset(0, screenHeight * (1 - formP)),
                    child: Opacity(opacity: formP.clamp(0.0, 1.0), child: _buildPaginaAuth()),
                  );
                },
              ),
            if (_onboardingCompletado && _transCtrl.isCompleted)
              _buildPaginaAuth(),
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
    return IndicadorConexion(child: const _NavegacionPrincipal());
  }
}

class _AuthWrapper extends StatefulWidget {
  const _AuthWrapper({super.key});

  @override
  State<_AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<_AuthWrapper> {
  bool _mostrarRegistro = false;

  @override
  Widget build(BuildContext context) {
    if (_mostrarRegistro) {
      return RegistroPantalla(
        authService: authService,
        onLogin: () => setState(() => _mostrarRegistro = false),
        onExito: () {},
      );
    }

    return LoginPantalla(
      authService: authService,
      onRegistro: () => setState(() => _mostrarRegistro = true),
      onExito: () {},
    );
  }
}

class _NavegacionPrincipal extends StatefulWidget {
  const _NavegacionPrincipal();

  @override
  State<_NavegacionPrincipal> createState() => _NavegacionPrincipalState();
}

class _NavegacionPrincipalState extends State<_NavegacionPrincipal> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    final miId = authService.usuarioActual!.id;

    final pantallas = <Widget>[
      const Center(child: Text('Descubrir — Fase 3')),
      MatchesPantalla(repositorio: matchesRepositorio),
      ChatPantalla(
        repositorio: chatRepositorio,
        otroUsuarioId: '',
        miId: miId,
      ),
      PerfilPantalla(repositorio: perfilRepositorio),
    ];

    return Scaffold(
      body: pantallas[_indice],
      bottomNavigationBar: BarraNavegacion(
        indiceActual: _indice,
        onCambio: (i) => setState(() => _indice = i),
      ),
    );
  }
}
