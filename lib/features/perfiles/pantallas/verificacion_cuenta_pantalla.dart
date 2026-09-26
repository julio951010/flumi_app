import 'package:camera/camera.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/base_datos_local/database.dart';
import '../../../core/estilos/tema.dart';
import '../../../core/servicios/notificacion_servicio.dart';
import '../../../core/servicios/perfil_foto_servicio.dart';
import '../../../core/utilidades/verificacion_cuenta_io_native.dart'
    if (dart.library.html) '../../../core/utilidades/verificacion_cuenta_io_web.dart';
import '../../../widgets_comunes/foto_perfil.dart';
import '../perfil_repositorio.dart';

/// Verificación de cuenta por revisión manual: la selfie se sube al servidor
/// y un administrador la compara con las fotos del perfil desde admin_flumi.
/// Sin ML on-device (sin FaceNet ni gestos): la app pesa mucho menos.
class VerificacionCuentaPantalla extends StatefulWidget {
  final Usuario perfil;
  final PerfilRepositorio repositorio;

  const VerificacionCuentaPantalla({
    super.key,
    required this.perfil,
    required this.repositorio,
  });

  @override
  State<VerificacionCuentaPantalla> createState() =>
      _VerificacionCuentaPantallaState();
}

class _VerificacionCuentaPantallaState extends State<VerificacionCuentaPantalla>
    with WidgetsBindingObserver {
  final _picker = ImagePicker();

  static const int _maxIntentos = 3;
  static const Duration _ventanaIntentos = Duration(hours: 24);

  String get _claveIntentos =>
      'verificacion_intentos_${widget.perfil.uuid}';

  /// Intentos de las últimas 24 h (persisten: salir y entrar no resetea).
  Future<void> _cargarIntentos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ahora = DateTime.now().millisecondsSinceEpoch;
      final lista = prefs.getStringList(_claveIntentos) ?? const <String>[];
      final recientes = lista
          .map(int.tryParse)
          .whereType<int>()
          .where((t) => ahora - t < _ventanaIntentos.inMilliseconds)
          .toList();
      if (!mounted) return;
      setState(() => _intentos = recientes.length.clamp(0, _maxIntentos));
    } catch (_) {}
  }

  Future<void> _registrarIntento() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lista = prefs.getStringList(_claveIntentos) ?? <String>[];
      lista.add(DateTime.now().millisecondsSinceEpoch.toString());
      await prefs.setStringList(_claveIntentos, lista);
    } catch (_) {}
  }

  String? _rutaFoto;
  bool _enviando = false;
  late bool _pendiente;
  late bool _verificado;
  int _intentos = 0;

  CameraController? _controller;
  bool _camaraIniciando = false;
  bool _capturando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargarIntentos();
    _verificado = widget.perfil.verificadoStatus;
    _pendiente = widget.perfil.fotoVerificacion.isNotEmpty &&
        !widget.perfil.verificadoStatus;
    if (!_verificado && !_pendiente) {
      _inicializarCamara();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.paused) {
      controller.dispose();
      if (mounted) setState(() => _controller = null);
    } else if (state == AppLifecycleState.resumed) {
      if (_rutaFoto == null) _inicializarCamara();
    }
  }

  Future<void> _inicializarCamara() async {
    if (kIsWeb || _controller != null) return;
    if (!mounted) return;
    setState(() {
      _camaraIniciando = true;
    });
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) setState(() => _camaraIniciando = false);
        return;
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _camaraIniciando = false);
        return;
      }
      // Siempre usamos la cámara frontal; si no hay frontal disponible,
      // fallamos explícitamente en lugar de caer a la cámara trasera.
      final frontal = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => throw Exception('sin-camara-frontal'),
      );
      final controller =
          CameraController(frontal, ResolutionPreset.high, enableAudio: false);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _camaraIniciando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _camaraIniciando = false);
    }
  }

  Future<void> _capturar() async {
    if (_capturando) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    setState(() => _capturando = true);
    try {
      final foto = await controller.takePicture();
      // Espejamos la selfie horizontalmente (como un espejo) para que quede
      // como un selfie normal.
      final reflejo = await espejarSelfie(foto.path);
      String rutaFinal = reflejo.$1;
      var espejada = reflejo.$2;
      await controller.dispose();
      if (!mounted) return;
      if (!espejada) {
        NotificacionServicio.alerta(
          context,
          'No se pudo espejar la selfie; se guardó sin espejar.',
        );
      }
      setState(() {
        _controller = null;
        _rutaFoto = rutaFinal;
        _capturando = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _capturando = false);
        NotificacionServicio.alerta(
          context,
          'No se pudo capturar la foto. Intenta de nuevo.',
        );
      }
    }
  }

  void _rehacerFoto() {
    if (!mounted) return;
    setState(() => _rutaFoto = null);
    _inicializarCamara();
  }

  Future<void> _tomarFoto() async {
    try {
      final fuente = kIsWeb ? ImageSource.gallery : ImageSource.camera;
      final foto = await _picker.pickImage(source: fuente, maxWidth: 1080);
      if (foto == null) return;
      if (!mounted) return;
      setState(() => _rutaFoto = foto.path);
    } catch (_) {
      if (!mounted) return;
      NotificacionServicio.alerta(
        context,
        kIsWeb
            ? 'No se pudo abrir la cámara en el navegador. Sube una foto del dispositivo.'
            : 'No se pudo acceder a la cámara. Revisa los permisos.',
      );
    }
  }

  /// Envía la selfie a revisión manual: se sube al servidor y queda pendiente
  /// hasta que un administrador la apruebe o rechace desde admin_flumi.
  Future<void> _enviarVerificacion() async {
    final ruta = _rutaFoto;
    if (ruta == null || ruta.isEmpty) return;
    if (_intentos >= _maxIntentos) return;
    setState(() => _enviando = true);
    try {
      final urlSubida = await PerfilFotoServicio.subirFotoVerificacion(
        usuarioId: widget.perfil.uuid,
        archivoRuta: ruta,
      );
      if (urlSubida == null) {
        if (!mounted) return;
        NotificacionServicio.alerta(
          context,
          'No se pudo subir la foto. Intenta de nuevo.',
        );
        return;
      }
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(widget.perfil.uuid),
        fotoVerificacion: Value(urlSubida),
        verificadoStatus: const Value(false),
      ));
      if (!mounted) return;
      _intentos++;
      _registrarIntento();
      setState(() {
        _verificado = false;
        _pendiente = true;
      });
      NotificacionServicio.exito(
        context,
        'Foto enviada. Te avisaremos cuando termine la revisión.',
      );
    } catch (_) {
      if (!mounted) return;
      NotificacionServicio.alerta(
        context,
        'No se pudo enviar la verificación. Intenta de nuevo.',
      );
    } finally {
      await _borrarFotoLocal(ruta);
      if (mounted) {
        setState(() {
          _enviando = false;
          _rutaFoto = null;
        });
      }
    }
  }

  /// Elimina el archivo local de la selfie (nativo). En web no aplica.
  Future<void> _borrarFotoLocal(String ruta) async {
    await borrarArchivo(ruta);
  }

  @override
  Widget build(BuildContext context) {
    final primario = FlumiTema.colorPrimario;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Verificación de cuenta',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: _verificado
            ? _seccionVerificado(primario)
            : _pendiente
                ? _seccionPendiente(primario)
                : _seccionCaptura(primario),
      ),
    );
  }

  Widget _contenidoTuFoto() {
    if (_rutaFoto != null) {
      return imagenOrigen(_rutaFoto!, fit: BoxFit.cover);
    }
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      final primario = FlumiTema.colorPrimario;
      return Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(controller),
          // Tocar cualquier parte del preview captura la foto.
          Positioned.fill(
            child: GestureDetector(
              onTap: _capturando ? null : _capturar,
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 14,
            child: Center(
              child: GestureDetector(
                onTap: _capturando ? null : _capturar,
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primario,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.camera_alt,
                      color: Colors.white, size: 30),
                ),
              ),
            ),
          ),
          if (_capturando)
            const Positioned.fill(
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      );
    }
    if (_camaraIniciando) {
      return const Center(child: CircularProgressIndicator());
    }
    // Sin cámara disponible (permiso denegado, sin cámara o web sin soporte).
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.camera_alt_outlined, size: 34, color: Colors.grey[400]),
        const SizedBox(height: 8),
        Text(
          'No se pudo abrir la cámara frontal',
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          textAlign: TextAlign.center,
        ),
        if (!kIsWeb)
          TextButton(
            onPressed: _inicializarCamara,
            child: const Text('Reintentar'),
          ),
        TextButton(
          onPressed: _tomarFoto,
          child: const Text('Usar cámara del sistema'),
        ),
      ],
    );
  }

  List<Widget> _seccionCaptura(Color primario) {
    final intentosRestantes = _maxIntentos - _intentos;
    final bloqueado = _intentos >= _maxIntentos;
    return [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: FlumiTema.colorPrimario.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          children: [
            Icon(Icons.verified, size: 48, color: FlumiTema.colorPrimario),
            SizedBox(height: 12),
            Text(
              'Verifica tu cuenta con una selfie',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Tómate una foto de frente con buena luz. Nuestro equipo la '
              'comparará con tus fotos de perfil y te avisará cuando termine '
              'la revisión.',
              style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!, width: 1.5),
        ),
        child: Column(
          children: [
            const Text('Tu foto',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 280,
                width: double.infinity,
                child: _contenidoTuFoto(),
              ),
            ),
          ],
        ),
      ),
      if (_rutaFoto != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: TextButton.icon(
            onPressed: _rehacerFoto,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Tomar otra foto'),
          ),
        ),
      const SizedBox(height: 24),
      SizedBox(
        height: 52,
        child: FilledButton.icon(
          onPressed: (_rutaFoto == null || _enviando || bloqueado)
              ? null
              : _enviarVerificacion,
          style: FilledButton.styleFrom(
            backgroundColor: primario,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          icon: _enviando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check_circle_outline, size: 20),
          label: Text(
            _enviando ? 'Enviando...' : 'Enviar verificación',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      if (_intentos > 0)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            'Intentos restantes: $intentosRestantes de $_maxIntentos',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ),
      if (bloqueado)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Has alcanzado el máximo de 3 envíos en 24 horas. '
            'Vuelve mañana con buena luz de frente.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ),
    ];
  }

  List<Widget> _seccionPendiente(Color primario) {
    final rutaFoto = _rutaFoto ?? widget.perfil.fotoVerificacion;
    return [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFC9A227).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          children: [
            Icon(Icons.hourglass_top_outlined,
                size: 48, color: Color(0xFFC9A227)),
            SizedBox(height: 12),
            Text(
              'Verificación en revisión',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Tu foto fue enviada y está siendo revisada por Flumi. '
              'Te avisaremos cuando termine.',
              style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      if (rutaFoto.isNotEmpty)
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[300]!, width: 1.5),
          ),
          child: Column(
            children: [
              const Text('Tu foto enviada',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 280,
                  width: double.infinity,
                  child: imagenOrigen(rutaFoto, fit: BoxFit.cover),
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 24),
      if (_intentos < _maxIntentos)
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() => _pendiente = false);
              _inicializarCamara();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: primario,
              side: BorderSide(color: primario),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Volver a enviar',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      if (_intentos < _maxIntentos) const SizedBox(height: 12),
      SizedBox(
        height: 52,
        child: FilledButton.icon(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(
            backgroundColor: primario,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          icon: const Icon(Icons.check, size: 20),
          label: const Text('Entendido',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ),
    ];
  }

  List<Widget> _seccionVerificado(Color primario) {
    return [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          children: [
            Icon(Icons.verified_user, size: 48, color: Colors.green),
            SizedBox(height: 12),
            Text(
              'Perfil verificado',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Hemos comprobado que eres tú. Tu badge de verificado '
              'ya es visible para los demás.',
              style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      SizedBox(
        height: 52,
        child: FilledButton.icon(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(
            backgroundColor: primario,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          icon: const Icon(Icons.check, size: 20),
          label: const Text('Entendido',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ),
    ];
  }
}
