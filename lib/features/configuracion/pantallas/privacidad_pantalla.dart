import 'package:flutter/material.dart';

import '../../../core/base_datos_local/database.dart';
import '../../../core/servicios/suscripcion_servicio.dart';
import '../../../core/servicios/sync_service.dart';
import '../../../features/perfiles/pantallas/detalle_plan_pantalla.dart';
import '../../../features/perfiles/perfil_repositorio.dart';
import '../../../widgets_comunes/bloqueo_suscripcion_sheet.dart';
import '../../../widgets_comunes/flumi_loader.dart';
import 'personas_bloqueadas_pantalla.dart';

class PrivacidadPantalla extends StatefulWidget {
  final AppDatabase db;
  final SuscripcionServicio suscripcionServicio;
  final SyncService syncService;
  final PerfilRepositorio repositorio;

  const PrivacidadPantalla({
    super.key,
    required this.db,
    required this.suscripcionServicio,
    required this.syncService,
    required this.repositorio,
  });

  @override
  State<PrivacidadPantalla> createState() => _PrivacidadPantallaState();
}

class _PrivacidadPantallaState extends State<PrivacidadPantalla> {
  bool _mostrarUbicacion = true;
  bool _mostrarEnLinea = true;
  bool _soloRangoEdad = false;
  bool _soloPersonasQueMeGustan = false;
  bool _mensajesSoloGustados = false;
  bool _mensajesSoloVerificados = false;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarPrivacidad();
  }

  Future<void> _cargarPrivacidad() async {
    try {
      final user = await (widget.db.select(widget.db.usuarios)
            ..where((u) => u.esPerfilPropio.equals(true))
            ..limit(1))
          .getSingleOrNull();
      if (user != null) {
        setState(() {
          _mostrarEnLinea = !user.ocultarEnLinea;
          _soloRangoEdad = user.ocultarEdad;
          _cargando = false;
        });
      }
    } catch (_) {
      setState(() => _cargando = false);
    }
  }

  Future<void> _guardarOcultarEnLinea(bool valor) async {
    if (!widget.suscripcionServicio.tienePremium) {
      _mostrarBloqueoPremium('Mostrarme en línea');
      return;
    }
    final user = await (widget.db.select(widget.db.usuarios)
          ..where((u) => u.esPerfilPropio.equals(true))
          ..limit(1))
        .getSingleOrNull();
    if (user != null) {
      await widget.db.update(widget.db.usuarios).replace(
        user.copyWith(ocultarEnLinea: !valor, pendienteDeSincronizar: true),
      );
      widget.syncService.sincronizarPerfil();
    }
    if (mounted) setState(() => _mostrarEnLinea = valor);
  }

  Future<void> _guardarOcultarEdad(bool valor) async {
    if (!widget.suscripcionServicio.tienePlus) {
      _mostrarBloqueoPlus('Mostrarme solo a personas dentro de mi rango de edad');
      return;
    }
    final user = await (widget.db.select(widget.db.usuarios)
          ..where((u) => u.esPerfilPropio.equals(true))
          ..limit(1))
        .getSingleOrNull();
    if (user != null) {
      await widget.db.update(widget.db.usuarios).replace(
        user.copyWith(ocultarEdad: valor, pendienteDeSincronizar: true),
      );
      widget.syncService.sincronizarPerfil();
    }
    if (mounted) setState(() => _soloRangoEdad = valor);
  }

  void _mostrarBloqueoPremium(String funcionalidad) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BloqueoSuscripcionSheet(
        titulo: 'Requiere Flumi Premium',
        descripcion: '$funcionalidad es una función exclusiva de Flumi Premium.',
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
      ),
    );
  }

  void _mostrarBloqueoPlus(String funcionalidad) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BloqueoSuscripcionSheet(
        titulo: 'Requiere Flumi Plus',
        descripcion: '$funcionalidad es una función de Flumi Plus.',
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
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: CargandoBlanco(),
      );
    }
    final primario = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Privacidad',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _filaConGate(
              primario,
              Icons.location_on_outlined,
              'Mostrar mi ubicación',
              'Permite que otras personas vean tu ubicación',
              _mostrarUbicacion,
              (v) => setState(() => _mostrarUbicacion = v),
              requierePremium: true,
            ),
            const Divider(height: 1),
            _filaConGate(
              primario,
              Icons.circle_outlined,
              'Mostrarme en línea',
              'Muestra tu estado de conexión a otras personas',
              _mostrarEnLinea,
              (v) => _guardarOcultarEnLinea(v),
              requierePremium: true,
            ),
            const Divider(height: 1),
            _filaConGate(
              primario,
              Icons.cake_outlined,
              'Mostrarme solo a personas dentro de mi rango de edad',
              'Solo las personas dentro del rango de edad que configures podrán ver tu perfil',
              _soloRangoEdad,
              (v) => _guardarOcultarEdad(v),
              requierePlus: true,
            ),
            const Divider(height: 1),
            _filaConGate(
              primario,
              Icons.favorite_outline,
              'Mostrarme solo a personas que me gustan',
              'Solo las personas a las que les diste "me gusta" podrán ver tu perfil',
              _soloPersonasQueMeGustan,
              (v) => _guardarVisibilidadSelectiva(v),
              requierePremium: true,
            ),
            const Divider(height: 1),
            _filaConGate(
              primario,
              Icons.forum_outlined,
              'Recibir mensajes solo de las personas que me gustan',
              'Solo las personas a las que les diste "me gusta" podrán escribirte',
              _mensajesSoloGustados,
              (v) => _guardarFiltroMensajes(v, true),
              requierePremium: true,
            ),
            const Divider(height: 1),
            _filaConGate(
              primario,
              Icons.verified_outlined,
              'Recibir mensajes solo de perfiles verificados',
              'Solo los perfiles con verificación podrán escribirte',
              _mensajesSoloVerificados,
              (v) => _guardarFiltroMensajes(v, false),
              requierePremium: true,
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.block_outlined,
                color: primario.withValues(alpha: 0.7),
              ),
              title: const Text(
                'Lista de personas bloqueadas',
                style: TextStyle(fontSize: 15, color: Colors.black87),
              ),
              trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PersonasBloqueadasPantalla(
                    db: widget.db,
                    repositorio: widget.repositorio,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _guardarVisibilidadSelectiva(bool valor) async {
    // Por ahora solo UI, se conectaría con backend/sync
    if (!widget.suscripcionServicio.tienePremium) {
      _mostrarBloqueoPremium('Visibilidad selectiva');
      return;
    }
    setState(() => _soloPersonasQueMeGustan = valor);
  }

  Future<void> _guardarFiltroMensajes(bool valor, bool soloGustados) async {
    if (!widget.suscripcionServicio.tienePremium) {
      _mostrarBloqueoPremium('Filtro de mensajes');
      return;
    }
    setState(() {
      if (soloGustados) {
        _mensajesSoloGustados = valor;
      } else {
        _mensajesSoloVerificados = valor;
      }
    });
  }

  Widget _filaConGate(
    Color primario,
    IconData icono,
    String titulo,
    String descripcion,
    bool valor,
    ValueChanged<bool> onCambio, {
    bool requierePlus = false,
    bool requierePremium = false,
  }) {
    final bloqueado = (requierePremium && !widget.suscripcionServicio.tienePremium) ||
        (requierePlus && !widget.suscripcionServicio.tienePlus);

    return GestureDetector(
      onTap: bloqueado
          ? () => requierePremium
              ? _mostrarBloqueoPremium(titulo)
              : _mostrarBloqueoPlus(titulo)
          : null,
      child: SwitchListTile(
        value: valor,
        onChanged: bloqueado ? null : onCambio,
        activeTrackColor: primario,
      secondary: Icon(
        icono,
        color: bloqueado ? Colors.grey : primario.withValues(alpha: 0.7),
      ),
      title: Text(
        titulo,
        style: TextStyle(
          fontSize: 15,
          color: bloqueado ? Colors.grey : Colors.black87,
        ),
      ),
      subtitle: Text(
        descripcion,
        style: TextStyle(
          fontSize: 13,
          color: bloqueado ? Colors.grey : Colors.black54,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
    );
  }
}
