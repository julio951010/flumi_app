import 'package:flutter/material.dart';
import '../../../config/env.dart';
import '../../../core/api/mock_data.dart';
import '../../../core/base_datos_local/database.dart';
import '../../../widgets_comunes/imagen_difuminada.dart';
import '../../../widgets_comunes/shimmer_caja.dart';
import '../../../widgets_comunes/tarjeta_usuario.dart';
import 'cerca_de_ti_pantalla.dart' show PerfilDetallePage;

class MeGustaPantalla extends StatefulWidget {
  final AppDatabase db;
  final String miId;
  const MeGustaPantalla({super.key, required this.db, required this.miId});

  @override
  State<MeGustaPantalla> createState() => _MeGustaPantallaState();
}

class _MeGustaPantallaState extends State<MeGustaPantalla>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<_ItemInteraccion> _likes = [];
  List<_ItemInteraccion> _visitas = [];
  List<_ItemInteraccion> _misLikes = [];
  Set<String> _idsGustados = {};
  Set<String> _idsRecibidos = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _cargar();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final todos = await widget.db.select(widget.db.usuarios).get();
      final mapa = {for (final u in todos) u.uuid: u};

      _likes = GeneradorMock.obtenerLikesRecibidos()
          .map((i) => _ItemInteraccion(usuario: mapa[i.usuarioId], timestamp: i.timestamp))
          .where((i) => i.usuario != null)
          .toList();

      _visitas = GeneradorMock.obtenerVisitas()
          .map((i) => _ItemInteraccion(usuario: mapa[i.usuarioId], timestamp: i.timestamp))
          .where((i) => i.usuario != null)
          .toList();

      _misLikes = GeneradorMock.obtenerMisLikes()
          .map((i) => _ItemInteraccion(usuario: mapa[i.usuarioId], timestamp: i.timestamp))
          .where((i) => i.usuario != null)
          .toList();

      _idsGustados =
          GeneradorMock.obtenerMisLikes().map((i) => i.usuarioId).toSet();
      _idsRecibidos = GeneradorMock.obtenerLikesRecibidos()
          .map((i) => i.usuarioId)
          .toSet();
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _formatoTiempo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays < 2) return 'Ayer';
    return 'Hace ${diff.inDays} d\u00edas';
  }

  @override
  Widget build(BuildContext context) {
    final esPremium = kEsPremium;
    final totalLikes = _likes.length;

    return Column(
      children: [
        if (!esPremium && totalLikes > 0)
          _bannerPremium(totalLikes),
        SizedBox(
          height: 42,
          child: TabBar(
            controller: _tabCtrl,
            indicatorColor: Colors.black87,
            labelColor: Colors.black87,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: 'Le gustas (${_likes.length})'),
              Tab(text: 'Visitas (${_visitas.length})'),
              Tab(text: 'Mis Likes (${_misLikes.length})'),
            ],
          ),
        ),
        Expanded(
          child: _cargando
              ? _esqueleto()
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _grilla(_likes, esPremium),
                    _grilla(_visitas, esPremium),
                    _grilla(_misLikes, esPremium),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _esqueleto() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 70),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.72,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
            ],
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

  Widget _bannerPremium(int total) {
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
          '\u00a1Tienes $total personas que quieren conocerte!',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Desbloquea qui\u00e9n te busca',
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
              'Ver planes',
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

  Widget _grilla(List<_ItemInteraccion> items, bool esPremium) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Sin actividad por aqu\u00ed',
          style: TextStyle(color: Colors.grey[400], fontSize: 15),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 70),
        child: GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.72,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final usuario = item.usuario!;
            final tiempo = _formatoTiempo(item.timestamp);
            final gustado = _idsGustados.contains(usuario.uuid);
            final esMatch = gustado && _idsRecibidos.contains(usuario.uuid);

            return TarjetaUsuario(
              usuario: usuario,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PerfilDetallePage(
                    usuario: usuario,
                    esMeGusta: gustado,
                    esMatch: esMatch,
                  ),
                ),
              ),
              imagenOverlay: !esPremium
                  ? Positioned.fill(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (usuario.fotosLocalesRutas.isNotEmpty)
                            ImagenDifuminada(
                              ruta: usuario.fotosLocalesRutas.first,
                              sigma: 20,
                            ),
                          Container(
                              color: Colors.black.withValues(alpha: 0.2)),
                        ],
                      ),
                    )
                  : null,
              esquinaDerecha: esMatch
                  ? const Icon(Icons.whatshot,
                      color: Colors.orangeAccent, size: 18)
                  : gustado
                      ? const Icon(Icons.favorite,
                          color: Colors.redAccent, size: 18)
                      : null,
              badge: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tiempo,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ItemInteraccion {
  final Usuario? usuario;
  final DateTime timestamp;
  _ItemInteraccion({required this.usuario, required this.timestamp});
}
