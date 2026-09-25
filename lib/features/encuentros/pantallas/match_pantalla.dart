import 'package:flutter/material.dart';
import '../../../core/utilidades/fotos_perfil.dart';

import '../../../core/base_datos_local/database.dart';
import '../../../core/estilos/tema.dart';
import '../../../core/servicios/suscripcion_servicio.dart';
import '../../../widgets_comunes/foto_perfil_io.dart';
import '../../chat/chat_repositorio.dart';
import '../../chat/pantallas/chat_pantalla.dart';

class MatchPantalla extends StatefulWidget {
  final Usuario usuario;
  final String miId;
  final ChatRepositorio chatRepo;
  final SuscripcionServicio suscripcionServicio;

  const MatchPantalla({
    super.key,
    required this.usuario,
    required this.miId,
    required this.chatRepo,
    required this.suscripcionServicio,
  });

  @override
  State<MatchPantalla> createState() => _MatchPantallaState();
}

class _MatchPantallaState extends State<MatchPantalla>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animacion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();
  late final Animation<double> _escala = CurvedAnimation(
    parent: _animacion,
    curve: Curves.elasticOut,
  );
  late final Animation<double> _opacidad = CurvedAnimation(
    parent: _animacion,
    curve: const Interval(0, 0.45, curve: Curves.easeOut),
  );
  final _mensajeCtrl = TextEditingController();

  @override
  void dispose() {
    _animacion.dispose();
    _mensajeCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviarYConversar() async {
    final texto = _mensajeCtrl.text.trim();
    // Mismo gate que ChatPantalla._enviar: gratis no puede enviar mensajes.
    // Sin esto, el match permitía saltarse el paywall de mensajería.
    if (texto.isNotEmpty && !widget.suscripcionServicio.esGratis) {
      await widget.chatRepo.enviarMensaje(
        emisorId: widget.miId,
        receptorId: widget.usuario.uuid,
        contenido: texto,
      );
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPantalla(
          repositorio: widget.chatRepo,
          otroUsuarioId: widget.usuario.uuid,
          miId: widget.miId,
          nombreOtro: widget.usuario.nombre,
          online: ChatRepositorio.estaEnLinea(widget.usuario),
          esMeGusta: true,
          esMatch: true,
          suscripcionServicio: widget.suscripcionServicio,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _fotoFondo(),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black54, Colors.black26, Colors.black38, Colors.black87],
                stops: [0.0, 0.35, 0.55, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _botonCerrar(),
                  ),
                ),
                _imagenMatch(),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _panelInferior(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fotoFondo() {
    final fotos = fotosParaMostrar(widget.usuario);
    if (fotos.isNotEmpty) {
      return SizedBox.expand(
        child: imagenFoto(fotos.first, fit: BoxFit.cover, cacheWidth: 1080),
      );
    }
    return _gradienteFallback();
  }

  Widget _gradienteFallback() {
    final u = widget.usuario;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FlumiTema.colorPrimario, Colors.black87],
        ),
      ),
      child: Center(
        child: Text(
          u.nombre.isNotEmpty ? u.nombre[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 140,
            fontWeight: FontWeight.bold,
            color: Colors.white54,
          ),
        ),
      ),
    );
  }

  Widget _botonCerrar() {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.pop(context),
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(Icons.close, color: Colors.white, size: 26),
        ),
      ),
    );
  }

  Widget _imagenMatch() {
    return Align(
      alignment: Alignment.center,
      child: FadeTransition(
        opacity: _opacidad,
        child: ScaleTransition(
          scale: _escala,
          child: Image.asset(
            'assets/images/match.png',
            width: 300,
            height: 220,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Widget _panelInferior() {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  '¡Es un match con ${widget.usuario.nombre}!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (widget.usuario.verificadoStatus) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.verified,
                  color: Colors.white,
                  size: 26,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
const Text(
              'Esto podr\u00eda ser el principio de algo...\n'
              'Ahora solo falta que t\u00fa des el primer paso.',
              style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.4,
              shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _campoMensaje(),
        ],
      ),
    );
  }

  Widget _campoMensaje() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 6, 6, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _mensajeCtrl,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _enviarYConversar(),
              decoration: const InputDecoration(
                hintText: 'Enviar mensaje',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          Material(
            color: FlumiTema.colorPrimario,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _enviarYConversar,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}