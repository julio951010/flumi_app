import 'package:flutter/material.dart';
import '../../../config/env.dart';
import '../../../core/api/mock_data.dart';
import '../../../core/base_datos_local/database.dart';
import '../../../widgets_comunes/shimmer_caja.dart';
import '../../encuentros/pantallas/cerca_de_ti_pantalla.dart'
    show PerfilDetallePage;
import '../chat_repositorio.dart';
import 'chat_pantalla.dart';

class ChatsPantalla extends StatefulWidget {
  final AppDatabase db;
  final ChatRepositorio repositorio;
  final String miId;

  const ChatsPantalla({
    super.key,
    required this.db,
    required this.repositorio,
    required this.miId,
  });

  @override
  State<ChatsPantalla> createState() => _ChatsPantallaState();
}

class _ChatsPantallaState extends State<ChatsPantalla> {
  static const _paletaAvatares = [
    [Color(0xFF6C63FF), Color(0xFFFF6584)],
    [Color(0xFF4ECDC4), Color(0xFF2ecc71)],
    [Color(0xFF667eea), Color(0xFF764ba2)],
    [Color(0xFFf093fb), Color(0xFFf5576c)],
    [Color(0xFF3AA5ED), Color(0xFF7B2CBF)],
  ];

  bool _sembrado = false;
  final _scrollCtrl = ScrollController();
  final _perfilesKey = GlobalKey();
  final _conversacionesKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _sembrar();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sembrar() async {
    if (kUsarModoMock && !_sembrado) {
      _sembrado = true;
      await GeneradorMock.sembrarConversacionesSiVacio(widget.db, widget.miId);
    }
  }

  String _formatoHora(DateTime dt) {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final dia = DateTime(dt.year, dt.month, dt.day);
    if (dia == hoy) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    if (dia == hoy.subtract(const Duration(days: 1))) return 'Ayer';
    final diff = ahora.difference(dt);
    if (diff.inDays < 7) return 'Hace ${diff.inDays} d\u00eda${diff.inDays == 1 ? '' : 's'}';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Color _colorAvatar(String nombre) {
    final lista = _paletaAvatares[nombre.hashCode.abs() % _paletaAvatares.length];
    return Color.lerp(lista[0], lista[1], 0.5)!;
  }

  Future<void> _irASeccion(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _abrirChat(ResumenConversacion conv) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPantalla(
          repositorio: widget.repositorio,
          otroUsuarioId: conv.otroUsuarioId,
          miId: widget.miId,
          nombreOtro: conv.nombre,
          online: conv.online,
          esMeGusta: conv.esMeGusta,
          esMatch: conv.esMatch,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ResumenConversacion>>(
      stream: widget.repositorio.observarConversaciones(widget.miId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'No se pudieron cargar las conversaciones',
              style: TextStyle(color: Colors.grey[500], fontSize: 15),
            ),
          );
        }
        final conversaciones = snapshot.data;
        if (conversaciones == null) return _esqueleto();
        if (conversaciones.isEmpty) return _vacio();

        return StreamBuilder<List<PerfilChat>>(
          stream: widget.repositorio.observarPerfiles(widget.miId),
          builder: (context, snapPerf) {
            final perfiles = snapPerf.data ?? const <PerfilChat>[];
            final noLeidos = conversaciones.fold<int>(
                0, (acc, c) => acc + c.noLeidos);
            final totalMatches = perfiles.where((p) => p.esMatch).length;

            return RefreshIndicator(
              onRefresh: () async {},
              child: ListView(
                controller: _scrollCtrl,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                children: [
                  if (noLeidos > 0 || totalMatches > 0)
                    _banner(noLeidos: noLeidos, totalMatches: totalMatches),
                  const SizedBox(height: 4),
                  if (perfiles.isNotEmpty) ...[
                    _encabezadoSeccion('Perfiles', key: _perfilesKey),
                    const SizedBox(height: 4),
                    _filaPerfiles(perfiles),
                    const SizedBox(height: 14),
                  ],
                  if (conversaciones.isNotEmpty) ...[
                    _encabezadoSeccion(
                        'Conversaciones', key: _conversacionesKey),
                    const SizedBox(height: 8),
                    for (final conv in conversaciones)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _fila(conv),
                      ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _encabezadoSeccion(String titulo, {Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        titulo,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _banner({required int noLeidos, required int totalMatches}) {
    final hayMensajes = noLeidos > 0;
    final titulo = hayMensajes
        ? '\u00a1Tienes $noLeidos mensaje${noLeidos == 1 ? '' : 's'} nuevo${noLeidos == 1 ? '' : 's'}!'
        : '\u00a1Tienes $totalMatches match${totalMatches == 1 ? '' : 'es'} para conocer!';
    final subtitulo =
        hayMensajes ? 'No te los pierdas' : 'Empieza a chatear';
    final etiqueta = hayMensajes ? 'Ver mensajes' : 'Ver perfiles';
    final destino =
        hayMensajes ? _conversacionesKey : _perfilesKey;

    return Container(
      width: double.infinity,
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
                  titulo,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitulo,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _irASeccion(destino),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                etiqueta,
                style: const TextStyle(
                  color: Color(0xFF6C63FF),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaPerfiles(List<PerfilChat> perfiles) {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: perfiles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) => _perfilCirculo(perfiles[index]),
      ),
    );
  }

  Widget _perfilCirculo(PerfilChat perfil) {
    final usuario = perfil.usuario;
    final nombre = usuario.nombre;
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';
    final gradiente = _paletaAvatares[
        nombre.hashCode.abs() % _paletaAvatares.length];

    final avatar = Container(
      width: 64,
      height: 64,
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
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    return GestureDetector(
      onTap: () {
        if (perfil.esMatch) {
          _abrirChat(ResumenConversacion(
            otroUsuarioId: usuario.uuid,
            nombre: nombre,
            ultimoMensaje: '',
            ultimoEsMio: false,
            timestamp: perfil.timestamp,
            noLeidos: 0,
            online: usuario.ultimaSincronizacionTimestamp != null,
            esMeGusta: perfil.esMeGusta,
            esMatch: perfil.esMatch,
          ));
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PerfilDetallePage(
                usuario: usuario,
                gusta: true,
                esMatch: perfil.esMatch,
                esMeGusta: perfil.esMeGusta,
              ),
            ),
          );
        }
      },
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                if (perfil.esMatch)
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradiente,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: avatar,
                  )
                else
                  avatar,
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      color: usuario.ultimaSincronizacionTimestamp != null
                          ? const Color(0xFF4CD964)
                          : Colors.grey[400],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
                if (perfil.esMatch || perfil.esMeGusta)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: perfil.esMatch
                          ? const Icon(Icons.whatshot,
                              color: Colors.orangeAccent, size: 12)
                          : const Icon(Icons.favorite,
                              color: Colors.redAccent, size: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (usuario.verificadoStatus) ...[
                  const Icon(Icons.verified,
                      color: Colors.blueAccent, size: 12),
                  const SizedBox(width: 2),
                ],
                Flexible(
                  child: Text(
                    '$nombre, ${usuario.edad}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _fila(ResumenConversacion conv) {
    final inicial = conv.nombre.isNotEmpty ? conv.nombre[0].toUpperCase() : '?';
    final preview = conv.ultimoEsMio
        ? 'T\u00fa: ${conv.ultimoMensaje}'
        : conv.ultimoMensaje;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _abrirChat(conv),
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
                        colors: _paletaAvatares[
                            conv.nombre.hashCode.abs() % _paletaAvatares.length],
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
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        color: conv.online
                            ? const Color(0xFF4CD964)
                            : Colors.grey[400],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
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
                        if (conv.verificado) ...[
                          const Icon(Icons.verified,
                              color: Colors.blueAccent, size: 15),
                          const SizedBox(width: 3),
                        ],
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  conv.edad != null
                                      ? '${conv.nombre}, ${conv.edad}'
                                      : conv.nombre,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              if (conv.esMatch || conv.esMeGusta) ...[
                                const SizedBox(width: 4),
                                conv.esMatch
                                    ? const Icon(Icons.whatshot,
                                        color: Colors.orangeAccent, size: 16)
                                    : const Icon(Icons.favorite,
                                        color: Colors.redAccent, size: 15),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          _formatoHora(conv.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: conv.noLeidos > 0
                                ? _colorAvatar(conv.nombre)
                                : Colors.grey[400],
                            fontWeight:
                                conv.noLeidos > 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: conv.noLeidos > 0
                                  ? Colors.black87
                                  : Colors.grey[500],
                              fontWeight: conv.noLeidos > 0
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (conv.noLeidos > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _colorAvatar(conv.nombre),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${conv.noLeidos}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
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
              child: Icon(Icons.chat_bubble_outline,
                  size: 44, color: Colors.grey[400]),
            ),
            const SizedBox(height: 20),
            const Text(
              'No hay conversaciones todav\u00eda',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Cuando hagas match con alguien, la conversaci\u00f3n aparecer\u00e1 aqu\u00ed.',
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
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
                  ShimmerCaja(width: 120, height: 14),
                  SizedBox(height: 8),
                  ShimmerCaja(width: 200, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
