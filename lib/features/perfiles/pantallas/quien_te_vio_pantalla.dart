import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/base_datos_local/database.dart';
import '../../../core/estilos/tema.dart';
import '../../../core/servicios/suscripcion_servicio.dart';
import '../../../core/servicios/visitas_historial_servicio.dart';
import '../../../widgets_comunes/flumi_loader.dart';
import '../../../widgets_comunes/tarjeta_usuario.dart';
import '../../perfiles/pantallas/detalle_plan_pantalla.dart';

class QuienTeVioPantalla extends StatefulWidget {
  final VisitasServicio visitasServicio;
  final SuscripcionServicio suscripcionServicio;

  const QuienTeVioPantalla({
    super.key,
    required this.visitasServicio,
    required this.suscripcionServicio,
  });

  @override
  State<QuienTeVioPantalla> createState() => _QuienTeVioPantallaState();
}

class _QuienTeVioPantallaState extends State<QuienTeVioPantalla> {
  List<Visita> _visitas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final puede = await widget.suscripcionServicio.puedeVerVisitas(0);
    if (!puede) {
      if (mounted) setState(() => _cargando = false);
      return;
    }
    final visitas = await widget.visitasServicio.obtenerVisitas();
    if (mounted) {
      setState(() {
        _visitas = visitas;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const CargandoBlanco();
    }

    if (!widget.suscripcionServicio.tienePlus) {
      return _bloqueo();
    }

    if (_visitas.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text(
              'Nadie ha visitado tu perfil aún',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: _visitas.length,
        itemBuilder: (context, index) {
          final visita = _visitas[index];
          return _VisitaTile(visita: visita);
        },
      ),
    );
  }

  Widget _bloqueo() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text(
              '¿Quién visitó tu perfil?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Disponible en Flumi Plus (20 visitas/día) y Premium (ilimitado)',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.push(
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
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Ver planes',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitaTile extends StatelessWidget {
  final Visita visita;

  const _VisitaTile({required this.visita});

  @override
  Widget build(BuildContext context) {
    final tiempo = _formatoTiempo(visita.timestamp);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: FlumiTema.colorPrimario.withValues(alpha: 0.15),
          child: Icon(Icons.person, color: FlumiTema.colorPrimario, size: 24),
        ),
        title: Text(
          'Visitante #${visita.visitanteId.substring(0, 8)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(tiempo),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
        onTap: () {
          // TODO: navegar a perfil del visitante cuando se tenga el UUID completo
        },
      ),
    );
  }

  String _formatoTiempo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays < 2) return 'Ayer';
    return DateFormat('dd/MM').format(dt);
  }
}