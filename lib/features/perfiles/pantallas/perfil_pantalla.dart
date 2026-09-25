import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/utilidades/fotos_perfil.dart';
import 'package:http/http.dart' as http;
import 'package:drift/drift.dart' hide Column;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../../config/env.dart';
import '../../../core/base_datos_local/database.dart';
import '../../../core/servicios/suscripcion_servicio.dart';
import '../../../widgets_comunes/foto_perfil.dart';
import '../../../widgets_comunes/placeholder_foto.dart';
import '../../../widgets_comunes/shimmer_caja.dart';
import '../../../widgets_comunes/visor_fotos_pantalla.dart';
import '../../auth/auth_service.dart';
import '../../configuracion/pantallas/administrar_suscripcion_pantalla.dart';
import '../perfil_completado.dart';
import '../perfil_repositorio.dart';
import 'detalle_plan_pantalla.dart';
import 'editar_perfil_pantalla.dart';
import 'verificacion_cuenta_pantalla.dart';

class PerfilPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;
  final VoidCallback? onConfiguracion;
  final SuscripcionServicio suscripcionServicio;

  const PerfilPantalla({
    super.key,
    required this.repositorio,
    this.onConfiguracion,
    required this.suscripcionServicio,
  });

  @override
  State<PerfilPantalla> createState() => _PerfilPantallaState();
}

class _PerfilPantallaState extends State<PerfilPantalla> {
  Usuario? _perfil;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    widget.repositorio.perfilPropio.addListener(_alCambiarPerfil);
    _cargarPerfil();
  }

  void _alCambiarPerfil() {
    final actual = widget.repositorio.perfilPropio.value;
    if (!mounted) return;
    setState(() {
      _perfil = actual;
      if (actual != null) _cargando = false;
    });
  }

  @override
  void dispose() {
    widget.repositorio.perfilPropio.removeListener(_alCambiarPerfil);
    super.dispose();
  }

  Future<void> _cargarPerfil() async {
    setState(() => _cargando = true);
    var perfil = await widget.repositorio.obtenerPerfilPropio();
    if (perfil == null) {
      await _descargarDeSupabase();
      perfil = await widget.repositorio.obtenerPerfilPropio();
    }
    if (perfil != null && perfil.nombre.trim().isEmpty) {
      final nombreSesion =
          AuthService().usuarioActual?['nombre'] as String? ?? '';
      final nombreFinal = nombreSesion.isNotEmpty ? nombreSesion : 'T\u00fa';
      await widget.repositorio.guardarOCambiarPerfil(
          perfil.toCompanion(true).copyWith(nombre: Value(nombreFinal)));
      perfil = await widget.repositorio.obtenerPerfilPropio();
    }
    if (!mounted) return;
    setState(() {
      _perfil = perfil;
      _cargando = false;
    });
  }

  Future<void> _descargarDeSupabase() async {
    final authService = AuthService();
    final userId = authService.usuarioActual?['id'];
    if (userId == null) return;
    try {
      Map<String, dynamic>? remoto;

      if (kUsarServidorLocal) {
        final token = await LocalTokenStore.obtenerToken();
        if (token == null) return;
        final res = await http.get(
          Uri.parse('$kServidorLocalUrl/api/profiles/$userId'),
          headers: {'authorization': 'Bearer $token'},
        );
        if (res.statusCode == 200) {
          remoto = jsonDecode(res.body) as Map<String, dynamic>;
        }
      }

      if (remoto == null && !kUsarServidorLocal) {
        final data = await sb.Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();
        if (data != null) remoto = data;
      }

      if (remoto == null) return;
      final fechaNac = remoto['fecha_nacimiento'] as String?;
      final db = widget.repositorio;
      final creadoEn = remoto['creado_en'] != null
          ? DateTime.parse(remoto['creado_en'] as String)
          : DateTime.now();
      final edad = fechaNac != null ? _calcularEdad(fechaNac) : 18;
      await db.guardarOCambiarPerfil(
        UsuariosCompanion.insert(
          uuid: remoto['id'],
          nombre: remoto['nombre'] ?? '',
          edad: edad,
          genero: remoto['genero'] ?? 'otro',
          buscaGenero: remoto['busca_genero'] ?? 'otro',
          biografia: Value(remoto['biografia'] ?? ''),
          fotosUrls: Value(
            (remoto['fotos_urls'] as List?)?.whereType<String>().toList() ??
                const [],
          ),
          verificadoStatus: Value(remoto['verificado_status'] ?? false),
          scorePopularidad: Value(remoto['score_popularidad'] ?? 0),
          esPerfilPropio: const Value(true),
          pendienteDeSincronizar: const Value(false),
          creadoEn: Value(creadoEn),
        ),
      );
    } catch (_) {}
  }

  int _calcularEdad(String fechaNacimientoIso) {
    final nacimiento = DateTime.parse(fechaNacimientoIso);
    final hoy = DateTime.now();
    var edad = hoy.year - nacimiento.year;
    if (hoy.month < nacimiento.month ||
        (hoy.month == nacimiento.month && hoy.day < nacimiento.day)) {
      edad--;
    }
    return edad;
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    if (_cargando) return _esqueleto();
    if (_perfil == null) {
      return _SinPerfil(authService: auth, onReintentar: _cargarPerfil);
    }
    return _PerfilFlumi(
      perfil: _perfil!,
      authService: auth,
      repositorio: widget.repositorio,
      suscripcionServicio: widget.suscripcionServicio,
      onActualizar: _cargarPerfil,
    );
  }

  Widget _esqueleto() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
      children: [
        Row(
          children: const [
            ShimmerCaja(width: 104, height: 104, radius: 52),
            SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerCaja(height: 26),
                  SizedBox(height: 8),
                  ShimmerCaja(height: 14),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _tarjetaInfoEsqueleto(),
        const SizedBox(height: 12),
        _tarjetaInfoEsqueleto(),
        const SizedBox(height: 28),
        const ShimmerCaja(width: 170, height: 18),
        const SizedBox(height: 12),
        _tarjetaInfoEsqueleto(),
        const SizedBox(height: 12),
        _carruselEsqueleto(),
      ],
    );
  }

  Widget _tarjetaInfoEsqueleto() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: const Row(
        children: [
          ShimmerCaja(width: 26, height: 26, radius: 13),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerCaja(height: 14),
                SizedBox(height: 6),
                ShimmerCaja(height: 11),
              ],
            ),
          ),
          SizedBox(width: 8),
          ShimmerCaja(width: 20, height: 20, radius: 4),
        ],
      ),
    );
  }

  Widget _carruselEsqueleto() {
    return Column(
      children: [
        SizedBox(
          height: 190,
          child: Row(
            children: [
              Expanded(child: _TarjetaPlanEsqueleto()),
              const SizedBox(width: 12),
              Expanded(child: _TarjetaPlanEsqueleto()),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShimmerCaja(width: 18, height: 6, radius: 3),
            SizedBox(width: 6),
            ShimmerCaja(width: 6, height: 6, radius: 3),
            SizedBox(width: 6),
            ShimmerCaja(width: 6, height: 6, radius: 3),
          ],
        ),
      ],
    );
  }

  Widget _TarjetaPlanEsqueleto() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShimmerCaja(width: 32, height: 32, radius: 16),
          SizedBox(height: 10),
          ShimmerCaja(width: 100, height: 16),
          SizedBox(height: 6),
          ShimmerCaja(width: 60, height: 12),
          SizedBox(height: 10),
          ShimmerCaja(width: 90, height: 20),
          SizedBox(height: 10),
          ShimmerCaja(width: 70, height: 18, radius: 9),
        ],
      ),
    );
  }
}

class _SinPerfil extends StatelessWidget {
  final AuthService authService;
  final VoidCallback? onReintentar;
  const _SinPerfil({required this.authService, this.onReintentar});

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;
    final userEmail = authService.usuarioActual?['email'] as String? ?? '';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_circle, size: 100, color: primario),
          const SizedBox(height: 16),
          Text(userEmail, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          const Text('Perfil no disponible'),
          const SizedBox(height: 16),
          if (onReintentar != null)
            TextButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reintentar'),
            ),
          const SizedBox(height: 24),
          _BotonCerrarSesion(authService: authService),
        ],
      ),
    );
  }
}

class _PerfilFlumi extends StatefulWidget {
  final Usuario perfil;
  final AuthService authService;
  final PerfilRepositorio repositorio;
  final SuscripcionServicio suscripcionServicio;
  final VoidCallback? onActualizar;

  const _PerfilFlumi({
    required this.perfil,
    required this.authService,
    required this.repositorio,
    required this.suscripcionServicio,
    this.onActualizar,
  });

  @override
  State<_PerfilFlumi> createState() => _PerfilFlumiState();
}

class _PerfilFlumiState extends State<_PerfilFlumi> {
  bool _fotoPrincipalError = false;

  static const _gradiente = [Color(0xFF6C63FF), Color(0xFFFF6584)];

  @override
  void didUpdateWidget(covariant _PerfilFlumi oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.perfil.uuid != widget.perfil.uuid ||
        oldWidget.perfil.fotosUrls.join() != widget.perfil.fotosUrls.join()) {
      _fotoPrincipalError = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
        children: [
          _encabezado(context),
          const SizedBox(height: 16),
          _tarjetaCompletado(context),
          if (!widget.perfil.verificadoStatus) ...[
            const SizedBox(height: 12),
            _tarjetaVerificacion(context),
          ],
          if (widget.suscripcionServicio.suscripcionesHabilitadas) ...[
            const SizedBox(height: 28),
            const _SeccionTitulo('Planes de suscripción'),
            const SizedBox(height: 12),
            _tarjetaPlanActual(context),
            const SizedBox(height: 12),
            _planes(),
          ],
        ],
      ),
    );
  }

  Widget _fotoWidget(String ruta) {
    if (kIsWeb && (ruta.startsWith('blob:') || ruta.startsWith('data:'))) {
      return Image.network(
        ruta,
        fit: BoxFit.cover,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        loadingBuilder: (_, __, ___) => const ShimmerCaja(radius: 0),
        errorBuilder: (_, __, ___) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_fotoPrincipalError) setState(() => _fotoPrincipalError = true);
          });
          return const PlaceholderFoto();
        },
      );
    }
    return imagenFoto(
      ruta,
      fit: BoxFit.cover,
      onError: () {
        if (mounted && !_fotoPrincipalError) setState(() => _fotoPrincipalError = true);
      },
      onLoad: () {
        if (mounted && _fotoPrincipalError) setState(() => _fotoPrincipalError = false);
      },
    );
  }

  Widget _encabezado(BuildContext context) {
    final inicial = widget.perfil.nombre.isNotEmpty
        ? widget.perfil.nombre[0].toUpperCase()
        : '?';
    final fotos = fotosParaMostrar(widget.perfil);
    final tieneFoto = fotos.isNotEmpty && !_fotoPrincipalError;
    return Row(
      children: [
        GestureDetector(
          onTap: tieneFoto ? () => _abrirGaleria(context, fotos) : null,
          child: Container(
            width: 104,
            height: 104,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _gradiente,
              ),
            ),
            child: ClipOval(
              child: tieneFoto
                  ? _fotoWidget(fotos.first)
                  : Center(
                      child: Text(
                        inicial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 44,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: GestureDetector(
            onTap: () => _abrirEditarPerfil(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${widget.perfil.nombre}, ${widget.perfil.edad}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.perfil.verificadoStatus) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, color: Colors.blueAccent, size: 22),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        widget.perfil.ciudad.trim().isNotEmpty
                            ? widget.perfil.ciudad
                            : 'Cerca de ti',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _abrirGaleria(BuildContext context, List<String> fotos) {
    if (fotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A\u00fan no tienes fotos'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VisorFotosPantalla(
          fotos: fotos,
          indiceInicial: 0,
        ),
      ),
    );
  }

  Future<void> _abrirEditarPerfil(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditarPerfilPantalla(
          perfil: widget.perfil,
          repositorio: widget.repositorio,
        ),
      ),
    );
    widget.onActualizar?.call();
  }

  Widget _tarjetaPlanActual(BuildContext context) {
    final s = widget.suscripcionServicio;
    final (icono, nombre, detalle) = switch (s.planActual) {
      PlanTipo.gratis => (
          Icons.eco,
          'Tu plan: Gratis',
          '${s.limites.meGustasPorDia} Me Gustas diarios · ${s.limites.superlikesPorDia} Superlikes · ${s.limites.vistasCercaPorDia} perfiles cerca',
        ),
      PlanTipo.plus => (
          Icons.auto_awesome,
          'Tu plan: Flumi Plus',
          'Me Gustas ilimitados · 10 Superlikes · 100 perfiles cerca · Visitas y historial',
        ),
      PlanTipo.premium => (
          Icons.workspace_premium,
          'Tu plan: Flumi Premium',
          'Acceso total sin límites',
        ),
    };
    return _tarjetaInfo(
      icono: icono,
      titulo: nombre,
      subtitulo: detalle,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AdministrarSuscripcionPantalla(
            suscripcionServicio: widget.suscripcionServicio,
          ),
        ),
      ),
    );
  }

  Widget _tarjetaCompletado(BuildContext context) {
    final porcentaje = calcularCompletadoPerfil(widget.perfil);
    final completo = porcentaje >= 100;
    return _tarjetaInfo(
      icono: Icons.fact_check_outlined,
      titulo: 'Perfil completado al $porcentaje%',
      subtitulo: completo
          ? 'Tu perfil est\u00e1 al d\u00eda y listo para m\u00e1s matches'
          : 'Completa tu perfil para recibir m\u00e1s matches',
      onTap: completo
          ? null
          : () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditarPerfilPantalla(
                    perfil: widget.perfil,
                    repositorio: widget.repositorio,
                  ),
                ),
              );
              widget.onActualizar?.call();
            },
    );
  }

  Widget _tarjetaVerificacion(BuildContext context) {
    final enRevision = widget.perfil.fotoVerificacion.isNotEmpty &&
        !widget.perfil.verificadoStatus;
    return _tarjetaInfo(
      icono: Icons.verified_outlined,
      titulo: enRevision
          ? 'Verificaci\u00f3n en revisi\u00f3n'
          : 'Verificaci\u00f3n de cuenta',
      subtitulo: enRevision
          ? 'Tu foto est\u00e1 siendo revisada por Flumi. Te avisaremos cuando termine.'
          : 'Verifica tu cuenta con una foto para ganar confianza',
      onTap: () async {
        final verificada = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => VerificacionCuentaPantalla(
              perfil: widget.perfil,
              repositorio: widget.repositorio,
            ),
          ),
        );
        if (verificada == true) widget.onActualizar?.call();
      },
    );
  }

  Widget _tarjetaInfo(
      {required IconData icono,
      required String titulo,
      required String subtitulo,
      VoidCallback? onTap}) {
    return Card(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icono, size: 26, color: const Color(0xFF6C63FF)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                    const SizedBox(height: 2),
                    Text(subtitulo,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _planes() {
    final planActual = widget.suscripcionServicio.planActual;
    return _CarruselPlanes(
      planes: [
        _TarjetaPlan(
          icono: Icons.eco,
          nombre: 'Flumi Gratis',
          periodo: 'sin costo',
          precio: '0 cup',
          detalle: 'Funciones b\u00e1sicas',
          esGratis: true,
          activo: planActual == PlanTipo.gratis,
        ),
        _TarjetaPlan(
          icono: Icons.auto_awesome,
          nombre: 'Flumi Plus',
          periodo: '30 d\u00edas',
          precio: '250 cup',
          detalle: 'Funciones extra',
          destacado: true,
          activo: planActual == PlanTipo.plus,
        ),
        _TarjetaPlan(
          icono: Icons.workspace_premium,
          nombre: 'Flumi Premium',
          periodo: '30 d\u00edas',
          precio: '500 cup',
          detalle: 'Acceso total',
          activo: planActual == PlanTipo.premium,
        ),
      ],
    );
  }
}

class _CarruselPlanes extends StatefulWidget {
  final List<Widget> planes;

  const _CarruselPlanes({required this.planes});

  @override
  State<_CarruselPlanes> createState() => _CarruselPlanesState();
}

class _CarruselPlanesState extends State<_CarruselPlanes> {
  final PageController _controller = PageController(viewportFraction: 0.82);
  int _paginaActiva = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.planes.length,
            padEnds: false,
            onPageChanged: (i) => setState(() => _paginaActiva = i),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: widget.planes[i],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.planes.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _paginaActiva == i ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _paginaActiva == i
                      ? const Color(0xFF6C63FF)
                      : Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TarjetaPlan extends StatelessWidget {
  final IconData icono;
  final String nombre;
  final String periodo;
  final String precio;
  final String detalle;
  final bool destacado;
  final bool esGratis;
  final bool activo;

  const _TarjetaPlan({
    required this.icono,
    required this.nombre,
    required this.periodo,
    required this.precio,
    required this.detalle,
    this.destacado = false,
    this.esGratis = false,
    this.activo = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorBase = esGratis
        ? Colors.grey[700]!
        : destacado
            ? const Color(0xFF6C63FF)
            : const Color(0xFFC9A227);
    final colorFondo = esGratis
        ? Colors.grey[100]!
        : destacado
            ? const Color(0xFFEFEBFF)
            : const Color(0xFFFFF7E0);
    final colorActivo =
        esGratis ? colorBase : const Color(0xFF6C63FF);
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DetallePlanPantalla(
              nombre: nombre,
              periodo: periodo,
              precio: precio,
              icono: icono,
              detalle: detalle,
              destacado: destacado,
              esGratis: esGratis,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: colorFondo,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: activo ? colorActivo : colorBase,
            width: activo ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icono, size: 32, color: colorBase),
            const SizedBox(height: 8),
            Text(
              nombre,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(periodo,
                style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            const SizedBox(height: 8),
            Text(
              precio,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: activo ? colorActivo : colorBase,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                activo && !esGratis ? 'Tu plan' : detalle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeccionTitulo extends StatelessWidget {
  final String texto;
  const _SeccionTitulo(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.grey[800],
      ),
    );
  }
}

class _BotonCerrarSesion extends StatelessWidget {
  final AuthService authService;
  const _BotonCerrarSesion({required this.authService});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final confirmado = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cerrar sesión'),
            content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        );
        if (confirmado == true) await authService.cerrarSesion();
      },
      icon: const Icon(Icons.logout, size: 20),
      label: const Text('Cerrar sesión', style: TextStyle(fontSize: 16)),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red[400],
        side: BorderSide(color: Colors.red[400]!),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
