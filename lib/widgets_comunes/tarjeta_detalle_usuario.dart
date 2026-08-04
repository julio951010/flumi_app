import 'package:flutter/material.dart';
import '../core/base_datos_local/database.dart';
import '../core/estilos/tema.dart';
import 'barra_progreso_rio.dart';

class TarjetaDetalleUsuario extends StatefulWidget {
  final Usuario usuario;
  final VoidCallback? onRechazar;
  final VoidCallback? onChat;
  final VoidCallback? onMeGusta;
  final bool mostrarProgreso;
  final ValueChanged<int>? onFotoCambio;
  final bool gusta;
  final bool esMatch;
  final bool esMeGusta;
  const TarjetaDetalleUsuario({
    super.key,
    required this.usuario,
    this.onRechazar,
    this.onChat,
    this.onMeGusta,
    this.mostrarProgreso = true,
    this.onFotoCambio,
    this.gusta = false,
    this.esMatch = false,
    this.esMeGusta = false,
  });

  @override
  State<TarjetaDetalleUsuario> createState() => _TarjetaDetalleUsuarioState();
}

class _TarjetaDetalleUsuarioState extends State<TarjetaDetalleUsuario> {
  static const _fotosMock = 4;

  static const _mockGradientes = [
    [Color(0xFF6C63FF), Color(0xFFFF6584)],
    [Color(0xFF4ECDC4), Color(0xFF2ecc71)],
    [Color(0xFF667eea), Color(0xFF764ba2)],
    [Color(0xFFf093fb), Color(0xFFf5576c)],
  ];

  int _fotoActual = 0;
  bool _scrolled = false;
  late final ScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    final scrolled = _scrollCtrl.hasClients ? _scrollCtrl.offset > 2 : false;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
  }

  @override
  void didUpdateWidget(TarjetaDetalleUsuario old) {
    super.didUpdateWidget(old);
    if (widget.usuario.uuid != old.usuario.uuid) {
      _fotoActual = 0;
      if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _fotoAnterior() {
    if (_fotoActual > 0) {
      setState(() => _fotoActual--);
      widget.onFotoCambio?.call(_fotoActual);
    }
  }

  void _fotoSiguiente() {
    if (_fotoActual < _fotosMock - 1) {
      setState(() => _fotoActual++);
      widget.onFotoCambio?.call(_fotoActual);
    }
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
              leading: const Icon(Icons.block, color: Colors.black87),
              title: const Text('Bloquear Usuario',
                  style: TextStyle(fontSize: 15)),
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
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.mostrarProgreso)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
            child: BarraProgresoRio(
              progreso: (_fotoActual + 1) / _fotosMock,
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final altoTarjeta = constraints.maxHeight;
              return Container(
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 8))
                  ],
                ),
                child: Stack(
                  children: [
                    ScrollbarTheme(
                      data: ScrollbarThemeData(
                        thumbColor: WidgetStatePropertyAll(
                            Colors.grey.withValues(alpha: 0.6)),
                        thickness: const WidgetStatePropertyAll(4),
                        radius: const Radius.circular(2),
                      ),
                      child: Scrollbar(
                        controller: _scrollCtrl,
                        child: SingleChildScrollView(
                          controller: _scrollCtrl,
                          child: Column(
                            children: [
                              SizedBox(
                                height: altoTarjeta,
                                child: Stack(
                                  children: [
                                    _buildFoto(),
                                    Positioned.fill(child: _buildTapZones()),
                                  ],
                                ),
                              ),
                              _buildExtendedContent(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 140,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.6),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 20,
                      left: 16,
                      right: 16,
                      child: IgnorePointer(
                        child: _buildInfoOverlay(),
                      ),
                    ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: GestureDetector(
                        onTap: _abrirMenu,
                        child: const Icon(Icons.more_horiz,
                            color: Colors.white, size: 40),
                      ),
                    ),
                    _buildBarraAcciones(),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBarraAcciones() {
    final tamano = _scrolled ? 52.0 : 64.0;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.65)],
          ),
        ),
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _fabCircular(
                icon: Icons.close,
                color: const Color(0xFFCCCCCC),
                size: tamano,
                onTap: widget.onRechazar,
              ),
              const SizedBox(width: 28),
              _fabCircular(
                icon: Icons.chat_bubble_outline,
                color: const Color(0xFF7B2CBF),
                size: tamano,
                onTap: widget.onChat,
              ),
              if (!widget.gusta && !widget.esMeGusta && !widget.esMatch) ...[
                const SizedBox(width: 28),
                _fabCircular(
                  icon: Icons.favorite,
                  color: FlumiTema.colorPrimario,
                  size: tamano,
                  onTap: widget.onMeGusta,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _fabCircular({
    required IconData icon,
    required Color color,
    required double size,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Icon(icon, color: color, size: size * 0.46),
      ),
    );
  }

  Widget _buildFoto() {
    final colores = _mockGradientes[_fotoActual % _mockGradientes.length];
    final inicial = widget.usuario.nombre.isNotEmpty
        ? widget.usuario.nombre[0].toUpperCase()
        : '?';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colores[0], colores[1]],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(inicial,
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width * 0.5,
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.bold,
            )),
      ),
    );
  }

  Widget _buildTapZones() {
    return Row(
      children: [
        Expanded(flex: 35, child: GestureDetector(onTap: _fotoAnterior)),
        Expanded(flex: 30, child: GestureDetector()),
        Expanded(flex: 35, child: GestureDetector(onTap: _fotoSiguiente)),
      ],
    );
  }

  Widget _buildInfoOverlay() {
    final u = widget.usuario;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (u.verificadoStatus)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.verified, color: Colors.blueAccent, size: 22),
              ),
            Flexible(
              child: Text(
                '${u.nombre}, ${u.edad}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black45)],
                ),
              ),
            ),
            if (widget.esMatch) ...[
              const SizedBox(width: 8),
              const Icon(Icons.whatshot, color: Colors.orangeAccent, size: 22),
            ] else if (widget.esMeGusta || widget.gusta) ...[
              const SizedBox(width: 6),
              const Icon(Icons.favorite, color: Colors.redAccent, size: 20),
            ],
            if (u.ultimaSincronizacionTimestamp != null) ...[
              const SizedBox(width: 8),
              Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  color: Color(0xFF4CD964),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
        AnimatedOpacity(
          opacity: _scrolled ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: _scrolled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 6),
                _buildQueBuscaBadge(u),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 13, color: Colors.white.withValues(alpha: 0.9)),
                      const SizedBox(width: 4),
                      Text('A pocos km',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.9))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQueBuscaBadge(Usuario u) {
    final map = <String, String>{
      'relacion': 'Relaci\u00f3n seria',
      'casual': 'Algo casual',
      'amistad': 'Amistad',
      'chatear': 'Chatear',
    };
    final texto = map[u.queBusca.toLowerCase()] ?? u.queBusca;
    if (texto.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.favorite, size: 14, color: Colors.black87),
          const SizedBox(width: 5),
          Text(texto,
              style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildExtendedContent() {
    final u = widget.usuario;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 170),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 16),
          if (u.biografia.isNotEmpty) ...[
            const _SeccionTitulo('Sobre m\u00ed'),
            const SizedBox(height: 6),
            Text(u.biografia,
                style: TextStyle(
                    fontSize: 15, color: Colors.grey[700], height: 1.4)),
            const SizedBox(height: 20),
          ],
          _buildIntencion(u),
          const SizedBox(height: 20),
          _buildIntereses(u),
          const SizedBox(height: 20),
          _buildPrompts(u),
          const SizedBox(height: 20),
          _buildVerificacion(u),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildIntencion(Usuario u) {
    final map = <String, String>{
      'relacion': 'Relaci\u00f3n seria',
      'casual': 'Algo casual',
      'amistad': 'Amistad',
      'chatear': 'Chatear',
    };
    final texto = map[u.queBusca.toLowerCase()] ?? u.queBusca;
    if (texto.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SeccionTitulo('Qu\u00e9 busco'),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: FlumiTema.colorPrimario.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.favorite,
                  size: 14, color: FlumiTema.colorPrimario),
              const SizedBox(width: 6),
              Text(texto,
                  style: const TextStyle(
                      fontSize: 13,
                      color: FlumiTema.colorPrimario,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntereses(Usuario u) {
    final intereses = u.intereses.isNotEmpty
        ? u.intereses
        : ['F\u00fatbol', 'Caf\u00e9', 'Viajes', 'M\u00fasica', 'Cine'];
    if (intereses.isEmpty) return const SizedBox.shrink();

    const emojis = {
      'F\u00fatbol': '\u26bd',
      'Caf\u00e9': '\u2615',
      'Viajes': '\u2708\ufe0f',
      'M\u00fasica': '\ud83c\udfb5',
      'Cine': '\ud83c\udfac',
      'Libros': '\ud83d\udcda',
      'Yoga': '\ud83e\uddd8',
      'Fotograf\u00eda': '\ud83d\udcf7',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SeccionTitulo('Intereses'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: intereses.map((i) {
            final emoji = emojis[i] ?? '';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: FlumiTema.colorPrimario.withValues(alpha: 0.06),
                border: Border.all(
                    color: FlumiTema.colorPrimario.withValues(alpha: 0.15)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$emoji $i',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700])),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPrompts(Usuario u) {
    const prompts = [
      'Mi domingo ideal es\u2026 \u2014 No hacer nada y ver series',
      'Un dato curioso\u2026 \u2014 Aprend\u00ed a tocar guitarra en un mes',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SeccionTitulo('Preguntas r\u00e1pidas'),
        const SizedBox(height: 8),
        ...prompts.map((p) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(p,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey[700], height: 1.3)),
            )),
      ],
    );
  }

  Widget _buildVerificacion(Usuario u) {
    final items = <_ItemVerificacion>[
      _ItemVerificacion('Foto verificada', u.verificadoStatus),
      _ItemVerificacion('Tel\u00e9fono verificado', u.verificadoStatus),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SeccionTitulo('Verificaci\u00f3n'),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    item.verificado
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: item.verificado ? Colors.green : Colors.grey[400],
                  ),
                  const SizedBox(width: 8),
                  Text(item.label,
                      style: TextStyle(
                          fontSize: 13,
                          color: item.verificado
                              ? Colors.green[700]
                              : Colors.grey[500])),
                ],
              ),
            )),
        const SizedBox(height: 4),
        Text('La cuenta fue creada hace m\u00e1s de 3 meses',
            style: TextStyle(fontSize: 12, color: Colors.grey[400])),
      ],
    );
  }
}

class _SeccionTitulo extends StatelessWidget {
  final String texto;
  const _SeccionTitulo(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(texto,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87));
  }
}

class _ItemVerificacion {
  final String label;
  final bool verificado;
  const _ItemVerificacion(this.label, this.verificado);
}
