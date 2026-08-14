import 'dart:math';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/base_datos_local/database.dart';
import '../../../core/estilos/tema.dart';
import '../../../core/servicios/notificacion_servicio.dart';
import '../../../widgets_comunes/foto_perfil.dart';
import '../perfil_repositorio.dart';

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

class _VerificacionCuentaPantallaState extends State<VerificacionCuentaPantalla> {
  final _picker = ImagePicker();
  final _random = Random();
  final List<String> _gestos = [
    'assets/images/gestos/gesto1.png',
    'assets/images/gestos/gesto2.png',
    'assets/images/gestos/gesto3.png',
    'assets/images/gestos/gesto4.png',
  ];

  static const int _maxIntentos = 3;

  late final String _gestoRuta;
  String? _rutaFoto;
  bool _enviando = false;
  late bool _pendiente;
  int _intentos = 0;

  @override
  void initState() {
    super.initState();
    _gestoRuta = _gestos[_random.nextInt(_gestos.length)];
    _pendiente = widget.perfil.fotoVerificacion.isNotEmpty &&
        !widget.perfil.verificadoStatus;
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

  Future<void> _enviarVerificacion() async {
    final ruta = _rutaFoto;
    if (ruta == null || ruta.isEmpty) return;
    if (_intentos >= _maxIntentos) return;
    setState(() => _enviando = true);
    try {
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(widget.perfil.uuid),
        fotoVerificacion: Value(ruta),
        // Se conserva verificadoStatus sin cambios: la cuenta queda en
        // estado "pendiente" hasta que Flumi la revise.
      ));
      if (!mounted) return;
      _intentos++;
      setState(() => _pendiente = true);
      NotificacionServicio.exito(context, 'Foto enviada. En revisión.');
    } catch (_) {
      if (!mounted) return;
      NotificacionServicio.alerta(
        context,
        'No se pudo enviar la verificación. Intenta de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
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
        children: _pendiente
            ? _seccionPendiente(primario)
            : _seccionCaptura(primario),
      ),
    );
  }

  List<Widget> _seccionCaptura(Color primario) {
    final intentosRestantes = _maxIntentos - _intentos;
    final bloqueado = _intentos >= _maxIntentos;
    return [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          children: [
            Icon(Icons.verified, size: 48, color: Color(0xFF6C63FF)),
            SizedBox(height: 12),
            Text(
              'Verifica tu cuenta con un gesto',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Imita el gesto que te mostramos y toma una foto de frente. '
              'Flumi revisará que coincida con tu perfil.',
              style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tarjetaLateral(
            'Gesto a imitar',
            Image.asset(_gestoRuta, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          if (_rutaFoto != null)
            _tarjetaLateral(
              'Tu foto',
              imagenOrigen(_rutaFoto!, fit: BoxFit.cover),
            )
          else
            _tarjetaLateral(
              'Tu foto',
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined,
                      size: 36, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    kIsWeb ? 'Sube una foto' : 'Tómate una foto',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
              onTap: _tomarFoto,
            ),
        ],
      ),
      if (_rutaFoto != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: TextButton.icon(
            onPressed: _tomarFoto,
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
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Has alcanzado el máximo de $_maxIntentos intentos. '
            'Flumi revisará tu última foto.',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ),
    ];
  }

  Widget _tarjetaLateral(String titulo, Widget imagen, {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[300]!, width: 1.5),
          ),
          child: Column(
            children: [
              Text(titulo,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: imagen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tarjetaLateral(
            'Gesto solicitado',
            Image.asset(_gestoRuta, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          if (rutaFoto.isNotEmpty)
            _tarjetaLateral(
              'Tu foto enviada',
              imagenOrigen(rutaFoto, fit: BoxFit.cover),
            ),
        ],
      ),
      const SizedBox(height: 24),
      if (_intentos < _maxIntentos)
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _pendiente = false),
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
}
