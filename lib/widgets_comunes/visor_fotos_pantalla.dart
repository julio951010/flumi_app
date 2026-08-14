import 'package:flutter/material.dart';

import 'foto_perfil.dart';

class VisorFotosPantalla extends StatefulWidget {
  final List<String> fotos;
  final int indiceInicial;

  const VisorFotosPantalla({
    super.key,
    required this.fotos,
    required this.indiceInicial,
  });

  @override
  State<VisorFotosPantalla> createState() => _VisorFotosPantallaState();
}

class _VisorFotosPantallaState extends State<VisorFotosPantalla> {
  late final PageController _ctrl;
  late int _indice;

  @override
  void initState() {
    super.initState();
    _indice = widget.indiceInicial.clamp(0, widget.fotos.length - 1);
    _ctrl = PageController(initialPage: _indice);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _cerrar() {
    Navigator.pop(context, _indice);
  }

  void _irA(int i) {
    if (i == _indice) return;
    _ctrl.animateToPage(
      i,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _botonNavegacion(IconData icono, int destino) {
    return IconButton(
      onPressed: () => _irA(destino),
      icon: Icon(icono, color: Colors.white, size: 34),
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _ctrl,
              itemCount: widget.fotos.length,
              onPageChanged: (i) => setState(() => _indice = i),
              itemBuilder: (context, i) => InteractiveViewer(
                maxScale: 5,
                minScale: 1,
                child: Center(
                  child: imagenFoto(widget.fotos[i],
                      fit: BoxFit.contain, cacheWidth: 1080),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: IconButton(
                onPressed: _cerrar,
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ),
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${_indice + 1} / ${widget.fotos.length}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            if (widget.fotos.length > 1 && _indice > 0)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _botonNavegacion(Icons.chevron_left, _indice - 1),
                ),
              ),
            if (widget.fotos.length > 1 && _indice < widget.fotos.length - 1)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _botonNavegacion(Icons.chevron_right, _indice + 1),
                ),
              ),
            if (widget.fotos.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < widget.fotos.length; i++)
                        GestureDetector(
                          onTap: () => _irA(i),
                          child: Container(
                            width: 52,
                            height: 52,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: i == _indice
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.3),
                                width: i == _indice ? 2.5 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: imagenFoto(widget.fotos[i],
                                  fit: BoxFit.cover, cacheWidth: 200),
                            ),
                          ),
                        ),
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
