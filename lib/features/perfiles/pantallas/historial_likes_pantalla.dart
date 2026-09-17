import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/base_datos_local/database.dart';
import '../../../core/servicios/suscripcion_servicio.dart';
import '../../../core/servicios/visitas_historial_servicio.dart';
import '../../../widgets_comunes/flumi_loader.dart';
import '../../perfiles/pantallas/detalle_plan_pantalla.dart';

class HistorialLikesPantalla extends StatefulWidget {
  final HistorialLikesServicio historialServicio;
  final SuscripcionServicio suscripcionServicio;

  const HistorialLikesPantalla({
    super.key,
    required this.historialServicio,
    required this.suscripcionServicio,
  });

  @override
  State<HistorialLikesPantalla> createState() => _HistorialLikesPantallaState();
}

class _HistorialLikesPantallaState extends State<HistorialLikesPantalla> {
  List<HistorialLike> _historial = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final puede = await widget.suscripcionServicio.puedeVerHistorialLikes(0);
    if (!puede) {
      if (mounted) setState(() => _cargando = false);
      return;
    }
    final historial = await widget.historialServicio.obtenerHistorial();
    if (mounted) {
      setState(() {
        _historial = historial;
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

    if (_historial.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text(
              'Aún no has dado Me Gusta a nadie',
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
        itemCount: _historial.length,
        itemBuilder: (context, index) {
          final like = _historial[index];
          return _HistorialTile(like: like);
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
              'Historial de tus Likes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Disponible en Flumi Plus (últimos 15) y Premium (ilimitado)',
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

class _HistorialTile extends StatelessWidget {
  final HistorialLike like;

  const _HistorialTile({required this.like});

  @override
  Widget build(BuildContext context) {
    final tiempo = _formatoTiempo(like.timestamp);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
          child: const Icon(Icons.favorite, color: Colors.redAccent, size: 24),
        ),
        title: Text(
          'Usuario #${like.usuarioLikeadoId.substring(0, 8)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('Te gustó $tiempo'),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
        onTap: () {
          // TODO: navegar a perfil cuando se tenga el UUID completo
        },
      ),
    );
  }

  String _formatoTiempo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays < 2) return 'Ayer';
    return DateFormat('dd/MM').format(dt);
  }
}