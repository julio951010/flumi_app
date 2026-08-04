import 'package:flutter/material.dart';
import '../../../core/api/mock_data.dart';
import '../../../core/base_datos_local/database.dart';
import '../../../widgets_comunes/shimmer_caja.dart';
import '../../../widgets_comunes/tarjeta_detalle_usuario.dart';
import '../../../widgets_comunes/tarjeta_usuario.dart';

class CercaDeTiPantalla extends StatefulWidget {
  final AppDatabase db;
  final String miId;

  const CercaDeTiPantalla({super.key, required this.db, required this.miId});

  @override
  State<CercaDeTiPantalla> createState() => _CercaDeTiPantallaState();
}

class _CercaDeTiPantallaState extends State<CercaDeTiPantalla> {
  List<Usuario> _usuarios = [];
  Set<String> _idsGustados = {};
  Set<String> _idsRecibidos = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final todos = await (widget.db.select(widget.db.usuarios)).get();
      todos.removeWhere((u) => u.uuid == widget.miId);
      final idsGustados =
          GeneradorMock.obtenerMisLikes().map((i) => i.usuarioId).toSet();
      final idsRecibidos = GeneradorMock.obtenerLikesRecibidos()
          .map((i) => i.usuarioId)
          .toSet();
      todos.removeWhere((u) => idsGustados.contains(u.uuid));
      if (mounted) {
        setState(() {
          _usuarios = todos;
          _idsGustados = idsGustados;
          _idsRecibidos = idsRecibidos;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return _esqueleto();
    if (_usuarios.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No hay usuarios cerca',
                style: TextStyle(fontSize: 18, color: Colors.grey[500])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: CustomScrollView(
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
                  final gustado = _idsGustados.contains(_usuarios[i].uuid);
                  final esMatch =
                      gustado && _idsRecibidos.contains(_usuarios[i].uuid);
                  return TarjetaUsuario(
                    usuario: _usuarios[i],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PerfilDetallePage(
                          usuario: _usuarios[i],
                          esMeGusta: gustado,
                          esMatch: esMatch,
                        ),
                      ),
                    ),
                    esquinaDerecha: esMatch
                        ? const Icon(Icons.whatshot,
                            color: Colors.orangeAccent, size: 18)
                        : gustado
                            ? const Icon(Icons.favorite,
                                color: Colors.redAccent, size: 18)
                            : null,
                  );
                },
                childCount: _usuarios.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bannerAd() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFFFF6584)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [                Text(
                  'Impulsa tu perfil',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Llega a m\u00e1s personas cerca de ti',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Ver plan',
              style: TextStyle(
                color: Color(0xFF6C63FF),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
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
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
          ),
          child: const Column(
            children: [
              Expanded(child: ShimmerCaja(radius: 0)),
              Padding(
                padding: EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerCaja(width: 80, height: 14),
                    SizedBox(height: 4),
                    ShimmerCaja(width: 60, height: 11),
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

class PerfilDetallePage extends StatelessWidget {
  final Usuario usuario;
  final bool gusta;
  final bool esMatch;
  final bool esMeGusta;
  const PerfilDetallePage({
    super.key,
    required this.usuario,
    this.gusta = false,
    this.esMatch = false,
    this.esMeGusta = false,
  });

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
                  usuario: usuario,
                  esMatch: esMatch,
                  esMeGusta: esMeGusta,
                  onRechazar: () => Navigator.pop(context),
                  gusta: gusta,
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 16,
              child: GestureDetector(
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
            ),
          ],
        ),
      ),
    );
  }
}
