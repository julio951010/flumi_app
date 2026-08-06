import 'package:flutter/material.dart';
import 'package:swipe_cards/swipe_cards.dart';
import '../../../core/api/mock_data.dart';
import '../../../core/base_datos_local/database.dart';
import '../../../core/estilos/tema.dart';
import '../../../widgets_comunes/barra_progreso_rio.dart';
import '../../../widgets_comunes/shimmer_caja.dart';
import '../../../widgets_comunes/tarjeta_detalle_usuario.dart';
import '../../chat/chat_repositorio.dart';
import '../../chat/pantallas/chat_pantalla.dart';
import 'filtros_encuentros_sheet.dart';

class EncuentrosPantalla extends StatefulWidget {
  final AppDatabase db;
  final String miId;
  final FiltrosEncuentros filtros;
  final ValueNotifier<int> undoSignal;

  const EncuentrosPantalla({
    super.key,
    required this.db,
    required this.miId,
    required this.filtros,
    required this.undoSignal,
  });

  @override
  State<EncuentrosPantalla> createState() => _EncuentrosPantallaState();
}

class _EncuentrosPantallaState extends State<EncuentrosPantalla> {
  List<Usuario> _usuarios = [];
  List<Usuario> _filtrados = [];
  Set<String> _idsGustados = {};
  Set<String> _idsRecibidos = {};
  bool _cargando = true;
  int _progresoFoto = 0;
  int _motorBase = 0;
  bool _agotado = false;
  int _motorId = 0;
  MatchEngine? _matchEngine;
  late final ChatRepositorio _chatRepo = ChatRepositorio(widget.db);

  @override
  void initState() {
    super.initState();
    widget.undoSignal.addListener(_undo);
    _cargar();
  }

  @override
  void dispose() {
    _matchEngine?.removeListener(_alCambiarCarta);
    widget.undoSignal.removeListener(_undo);
    super.dispose();
  }

  void _alCambiarCarta() {
    if (mounted) {
      setState(() {
        _progresoFoto = 0;
      });
    }
  }

  void _undo() {
    final engine = _matchEngine;
    if (engine == null) return;
    if (_agotado) {
      if (_filtrados.isEmpty) return;
      setState(() {
        _agotado = false;
        _motorBase = _filtrados.length - 1;
        _progresoFoto = 0;
        _motorId++;
        _matchEngine = MatchEngine(
          swipeItems: [
            for (final u in _filtrados.sublist(_motorBase))
              SwipeItem(content: u, superlikeAction: () => _abrirChat(u)),
          ],
        )..addListener(_alCambiarCarta);
      });
    } else if (engine.currentItem != null) {
      engine.rewindMatch();
      setState(() => _progresoFoto = 0);
    }
  }

  @override
  void didUpdateWidget(EncuentrosPantalla old) {
    super.didUpdateWidget(old);
    if (widget.filtros != old.filtros) {
      _aplicarFiltros();
    }
  }

  Future<void> _cargar() async {
    try {
      final todos = await (widget.db.select(widget.db.usuarios)).get();
      todos.removeWhere((u) => u.uuid == widget.miId);
      if (mounted) {
        setState(() {
          _usuarios = todos;
          _idsGustados =
              GeneradorMock.obtenerMisLikes().map((i) => i.usuarioId).toSet();
          _idsRecibidos = GeneradorMock.obtenerLikesRecibidos()
              .map((i) => i.usuarioId)
              .toSet();
          _cargando = false;
        });
        _aplicarFiltros();
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _aplicarFiltros() {
    final f = widget.filtros;
    var lista = List<Usuario>.from(_usuarios);

    if (f.generoFiltro.isNotEmpty) {
      final generoDestino = f.generoFiltro.toLowerCase();
      lista.removeWhere((u) => !u.genero.toLowerCase().contains(generoDestino));
    }

    lista.removeWhere(
        (u) => u.edad < f.edadRango.start.toInt() || u.edad > f.edadRango.end.toInt());

    if (f.enLineaAhora) {
      lista.removeWhere((u) => u.ultimaSincronizacionTimestamp == null);
    }

    lista.removeWhere((u) => _idsGustados.contains(u.uuid));

    setState(() {
      _filtrados = lista;
      _motorBase = 0;
      _agotado = false;
      _progresoFoto = 0;
      _motorId++;
      _matchEngine = MatchEngine(
        swipeItems: [for (final u in lista) SwipeItem(content: u, superlikeAction: () => _abrirChat(u))],
      )..addListener(_alCambiarCarta);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: _cuerpo(),
    );
  }

  Widget _cuerpo() {
    if (_cargando) return _esqueleto();
    if (_filtrados.isEmpty || _agotado) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No hay m\u00e1s perfiles',
                style: TextStyle(fontSize: 18, color: Colors.grey[500])),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() => _cargando = true);
                _cargar();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: FlumiTema.colorPrimario,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
                minimumSize: const Size(200, 48),
              ),
              child: const Text('Recargar'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: BarraProgresoRio(
            progreso: (_progresoFoto + 1) / 4,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            child: SwipeCards(
              key: ValueKey(_motorId),
              matchEngine: _matchEngine!,
              itemBuilder: (context, index) =>
                  _tarjeta(_filtrados[_motorBase + index]),
              onStackFinished: () => setState(() => _agotado = true),
              upSwipeAllowed: true,
              fillSpace: true,
              likeTag: _badgeSwipe(Icons.check, Colors.greenAccent),
              nopeTag: _badgeSwipe(Icons.close, Colors.red),
              superLikeTag: _badgeSwipe(Icons.chat_bubble, FlumiTema.colorPrimario),
              likeGradient: _overlaySwipe(Colors.green),
              nopeGradient: _overlaySwipe(Colors.red),
              superLikeGradient: _overlaySwipe(Colors.blueAccent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tarjeta(Usuario usuario) {
    final gustado = _idsGustados.contains(usuario.uuid);
    return TarjetaDetalleUsuario(
      usuario: usuario,
      onRechazar: () => _matchEngine?.currentItem?.nope(),
      onChat: () {},
      onMeGusta: () => _matchEngine?.currentItem?.like(),
      mostrarProgreso: false,
      onFotoCambio: (i) => setState(() => _progresoFoto = i),
      esMatch: gustado && _idsRecibidos.contains(usuario.uuid),
      esMeGusta: gustado,
    );
  }

  void _abrirChat(Usuario usuario) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPantalla(
          repositorio: _chatRepo,
          otroUsuarioId: usuario.uuid,
          miId: widget.miId,
          nombreOtro: usuario.nombre,
          online: usuario.ultimaSincronizacionTimestamp != null,
        ),
      ),
    );
  }

  Widget _badgeSwipe(IconData icono, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3),
        color: Colors.white.withValues(alpha: 0.95),
      ),
      child: Icon(icono, color: color, size: 26),
    );
  }

  Widget _overlaySwipe(Color color) {
    return Container(
      color: color.withValues(alpha: 0.35),
    );
  }

  Widget _esqueleto() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: const Column(
          children: [
            Expanded(
              flex: 7,
              child: ShimmerCaja(radius: 0),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerCaja(width: 200, height: 22),
                    SizedBox(height: 12),
                    ShimmerCaja(width: 100, height: 16),
                    SizedBox(height: 12),
                    ShimmerCaja(width: double.infinity, height: 14),
                    SizedBox(height: 6),
                    ShimmerCaja(width: 160, height: 14),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
