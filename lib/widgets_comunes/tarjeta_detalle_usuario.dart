import 'dart:io';
import 'package:flutter/material.dart';
import '../core/base_datos_local/database.dart';
import '../core/estilos/tema.dart';
import '../features/perfiles/perfil_etiquetas.dart';
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
  final bool soloVista;
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
    this.soloVista = false,
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

  List<String> get _fotos {
    final fotos = widget.usuario.fotosLocalesRutas;
    return fotos.isEmpty ? const [] : fotos;
  }

  int get _totalFotos => _fotos.isEmpty ? _fotosMock : _fotos.length;

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
    if (_fotoActual < _totalFotos - 1) {
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
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.mostrarProgreso)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
            child: BarraProgresoRio(
              progreso: (_fotoActual + 1) / _totalFotos,
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
                        onTap: widget.soloVista ? null : _abrirMenu,
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
              _fabImage(
                asset: 'assets/icons/close.png',
                size: tamano,
                onTap: widget.soloVista ? null : widget.onRechazar,
              ),
              const SizedBox(width: 28),
              _fabImage(
                asset: 'assets/icons/chat.png',
                size: tamano,
                onTap: widget.soloVista ? null : widget.onChat,
              ),
              if (widget.soloVista ||
                  (!widget.gusta && !widget.esMeGusta && !widget.esMatch)) ...[
                const SizedBox(width: 28),
                _fabImage(
                  asset: 'assets/icons/heart.png',
                  size: tamano,
                  onTap: widget.soloVista ? null : widget.onMeGusta,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _fabImage({
    required String asset,
    required double size,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 4,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Image.asset(
            asset,
            width: size * 0.8,  // Cambia de 0.5 a 0.7 para hacerla más grande
            height: size * 0.8,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildFoto() {
    if (_fotos.isNotEmpty &&
        File(_fotos[_fotoActual % _fotos.length]).existsSync()) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Image.file(
          File(_fotos[_fotoActual % _fotos.length]),
          key: ValueKey(_fotoActual),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }
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
                if (u.ciudad.trim().isNotEmpty) ...[
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
                        Icon(Icons.location_on,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.9)),
                        const SizedBox(width: 4),
                        Text(u.ciudad,
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.9))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQueBuscaBadge(Usuario u) {
    final texto = opcionTexto(opcionesQueBusca, u.queBusca);
    if (texto.isEmpty || texto == 'Sin definir') return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
    final secciones = <Widget>[
      _seccionDetalle('Informaci\u00f3n b\u00e1sica', [
        _pillIconoValor(Icons.face, valorTexto(capitalizar(u.genero))),
        _pillIconoValor(Icons.location_on, valorTexto(u.ciudad)),
      ]),
      if (u.biografia.trim().isNotEmpty) ...[
        const _SeccionTitulo('Sobre m\u00ed'),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(u.biografia,
              style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  height: 1.4,
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 20),
      ],
      _seccionDetalle('Qu\u00e9 buscas', [
        _pill(null, opcionTexto(opcionesQueBusca, u.queBusca)),
        _pillBuscaRango(u),
      ]),
      _seccionDetalle('Vida personal y creencias', [
        _pillIconoValor(Icons.favorite, orientacionTexto(u.orientacionSexual)),
        _pill(null, situacionTexto(u.situacionSentimental)),
        _pillIconoValor(Icons.child_care, hijosTexto(u.hijos)),
        _pill(null, religionTexto(u.religion)),
      ]),
      _seccionDetalle('Trabajo y formaci\u00f3n', [
        _pillIconoValor(Icons.school, educacionTexto(u.educacion)),
        _pillIconoValor(Icons.badge, valorTexto(u.profesion)),
        _pillIconoValor(Icons.work, trabajoTexto(u.trabajo)),
      ]),
      _seccionDetalle('H\u00e1bitos y estilo de vida', [
        _pill(null, tabacoTexto(u.fuma)),
        _pill(null, alcoholTexto(u.bebe)),
        _pillIconoValor(Icons.pets, mascotasTexto(u.mascotas)),
        _pillIconoValor(Icons.colorize, tatuajesTexto(u.tatuajes)),
      ]),
      _seccionDetalle('Personalidad y rasgos', [
        for (final p in listaPersonalidad(u.personalidad))
          _pill(Icons.psychology, p),
        _pillIconoValor(Icons.height, alturaTexto(u.altura)),
        _pill(null, signoTexto(u.signoZodiaco)),
      ]),
      _seccionDetalle('Idiomas que hablas', [
        for (final idioma in u.idiomas.split(','))
          if (idioma.trim().isNotEmpty) _pill(Icons.translate, idioma.trim()),
      ]),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          ...secciones,
          _buildIntereses(u),
          const SizedBox(height: 20),
          _buildPreguntas(u),
          const SizedBox(height: 20),
          _buildVerificacion(u),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _pillIconoValor(IconData icono, String valor) {
    if (valor == 'Sin definir' || valor.isEmpty) return const SizedBox.shrink();
    return _pill(icono, valor);
  }

  Widget _pillBuscaRango(Usuario u) {
    final conocer = buscaGeneroTexto(u.buscaGenero);
    final rango = rangoEdadTexto(u.preferenciaEdadMin, u.preferenciaEdadMax);
    if (conocer.isEmpty || conocer == 'Sin definir') {
      return const SizedBox.shrink();
    }
    final rangoParte =
        (rango.isEmpty || rango == 'Sin definir') ? '' : ' de $rango';
    return _pill(Icons.people, 'Tengo inter\u00e9s en $conocer$rangoParte');
  }

  Widget _pill(IconData? icono, String texto) {
    if (texto == 'Sin definir' || texto.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 16, color: Colors.black87),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(texto,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _seccionDetalle(String titulo, List<Widget> pills) {
    final visibles = pills.where((f) => f is! SizedBox).toList();
    if (visibles.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SeccionTitulo(titulo),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: visibles,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildIntereses(Usuario u) {
    final intereses = u.intereses;
    if (intereses.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SeccionTitulo('Intereses'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: intereses.map((i) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: FlumiTema.colorPrimario.withValues(alpha: 0.06) ,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(i,
                  style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600)),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPreguntas(Usuario u) {
    final preguntas = u.preguntasPerfil;
    if (preguntas.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SeccionTitulo('Preguntas del perfil'),
        const SizedBox(height: 8),
        ...preguntas.map((p) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.pregunta,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[700])),
                  const SizedBox(height: 4),
                  Text(p.respuesta,
                      style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          height: 1.3,
                          fontWeight: FontWeight.w600)),
                ],
              ),
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
                    size: 20,
                    color: item.verificado ? Colors.green : Colors.grey[400],
                  ),
                  const SizedBox(width: 8),
                  Text(item.label,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: item.verificado
                              ? Colors.green[700]
                              : Colors.grey[500])),
                ],
              ),
            )),
        const SizedBox(height: 4),
        Text('La cuenta fue creada hace m\u00e1s de 3 meses',
            style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
                fontWeight: FontWeight.w500)),
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
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[500]));
  }
}

class _ItemVerificacion {
  final String label;
  final bool verificado;
  const _ItemVerificacion(this.label, this.verificado);
}
