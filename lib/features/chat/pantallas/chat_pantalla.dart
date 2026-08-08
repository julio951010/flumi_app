import 'package:flutter/material.dart';
import '../../../core/base_datos_local/database.dart';
import '../../../core/estilos/tema.dart';
import '../../../widgets_comunes/shimmer_caja.dart';
import '../../encuentros/pantallas/cerca_de_ti_pantalla.dart';
import '../chat_repositorio.dart';

class ChatPantalla extends StatefulWidget {
  final ChatRepositorio repositorio;
  final String otroUsuarioId;
  final String miId;
  final String nombreOtro;
  final bool online;
  final bool esMeGusta;
  final bool esMatch;

  const ChatPantalla({
    super.key,
    required this.repositorio,
    required this.otroUsuarioId,
    required this.miId,
    this.nombreOtro = '',
    this.online = false,
    this.esMeGusta = false,
    this.esMatch = false,
  });

  @override
  State<ChatPantalla> createState() => _ChatPantallaState();
}

class _ChatPantallaState extends State<ChatPantalla> {
  static const _paletaAvatares = [
    [Color(0xFF6C63FF), Color(0xFFFF6584)],
    [Color(0xFF4ECDC4), Color(0xFF2ecc71)],
    [Color(0xFF667eea), Color(0xFF764ba2)],
    [Color(0xFFf093fb), Color(0xFFf5576c)],
    [Color(0xFF3AA5ED), Color(0xFF7B2CBF)],
  ];

  final _mensajeCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _alFondo = true;
  DateTime? _marcadoHasta;
  Usuario? _usuario;

  @override
  void initState() {
    super.initState();
    widget.repositorio.suscribirseARealtime(widget.miId);
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.repositorio
            .marcarConversacionLeida(widget.otroUsuarioId, widget.miId);
      }
    });
    widget.repositorio.obtenerUsuario(widget.otroUsuarioId).then((u) {
      if (mounted) setState(() => _usuario = u);
    });
  }

  void _abrirPerfil() {
    final u = _usuario;
    if (u == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PerfilDetallePage(
          usuario: u,
          esMatch: widget.esMatch,
          esMeGusta: widget.esMeGusta,
        ),
      ),
    );
  }

  Future<void> _abrirMenu() async {
    final opcion = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.black87),
              title: const Text('Reportar este perfil',
                  style: TextStyle(fontSize: 15)),
              onTap: () => Navigator.pop(ctx, 'reportar'),
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.redAccent),
              title: const Text('Bloquear Usuario',
                  style: TextStyle(fontSize: 15, color: Colors.redAccent)),
              onTap: () => Navigator.pop(ctx, 'bloquear'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || opcion == null) return;
    final mensaje = opcion == 'reportar'
        ? 'Reporte enviado. \u00a1Gracias por ayudarnos!'
        : 'Usuario bloqueado';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    widget.repositorio.cancelarRealtime();
    _mensajeCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final cerca = _scrollCtrl.position.maxScrollExtent - _scrollCtrl.offset < 120;
    if (cerca != _alFondo) setState(() => _alFondo = cerca);
  }

  Future<void> _enviar() async {
    final texto = _mensajeCtrl.text.trim();
    if (texto.isEmpty) return;
    _mensajeCtrl.clear();
    await widget.repositorio.enviarMensaje(
      emisorId: widget.miId,
      receptorId: widget.otroUsuarioId,
      contenido: texto,
    );
  }

  String _formatoHora(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            const Divider(height: 1, color: Colors.grey),
            Expanded(
              child: StreamBuilder<List<Mensaje>>(
                stream: widget.repositorio.observarConversacion(
                  widget.otroUsuarioId, widget.miId,
                ),
                builder: (context, snapshot) {
                  final mensajes = snapshot.data;
                  if (mensajes == null) return _esqueleto();
                  if (mensajes.isEmpty) return _vacio();
                  _marcarLeidoSiNuevo(mensajes);
                  _irAlFondo();
                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: mensajes.length,
                    itemBuilder: (context, index) =>
                        _burbuja(mensajes[index]),
                  );
                },
              ),
            ),
            _campoEntrada(),
          ],
        ),
      ),
    );
  }

  void _marcarLeidoSiNuevo(List<Mensaje> mensajes) {
    if (mensajes.isEmpty) return;
    final ultimo = mensajes.last.timestamp;
    if (_marcadoHasta != null && !ultimo.isAfter(_marcadoHasta!)) return;
    _marcadoHasta = ultimo;
    widget.repositorio
        .marcarConversacionLeida(widget.otroUsuarioId, widget.miId);
  }

  void _irAlFondo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients || !_alFondo) return;
      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    });
  }

  Widget _header() {
    final nombre = widget.nombreOtro;
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.black87, size: 22),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _abrirPerfil,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _paletaAvatares[
                          nombre.hashCode.abs() % _paletaAvatares.length],
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
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: widget.online
                          ? const Color(0xFF4CD964)
                          : Colors.grey[400],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: _abrirPerfil,
              child: Row(
                children: [
                  if (_usuario?.verificadoStatus ?? false) ...[
                    const Icon(Icons.verified,
                        color: Colors.blueAccent, size: 18),
                    const SizedBox(width: 3),
                  ],
                  Flexible(
                    child: Text(
                      _usuario != null
                          ? '${_usuario!.nombre}, ${_usuario!.edad}'
                          : widget.nombreOtro,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  if (widget.esMatch || widget.esMeGusta) ...[
                    const SizedBox(width: 5),
                    widget.esMatch
                        ? const Icon(Icons.whatshot,
                            color: Colors.orangeAccent, size: 18)
                        : const Icon(Icons.favorite,
                            color: Colors.redAccent, size: 17),
                  ],
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: _abrirMenu,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.more_horiz, color: Colors.black87, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _burbuja(Mensaje msg) {
    final esMio = msg.emisorId == widget.miId;
    return Align(
      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: esMio ? FlumiTema.colorPrimario : Colors.grey[100],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(esMio ? 16 : 4),
            bottomRight: Radius.circular(esMio ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              msg.contenido,
              style: TextStyle(
                fontSize: 15,
                height: 1.3,
                color: esMio ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatoHora(msg.timestamp),
              style: TextStyle(
                fontSize: 11,
                color: esMio
                    ? Colors.white.withValues(alpha: 0.75)
                    : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campoEntrada() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _mensajeCtrl,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _enviar(),
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _enviar,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: FlumiTema.colorPrimario,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vacio() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 44, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            'Todav\u00eda no hay mensajes',
            style: TextStyle(color: Colors.grey[500], fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'Saluda a ${widget.nombreOtro} \u2014 \u00a1El primer paso!',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _esqueleto() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, index) {
        final izquierda = index.isEven;
        return Align(
          alignment:
              izquierda ? Alignment.centerLeft : Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ShimmerCaja(width: izquierda ? 160 : 110, height: 14),
          ),
        );
      },
    );
  }
}
