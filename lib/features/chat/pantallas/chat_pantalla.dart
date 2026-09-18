import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/base_datos_local/database.dart';
import '../../../core/constantes/constantes.dart';
import '../../../core/estilos/tema.dart';
import '../../../core/servicios/suscripcion_servicio.dart';
import '../../../core/servicios/notificacion_servicio.dart';
import '../../../widgets_comunes/avatar_usuario.dart';
import '../../../widgets_comunes/shimmer_caja.dart';
import '../chat_repositorio.dart';
import '../../encuentros/pantallas/cerca_de_ti_pantalla.dart';

/// IDs de los perfiles de sistema (Administrador / Flumi). Las conversaciones
/// con ellos son de solo lectura para el usuario: solo recibe mensajes.
final Set<String> _idsConversacionOficial = cuentasOficialesFlumi.keys.toSet();

class ChatPantalla extends StatefulWidget {
  final ChatRepositorio repositorio;
  final String otroUsuarioId;
  final String miId;
  final String nombreOtro;
  final bool online;
  final bool esMeGusta;
  final bool esMatch;
  final SuscripcionServicio suscripcionServicio;

  const ChatPantalla({
    super.key,
    required this.repositorio,
    required this.otroUsuarioId,
    required this.miId,
    this.nombreOtro = '',
    this.online = false,
    this.esMeGusta = false,
    this.esMatch = false,
    required this.suscripcionServicio,
  });

  @override
  State<ChatPantalla> createState() => _ChatPantallaState();
}

class _ChatPantallaState extends State<ChatPantalla> {
  static const _motivosReporte = [
    'Comportamiento inapropiado',
    'Spam',
    'Fotos falsas',
    'Menor de edad',
    'Otro',
  ];

  static const _emojis = [
    '😀', '😁', '😂', '🤣', '😊', '😍', '😘', '😜', '🤪', '😎',
    '🤩', '🥳', '😢', '😭', '😡', '🥺', '😳', '😅', '🙃', '😴',
    '🤔', '🙄', '😏', '😇', '🥰', '😋', '🤗', '🤭', '😱', '😤',
    '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '💔', '💕', '💞',
    '💋', '🔥', '✨', '⭐', '🌹', '🌚', '🍕', '🍺', '☕', '🎉',
    '👍', '👎', '👏', '🙏', '👌', '✌️', '🤝', '💪', '🫶', '🤙',
    '🐶', '🐱', '🐸', '🦄', '🐻', '🌸', '🎈', '🎁', '⚽', '🎮',
  ];

  final _mensajeCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _alFondo = true;
  DateTime? _marcadoHasta;
  Usuario? _usuario;
  DateTime? _leidoHasta;
  StreamSubscription? _leidoSub;
  StreamSubscription<Usuario?>? _usuarioSub;
  bool _otroEscribiendo = false;
  StreamSubscription<bool>? _escribiendoSub;
  Timer? _timerEscribiendo;
  bool _enviandoEscribiendo = false;
  bool _panelEmojisAbierto = false;

  // Paginación: la lista llega completa por el watch; se renderizan los
  // últimos [_visibles] mensajes (lista invertida) y se amplían al hacer
  // scroll hasta arriba.
  static const _tamPagina = 60;
  int _visibles = _tamPagina;
  bool _cargandoMas = false;
  int _totalMensajes = 0;

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
    _usuarioSub = widget.repositorio.observarUsuario(widget.otroUsuarioId).listen((u) {
      if (mounted) setState(() => _usuario = u);
    });
    _leidoSub = widget.repositorio
        .observarLeidoHasta(widget.otroUsuarioId, widget.miId)
        .listen((leido) {
      if (mounted) setState(() => _leidoHasta = leido);
    });
    _escribiendoSub = widget.repositorio
        .observarEscribiendo(widget.otroUsuarioId, widget.miId)
        .listen((escribiendo) {
      if (mounted) setState(() => _otroEscribiendo = escribiendo);
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
          onChat: () => _abrirChatDirecto(),
        ),
      ),
    );
  }

  void _abrirChatDirecto() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPantalla(
          repositorio: widget.repositorio,
          otroUsuarioId: widget.otroUsuarioId,
          miId: widget.miId,
          nombreOtro: widget.nombreOtro,
          online: widget.online,
          esMeGusta: widget.esMeGusta,
          esMatch: widget.esMatch,
          suscripcionServicio: widget.suscripcionServicio,
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
              leading: const Icon(Icons.delete_outline, color: Colors.black87),
              title: const Text('Borrar conversación',
                  style: TextStyle(fontSize: 15, color: Colors.black87)),
              onTap: () => Navigator.pop(ctx, 'borrar'),
            ),
            if (!esCuentaOficial(widget.otroUsuarioId)) ...[
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
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || opcion == null) return;
    switch (opcion) {
      case 'borrar':
        await _borrarConversacion();
        break;
      case 'reportar':
        await _reportarPerfil();
        break;
      case 'bloquear':
        await _bloquearUsuario();
        break;
    }
  }

  Future<void> _borrarConversacion() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar conversación'),
        content: const Text(
            '¿Seguro que quieres borrar esta conversación? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await widget.repositorio
        .borrarConversacion(widget.otroUsuarioId, widget.miId);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _reportarPerfil() async {
    final motivo = await showModalBottomSheet<String>(
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '¿Por qué reportas a ${widget.nombreOtro}?',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ),
            for (final m in _motivosReporte)
              ListTile(
                title: Text(m, style: const TextStyle(fontSize: 15)),
                onTap: () => Navigator.pop(ctx, m),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (motivo == null || !mounted) return;
    await widget.repositorio.reportarUsuario(
      miId: widget.miId,
      otroId: widget.otroUsuarioId,
      motivo: motivo,
    );
    if (!mounted) return;
    _toast('Reporte enviado. \u00a1Gracias por ayudarnos!');
  }

  Future<void> _bloquearUsuario() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bloquear usuario'),
        content: Text(
            '¿Seguro que quieres bloquear a ${widget.nombreOtro}? No podrá volver a aparecer en tus resultados.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bloquear',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await widget.repositorio.bloquearUsuario(
      miId: widget.miId,
      otroId: widget.otroUsuarioId,
    );
    if (!mounted) return;
    _toast('Usuario bloqueado');
    Navigator.pop(context);
  }

  void _toast(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    widget.repositorio.cancelarRealtime();
    _timerEscribiendo?.cancel();
    if (_enviandoEscribiendo) {
      widget.repositorio.enviarEscribiendo(
        miId: widget.miId,
        otroUsuarioId: widget.otroUsuarioId,
        escribiendo: false,
      );
    }
    _leidoSub?.cancel();
    _usuarioSub?.cancel();
    _escribiendoSub?.cancel();
    widget.repositorio.cerrarEscribiendo(widget.otroUsuarioId, widget.miId);
    _mensajeCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final cerca = _scrollCtrl.offset < 120;
    if (cerca != _alFondo) setState(() => _alFondo = cerca);
    // Lista invertida: "arriba" = offset alto; al llegar al borde se cargan
    // mensajes más antiguos.
    if (_scrollCtrl.offset >
            _scrollCtrl.position.maxScrollExtent - 200 &&
        _visibles < _totalMensajes) {
      _cargarMas();
    }
  }

  void _cargarMas() {
    if (_cargandoMas) return;
    setState(() {
      _cargandoMas = true;
      _visibles += _tamPagina;
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _cargandoMas = false);
    });
  }

  Future<void> _enviar() async {
    if (!widget.suscripcionServicio.esGratis) {
      final texto = _mensajeCtrl.text.trim();
      if (texto.isEmpty) return;
      _mensajeCtrl.clear();
      _apagarEscribiendo();
      await widget.repositorio.enviarMensaje(
        emisorId: widget.miId,
        receptorId: widget.otroUsuarioId,
        contenido: texto,
      );
    } else {
      // Usuario en plan gratis: mostrar mensaje de upgrade
      if (mounted) {
        NotificacionServicio.advertencia(
          context,
          'Esta función requiere Flumi Plus o Premium. Actualiza tu plan para enviar mensajes.',
        );
      }
    }
  }

  void _alCambiarTexto(String texto) {
    final escribiendo = texto.trim().isNotEmpty;
    if (escribiendo != _enviandoEscribiendo) {
      _enviandoEscribiendo = escribiendo;
      widget.repositorio.enviarEscribiendo(
        miId: widget.miId,
        otroUsuarioId: widget.otroUsuarioId,
        escribiendo: escribiendo,
      );
    }
    _timerEscribiendo?.cancel();
    if (escribiendo) {
      _timerEscribiendo = Timer(const Duration(seconds: 3), () {
        if (mounted) _apagarEscribiendo();
      });
    }
  }

  void _apagarEscribiendo() {
    _timerEscribiendo?.cancel();
    if (!_enviandoEscribiendo) return;
    _enviandoEscribiendo = false;
    widget.repositorio.enviarEscribiendo(
      miId: widget.miId,
      otroUsuarioId: widget.otroUsuarioId,
      escribiendo: false,
    );
  }

  void _insertarEmoji(String emoji) {
    final texto = _mensajeCtrl.text;
    final sel = _mensajeCtrl.selection;
    final inicio = sel.isValid ? sel.start : texto.length;
    final fin = sel.isValid ? sel.end : texto.length;
    final nuevo = texto.replaceRange(inicio, fin, emoji);
    _mensajeCtrl.text = nuevo;
    _mensajeCtrl.selection =
        TextSelection.collapsed(offset: inicio + emoji.length);
    _alCambiarTexto(nuevo);
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
                  _marcarLeidoSiNuevo(mensajes);
                  _totalMensajes = mensajes.length;
                  if (mensajes.isEmpty) return _vacio();
                  _irAlFondo();
                  return _lista(mensajes);
                },
              ),
            ),
            if (_otroEscribiendo) _indicadorEscribiendo(),
            if (_panelEmojisAbierto) _panelEmojis(),
            _campoEntrada(),
          ],
        ),
      ),
    );
  }

  void _marcarLeidoSiNuevo(List<Mensaje> mensajes) {
    if (mensajes.isEmpty) return;
    final ultimo = mensajes.last;
    // No remarcar cuando el último mensaje es mío: la marca de leído de esta
    // conversación la escribe el OTRO usuario; así el tick "visto" refleja
    // sus lecturas, no las propias.
    if (ultimo.emisorId == widget.miId) return;
    if (_marcadoHasta != null && !ultimo.timestamp.isAfter(_marcadoHasta!)) return;
    _marcadoHasta = ultimo.timestamp;
    widget.repositorio
        .marcarConversacionLeida(widget.otroUsuarioId, widget.miId);
  }

  void _irAlFondo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients || !_alFondo) return;
      _scrollCtrl.jumpTo(0);
    });
  }

  Widget _lista(List<Mensaje> mensajes) {
    // Lista invertida (reverse: true): el índice 0 es el mensaje más reciente
    // (abajo); al cargar más antiguos no se mueve el scroll.
    final visibles = _visibles.clamp(1, mensajes.length);
    return ListView.builder(
      controller: _scrollCtrl,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      itemCount: visibles + (_visibles < mensajes.length ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == visibles) return _cargarMasCabecera();
        return _burbuja(mensajes[mensajes.length - 1 - index]);
      },
    );
  }

  Widget _cargarMasCabecera() {
    if (_cargandoMas) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Center(
        child: GestureDetector(
          onTap: _cargarMas,
          child: const Text(
            'Ver mensajes anteriores',
            style: TextStyle(
              color: FlumiTema.colorPrimario,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _indicadorEscribiendo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 1.6),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${widget.nombreOtro} está escribiendo...',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelEmojis() {
    return Container(
      height: 220,
      color: Colors.grey[50],
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Colors.grey[100],
            child: Text(
              'Emojis',
              style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 8,
              children: [
                for (final e in _emojis)
                  InkWell(
                    onTap: () => _insertarEmoji(e),
                    child: Center(
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Estado en línea en vivo (Realtime de profiles) con fallback al valor
  /// que trajo la lista al abrir el chat.
  bool get _online {
    final u = _usuario;
    return u != null ? ChatRepositorio.estaEnLinea(u) : widget.online;
  }

  Widget _header() {
    final nombre = widget.nombreOtro;
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
            child: AvatarUsuario(
              nombre: nombre,
              fotoUrl: fotosOficialesFlumi[widget.otroUsuarioId] ??
                  ((_usuario != null && _usuario!.fotosUrls.isNotEmpty)
                      ? _usuario!.fotosUrls.first
                      : null),
              size: 42,
              online: _online,
              radioPunto: 7,
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
              child: const Icon(Icons.more_vert, color: Colors.black87, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _burbuja(Mensaje msg) {
    final esMio = msg.emisorId == widget.miId;
    return GestureDetector(
      onLongPress: esMio ? () => _accionesMensaje(msg) : null,
      child: Align(
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatoHora(msg.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: esMio
                          ? Colors.white.withValues(alpha: 0.75)
                          : Colors.grey[400],
                    ),
                  ),
                  if (esMio) ...[
                    const SizedBox(width: 4),
                    _estadoEnvio(msg),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tick de estado de envío: enviando (reloj), enviado (✓), visto (✓✓),
  /// fallido (⚠ con reintento al tocar).
  Widget _estadoEnvio(Mensaje msg) {
    if (msg.estadoEnvio == 'fallido') {
      return GestureDetector(
        onTap: () {
          widget.repositorio.reintentarMensaje(uuid: msg.uuid);
          _toast('Reintentando envío...');
        },
        child: const Icon(Icons.error_outline, color: Colors.white, size: 13),
      );
    }
    if (msg.estadoEnvio == 'enviando') {
      return const Icon(Icons.schedule, color: Colors.white70, size: 13);
    }
    final visto =
        _leidoHasta != null && !msg.timestamp.isAfter(_leidoHasta!);
    return Icon(
      visto ? Icons.done_all : Icons.done,
      color: visto ? Colors.lightBlue.shade100 : Colors.white70,
      size: 14,
    );
  }

  Future<void> _accionesMensaje(Mensaje msg) async {
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
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                msg.contenido,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.black87),
              title: const Text('Editar mensaje',
                  style: TextStyle(fontSize: 15)),
              onTap: () => Navigator.pop(ctx, 'editar'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Eliminar mensaje',
                  style: TextStyle(fontSize: 15, color: Colors.redAccent)),
              onTap: () => Navigator.pop(ctx, 'eliminar'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || opcion == null) return;
    if (opcion == 'editar') {
      await _editarMensaje(msg);
    } else {
      await _eliminarMensaje(msg);
    }
  }

  Future<void> _editarMensaje(Mensaje msg) async {
    final ctrl = TextEditingController(text: msg.contenido);
    final nuevo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar mensaje'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Nuevo texto'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (nuevo == null || nuevo.isEmpty || !mounted) return;
    await widget.repositorio.editarMensaje(uuid: msg.uuid, contenido: nuevo);
  }

  Future<void> _eliminarMensaje(Mensaje msg) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar mensaje'),
        content: const Text('¿Seguro que quieres eliminar este mensaje?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await widget.repositorio.eliminarMensaje(uuid: msg.uuid);
  }

  Widget _campoEntrada() {
    if (_idsConversacionOficial.contains(widget.otroUsuarioId)) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Conversación oficial. Solo puedes recibir mensajes del equipo de Flumi.',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final bool esGratis = widget.suscripcionServicio.esGratis;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: esGratis
                ? null
                : () => setState(() {
                      _panelEmojisAbierto = !_panelEmojisAbierto;
                    }),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: esGratis
                    ? Colors.grey[100]
                    : (_panelEmojisAbierto
                        ? FlumiTema.colorPrimario.withValues(alpha: 0.12)
                        : Colors.grey[100]),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _panelEmojisAbierto
                    ? Icons.keyboard_alt_outlined
                    : Icons.emoji_emotions_outlined,
                color: esGratis
                    ? Colors.grey[400]
                    : (_panelEmojisAbierto
                        ? FlumiTema.colorPrimario
                        : Colors.black54),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 6),
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
                onChanged: _alCambiarTexto,
                onSubmitted: (_) => _enviar(),
                enabled: !esGratis,
                decoration: InputDecoration(
                  hintText: esGratis
                      ? 'Actualiza a Plus/Premium para enviar mensajes'
                      : 'Escribe un mensaje...',
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
            onTap: esGratis ? null : _enviar,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: esGratis ? Colors.grey[300] : FlumiTema.colorPrimario,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.send,
                color: esGratis ? Colors.grey[500] : Colors.white,
                size: 20,
              ),
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
