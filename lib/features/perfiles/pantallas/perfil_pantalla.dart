import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:drift/drift.dart' hide Column;
import '../../../config/env.dart';
import '../../../core/base_datos_local/database.dart';
import '../../../core/estilos/tema.dart';
import '../../../widgets_comunes/shimmer_caja.dart';
import '../../auth/auth_service.dart';
import '../perfil_repositorio.dart';
import 'editar_perfil_pantalla.dart';
import '../../encuentros/pantallas/cerca_de_ti_pantalla.dart' show PerfilDetallePage;

class PerfilPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;
  final VoidCallback? onConfiguracion;

  const PerfilPantalla({
    super.key,
    required this.repositorio,
    this.onConfiguracion,
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
    _cargarPerfil();
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
    return _PerfilBadoo(
      perfil: _perfil!,
      authService: auth,
      repositorio: widget.repositorio,
    );
  }

  Widget _esqueleto() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        ShimmerCaja(height: 420, radius: 0),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerCaja(width: 200, height: 26),
              SizedBox(height: 8),
              ShimmerCaja(width: 120, height: 14),
              SizedBox(height: 24),
              ShimmerCaja(width: 120, height: 18),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: ShimmerCaja(height: 64)),
                  SizedBox(width: 12),
                  Expanded(child: ShimmerCaja(height: 64)),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: ShimmerCaja(height: 64)),
                  SizedBox(width: 12),
                  Expanded(child: ShimmerCaja(height: 64)),
                ],
              ),
              SizedBox(height: 28),
              ShimmerCaja(height: 50),
            ],
          ),
        ),
      ],
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

class _PerfilBadoo extends StatelessWidget {
  final Usuario perfil;
  final AuthService authService;
  final PerfilRepositorio repositorio;

  const _PerfilBadoo({
    required this.perfil,
    required this.authService,
    required this.repositorio,
  });

  static const _gradiente = [Color(0xFF6C63FF), Color(0xFFFF6584)];

  int _calcularCompletado(Usuario p) {
    final checks = <bool>[
      p.biografia.trim().isNotEmpty,
      p.fotosLocalesRutas.isNotEmpty,
      p.preferenciaEdadMin != 18 || p.preferenciaEdadMax != 99,
      p.queBusca.trim().isNotEmpty,
      p.intereses.isNotEmpty,
      p.altura.trim().isNotEmpty,
      p.educacion.trim().isNotEmpty,
      p.trabajo.trim().isNotEmpty,
      p.bebe.isNotEmpty || p.fuma.isNotEmpty || p.hijos.isNotEmpty,
      p.personalidad.trim().isNotEmpty,
      p.signoZodiaco.trim().isNotEmpty,
      p.mascotas.trim().isNotEmpty || p.religion.trim().isNotEmpty,
    ];
    return (checks.where((c) => c).length * 100 / checks.length).round();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _encabezado(context),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _tarjetaInfo(
                  icono: Icons.fact_check_outlined,
                  titulo: 'Perfil completado al ${_calcularCompletado(perfil)}%',
                  subtitulo: 'Completa tu perfil para recibir más matches',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _tarjetaInfo(
            icono: Icons.verified_outlined,
            titulo: 'Verificación de foto',
            subtitulo: 'Agrega una foto para verificar tu cuenta',
          ),
          const SizedBox(height: 28),
          const _SeccionTitulo('Planes de suscripción'),
          const SizedBox(height: 12),
          _planes(),
        ],
      ),
    );
  }

  Widget _encabezado(BuildContext context) {
    final inicial =
        perfil.nombre.isNotEmpty ? perfil.nombre[0].toUpperCase() : '?';
    return Row(
      children: [
        Container(
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
          child: Center(
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
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      '${perfil.nombre}, ${perfil.edad}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (perfil.verificadoStatus) ...[
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
                  Text('Cerca de ti',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tarjetaInfo(
      {required IconData icono,
      required String titulo,
      required String subtitulo,
      Widget? trailing}) {
    return Card(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
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
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ] else
              Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _planes() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _TarjetaPlan(
            icono: Icons.auto_awesome,
            nombre: 'Plus',
            periodo: '1 mes',
            precio: '\$9.99',
            detalle: 'Prueba Flumi',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TarjetaPlan(
            icono: Icons.workspace_premium,
            nombre: 'Gold',
            periodo: '3 meses',
            precio: '\$19.99',
            detalle: 'M\u00e1s popular',
            destacado: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TarjetaPlan(
            icono: Icons.diamond,
            nombre: 'VIP',
            periodo: '6 meses',
            precio: '\$29.99',
            detalle: 'Mejor precio',
          ),
        ),
      ],
    );
  }

  Widget _botonVistaPrevia(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PerfilDetallePage(usuario: perfil),
            ),
          );
        },
        icon: const Icon(Icons.visibility_outlined, size: 20),
        label: const Text('Vista previa de mi perfil',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: FlumiTema.colorPrimario,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
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

  const _TarjetaPlan({
    required this.icono,
    required this.nombre,
    required this.periodo,
    required this.precio,
    required this.detalle,
    this.destacado = false,
  });

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Suscripci\u00f3n pr\u00f3ximamente'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: destacado ? const Color(0xFFFFF3E0) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: destacado ? primario : Colors.grey[200]!,
            width: destacado ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icono, size: 30, color: destacado ? primario : Colors.grey[500]),
            const SizedBox(height: 8),
            Text(
              nombre,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(periodo, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            const SizedBox(height: 8),
            Text(
              precio,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: destacado ? primario : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                detalle,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: destacado ? Colors.white : Colors.grey[600],
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
