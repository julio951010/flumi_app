import 'package:drift/drift.dart';
import 'package:flutter/material.dart';

import '../../../core/base_datos_local/database.dart';
import '../../../core/servicios/notificacion_servicio.dart';
import '../../../core/servicios/suscripcion_servicio.dart';
import '../../perfiles/perfil_repositorio.dart';
import '../../perfiles/pantallas/detalle_plan_pantalla.dart';
import '../../../widgets_comunes/bloqueo_suscripcion_sheet.dart';

class ModoInvisiblePantalla extends StatefulWidget {
  final SuscripcionServicio suscripcionServicio;
  final PerfilRepositorio repositorio;

  const ModoInvisiblePantalla({
    super.key,
    required this.suscripcionServicio,
    required this.repositorio,
  });

  @override
  State<ModoInvisiblePantalla> createState() => _ModoInvisiblePantallaState();
}

class _ModoInvisiblePantallaState extends State<ModoInvisiblePantalla> {
  bool _ocultarPerfil = false;
  bool _ocultarVisitas = false;
  bool _cargando = true;
  String? _miUuid;

  @override
  void initState() {
    super.initState();
    _cargarEstado();
  }

  Future<void> _cargarEstado() async {
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() {
      _miUuid = perfil?.uuid;
      _ocultarPerfil = perfil?.ocultarPerfil ?? false;
      _ocultarVisitas = perfil?.ocultarVisitas ?? false;
      _cargando = false;
    });
  }

  Future<void> _guardar(bool guardarOcultarPerfil, bool valor) async {
    final uuid = _miUuid;
    if (uuid == null) {
      if (mounted) {
        NotificacionServicio.alerta(
            context, 'No se encontr\u00f3 tu perfil.');
      }
      return;
    }
    setState(() {
      if (guardarOcultarPerfil) {
        _ocultarPerfil = valor;
      } else {
        _ocultarVisitas = valor;
      }
    });
    try {
      final cambios = guardarOcultarPerfil
          ? UsuariosCompanion(uuid: Value(uuid), ocultarPerfil: Value(valor))
          : UsuariosCompanion(uuid: Value(uuid), ocultarVisitas: Value(valor));
      await widget.repositorio.guardarOCambiarPerfil(cambios);
    } catch (_) {
      if (mounted) {
        NotificacionServicio.alerta(
            context,
            'No se pudo guardar el cambio. '
            'Se reintentar\u00e1 cuando haya conexi\u00f3n.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;
    final bloqueado = !widget.suscripcionServicio.tienePremium;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Modo invisible',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _fila(
                    primario,
                    Icons.visibility_off_outlined,
                    'Ocultar mi perfil',
                    'Tu perfil no aparecer\u00e1 en los resultados de otras personas',
                    _ocultarPerfil,
                    (v) => _guardar(true, v),
                    bloqueado,
                  ),
                  const Divider(height: 1),
                  _fila(
                    primario,
                    Icons.remove_red_eye_outlined,
                    'Ocultar visitas',
                    'Nadie podr\u00e1 ver que visitaste su perfil',
                    _ocultarVisitas,
                    (v) => _guardar(false, v),
                    bloqueado,
                  ),
                  if (bloqueado) ...[
                    const SizedBox(height: 16),
                    Text(
                      'El modo invisible requiere Flumi Premium.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _fila(
    Color primario,
    IconData icono,
    String titulo,
    String descripcion,
    bool valor,
    ValueChanged<bool> onCambio,
    bool bloqueado,
  ) {
    return GestureDetector(
      onTap: bloqueado ? () => _mostrarBloqueoPremium(titulo) : null,
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

  void _mostrarBloqueoPremium(String funcionalidad) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BloqueoSuscripcionSheet(
        titulo: 'Requiere Flumi Premium',
        descripcion:
            '$funcionalidad es una funci\u00f3n exclusiva de Flumi Premium.',
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
}