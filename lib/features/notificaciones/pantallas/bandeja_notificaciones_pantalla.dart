import 'package:flutter/material.dart';
import '../../../core/api/mock_data.dart';
import '../../../core/base_datos_local/database.dart';
import '../../../core/estilos/tema.dart';
import '../../../widgets_comunes/shimmer_caja.dart';
import '../../chat/chat_repositorio.dart';
import '../../chat/pantallas/chat_pantalla.dart';
import '../../encuentros/pantallas/cerca_de_ti_pantalla.dart'
    show PerfilDetallePage;

enum TipoNotificacion { meGusta, visita, match, mensaje }

class BandejaNotificacionesPantalla extends StatefulWidget {
  final AppDatabase db;
  final String miId;
  final VoidCallback? onAbierto;

  const BandejaNotificacionesPantalla({
    super.key,
    required this.db,
    required this.miId,
    this.onAbierto,
  });

  @override
  State<BandejaNotificacionesPantalla> createState() =>
      _BandejaNotificacionesPantallaState();
}

class _NotificacionInbox {
  final String id;
  final TipoNotificacion tipo;
  final Usuario? usuario;
  final String nombre;
  final DateTime timestamp;
  final String? preview;

  const _NotificacionInbox({
    required this.id,
    required this.tipo,
    required this.usuario,
    required this.nombre,
    required this.timestamp,
    this.preview,
  });
}

class _BandejaNotificacionesPantallaState
    extends State<BandejaNotificacionesPantalla> {
  static const _paletaAvatares = [
    [Color(0xFF6C63FF), Color(0xFFFF6584)],
    [Color(0xFF4ECDC4), Color(0xFF2ecc71)],
    [Color(0xFF667eea), Color(0xFF764ba2)],
    [Color(0xFFf093fb), Color(0xFFf5576c)],
    [Color(0xFF3AA5ED), Color(0xFF7B2CBF)],
  ];

  final Set<String> _leidas = {};
  List<_NotificacionInbox> _items = [];
  bool _cargando = true;
  bool _marcadoVisto = false;
  late final ChatRepositorio _chatRepo = ChatRepositorio(widget.db);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final todos = await widget.db.select(widget.db.usuarios).get();
      final mapa = {for (final u in todos) u.uuid: u};
      final miId = widget.miId;
      final items = <_NotificacionInbox>[];

      for (final i in GeneradorMock.obtenerLikesRecibidos()) {
        final u = mapa[i.usuarioId];
        if (u == null) continue;
        items.add(_NotificacionInbox(
          id: 'meGusta:${u.uuid}',
          tipo: TipoNotificacion.meGusta,
          usuario: u,
          nombre: u.nombre,
          timestamp: i.timestamp,
        ));
      }

      for (final i in GeneradorMock.obtenerVisitas()) {
        final u = mapa[i.usuarioId];
        if (u == null) continue;
        items.add(_NotificacionInbox(
          id: 'visita:${u.uuid}',
          tipo: TipoNotificacion.visita,
          usuario: u,
          nombre: u.nombre,
          timestamp: i.timestamp,
        ));
      }

      final matches = await (widget.db.select(widget.db.matches)).get();
      for (final m in matches) {
        if (m.usuarioAId != miId && m.usuarioBId != miId) continue;
        final otroId = m.usuarioAId == miId ? m.usuarioBId : m.usuarioAId;
        final u = mapa[otroId];
        if (u == null) continue;
        items.add(_NotificacionInbox(
          id: 'match:${u.uuid}',
          tipo: TipoNotificacion.match,
          usuario: u,
          nombre: u.nombre,
          timestamp: m.timestampMatch,
        ));
      }

      final mensajes =
          await (widget.db.select(widget.db.mensajes)
                ..where((m) => m.receptorId.equals(miId)))
              .get();
      final ultimosPorEmisor = <String, Mensaje>{};
      for (final ms in mensajes) {
        final prev = ultimosPorEmisor[ms.emisorId];
        if (prev == null || prev.timestamp.isBefore(ms.timestamp)) {
          ultimosPorEmisor[ms.emisorId] = ms;
        }
      }
      for (final ms in ultimosPorEmisor.values) {
        final u = mapa[ms.emisorId];
        if (u == null) continue;
        items.add(_NotificacionInbox(
          id: 'mensaje:${u.uuid}',
          tipo: TipoNotificacion.mensaje,
          usuario: u,
          nombre: u.nombre,
          timestamp: ms.timestamp,
          preview: ms.contenido,
        ));
      }

      if (mounted) {
        setState(() {
          items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          _items = items;
          if (!_marcadoVisto) {
            _marcadoVisto = true;
            for (final n in items) {
              _leidas.add(n.id);
            }
          }
        });
        if (_marcadoVisto) {
          widget.onAbierto?.call();
        }
      }
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

  String _texto(_NotificacionInbox n) {
    switch (n.tipo) {
      case TipoNotificacion.meGusta:
        return 'A ${n.nombre} le gust\u00f3 tu perfil';
      case TipoNotificacion.visita:
        return '${n.nombre} visit\u00f3 tu perfil';
      case TipoNotificacion.match:
        return '\u00a1Hiciste match con ${n.nombre}!';
      case TipoNotificacion.mensaje:
        return 'Nuevo mensaje de ${n.nombre}';
    }
  }

  IconData _icono(TipoNotificacion tipo) {
    switch (tipo) {
      case TipoNotificacion.meGusta:
        return Icons.favorite;
      case TipoNotificacion.visita:
        return Icons.visibility_outlined;
      case TipoNotificacion.match:
        return Icons.whatshot;
      case TipoNotificacion.mensaje:
        return Icons.chat_bubble;
    }
  }

  Color _colorIcono(TipoNotificacion tipo) {
    switch (tipo) {
      case TipoNotificacion.meGusta:
        return Colors.redAccent;
      case TipoNotificacion.visita:
        return Colors.blueAccent;
      case TipoNotificacion.match:
        return Colors.orangeAccent;
      case TipoNotificacion.mensaje:
        return FlumiTema.colorPrimario;
    }
  }

  int get _noLeidas => _items.where((n) => !_leidas.contains(n.id)).length;

  void _marcarTodosLeidos() {
    setState(() {
      for (final n in _items) {
        _leidas.add(n.id);
      }
    });
  }

  void _abrir(_NotificacionInbox n) {
    setState(() {
      _leidas.add(n.id);
      _items.removeWhere((item) => item.id == n.id && item.timestamp == n.timestamp);
    });
    final usuario = n.usuario;
    if (usuario == null) return;
    final esMatch = n.tipo == TipoNotificacion.match ||
        (n.tipo == TipoNotificacion.meGusta &&
            GeneradorMock.obtenerLikesRecibidos()
                .map((i) => i.usuarioId)
                .contains(usuario.uuid) &&
            GeneradorMock.obtenerMisLikes()
                .map((i) => i.usuarioId)
                .contains(usuario.uuid));

    if (n.tipo == TipoNotificacion.match ||
        n.tipo == TipoNotificacion.mensaje) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPantalla(
            repositorio: _chatRepo,
            otroUsuarioId: usuario.uuid,
            miId: widget.miId,
            nombreOtro: usuario.nombre,
            online: usuario.ultimaSincronizacionTimestamp != null,
            esMeGusta: n.tipo == TipoNotificacion.match ? false : true,
            esMatch: esMatch,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PerfilDetallePage(
            usuario: usuario,
            esMeGusta: n.tipo == TipoNotificacion.meGusta,
            esMatch: esMatch,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Notificaciones',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        actions: [
          if (_noLeidas > 0)
            IconButton(
              icon: Icon(Icons.done_all, color: primario, size: 22),
              onPressed: _marcarTodosLeidos,
              tooltip: 'Marcar todas como le\u00eddas',
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _cargando
            ? _esqueleto()
            : _items.isEmpty
                ? _vacio()
                : RefreshIndicator(
                    onRefresh: _cargar,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final n = _items[index];
                        final leida = _leidas.contains(n.id);
                        return _fila(n, leida, primario);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _fila(_NotificacionInbox n, bool leida, Color primario) {
    final usuario = n.usuario;
    final nombre = n.nombre;
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';
    final gradiente =
        _paletaAvatares[nombre.hashCode.abs() % _paletaAvatares.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: leida ? Colors.white : primario.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _abrir(n),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradiente,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        inicial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_icono(n.tipo), color: _colorIcono(n.tipo), size: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (usuario?.verificadoStatus ?? false) ...[
                            const Icon(Icons.verified,
                                color: Colors.blueAccent, size: 15),
                            const SizedBox(width: 3),
                          ],
                          Flexible(
                            child: Text(
                              _texto(n),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                fontWeight:
                                    leida ? FontWeight.normal : FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (n.preview != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          n.preview!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatoTiempo(n.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: leida ? Colors.grey[400] : primario,
                        fontWeight:
                            leida ? FontWeight.normal : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (!leida)
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: primario,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _vacio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.notifications_none,
                  size: 44, color: Colors.grey[400]),
            ),
            const SizedBox(height: 20),
            const Text(
              'No tienes notificaciones',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Cuando tengas matches, mensajes, likes o visitas te avisaremos aqu\u00ed.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500], height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _esqueleto() {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            ShimmerCaja(width: 52, height: 52, radius: 26),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerCaja(width: 160, height: 14),
                  SizedBox(height: 8),
                  ShimmerCaja(width: 100, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}