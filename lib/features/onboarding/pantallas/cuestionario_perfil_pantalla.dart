import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:image_picker/image_picker.dart';
import '../../../core/base_datos_local/database.dart';
import '../../../core/estilos/tema.dart';
import '../../../widgets_comunes/barra_progreso_rio.dart';

class CuestionarioPerfilPantalla extends StatefulWidget {
  final AppDatabase db;
  final String usuarioUuid;
  final VoidCallback onCompletado;

  const CuestionarioPerfilPantalla({
    super.key,
    required this.db,
    required this.usuarioUuid,
    required this.onCompletado,
  });

  @override
  State<CuestionarioPerfilPantalla> createState() => _CuestionarioPerfilPantallaState();
}

class _CuestionarioPerfilPantallaState extends State<CuestionarioPerfilPantalla> {
  final _pageCtrl = PageController();
  int _paso = 0;
  bool _cargando = false;
  bool _omitido = false;

  String _orientacion = '';
  String _orientacionOtro = '';
  String _situacionSentimental = '';
  String _situacionOtro = '';
  final List<String> _intereses = [];
  final _bioCtrl = TextEditingController();
  double _alturaValor = 1.70;
  bool _alturaNoDecir = false;
  String _educacion = '';
  String _educacionOtro = '';
  final _cargoCtrl = TextEditingController();
  final _empresaCtrl = TextEditingController();
  String _bebe = '';
  String _bebeOtro = '';
  String _fuma = '';
  String _fumaOtro = '';
  String _hijos = '';
  String _hijosOtro = '';
  String _personalidad = '';
  String _personalidadOtro = '';
  String _signoZodiaco = '';
  String _signoOtro = '';
  String _mascotas = '';
  String _mascotasOtro = '';
  String _religion = '';
  String _religionOtro = '';
  String _fotoVerificacion = '';

  static const _totalPasos = 17;

  static const _opcionesOrientacion = [
    'Heterosexual', 'Gay', 'Lesbiana', 'Bisexual', 'Asexual', 'Pansexual', 'Otro', 'Prefiero no decirlo',
  ];
  static const _opcionesSituacion = [
    'Soltero/a', 'En una relación', 'Casado/a', 'Es complicado',
    'En una relación abierta', 'Divorciado/a', 'Viudo/a', 'Otro', 'Prefiero no decirlo',
  ];
  static const _listaIntereses = [
    'Deportes', 'Música', 'Cine', 'Viajes', 'Lectura',
    'Cocina', 'Fotografía', 'Arte', 'Naturaleza', 'Videojuegos',
    'Baile', 'Yoga', 'Running', 'Senderismo', 'Animales',
  ];
  static const _opcionesEducacion = [
    'Secundaria', 'Preparatoria', 'Universidad', 'Posgrado', 'Otro',
  ];
  static const _opcionesBebe = [
    'En contextos sociales', 'Nunca', 'A menudo', 'Me mantengo sobrio', 'Otro', 'Prefiero no decirlo',
  ];
  static const _opcionesFuma = [
    'Sí', 'No', 'A veces', 'Otro', 'Prefiero no decirlo',
  ];
  static const _opcionesHijos = [
    'Me gustaría tener algún día', 'Me gustaría tener pronto', 'No quiero tener',
    'Ya tengo', 'Otro', 'Prefiero no decirlo',
  ];
  static const _opcionesPersonalidad = [
    'Reservado/a', 'Extrovertido/a', 'Mezcla de las dos', 'Otro', 'Prefiero no decirlo',
  ];
  static const _opcionesSigno = [
    'Aries', 'Tauro', 'Géminis', 'Cáncer', 'Leo', 'Virgo',
    'Libra', 'Escorpio', 'Sagitario', 'Capricornio', 'Acuario', 'Piscis', 'Prefiero no decirlo',
  ];
  static const _opcionesMascotas = [
    'Gato(s)', 'Perro(s)', 'Perros y gatos', 'Otros animales', 'Sin mascotas', 'Prefiero no decirlo',
  ];
  static const _opcionesReligion = [
    'Católica', 'Cristiana', 'Judía', 'Musulmana', 'Budista',
    'Hindú', 'Agnóstico/a', 'Ateo/a', 'Espiritual pero no religioso',
    'Otra', 'Prefiero no decirlo',
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    _bioCtrl.dispose();
    _cargoCtrl.dispose();
    _empresaCtrl.dispose();
    super.dispose();
  }

  bool get _esIntro => _paso == 0;
  bool get _esBienvenida => _paso >= _totalPasos - 1;
  bool get _esUltimoPaso => _paso == _totalPasos - 2;
  bool get _mostrarAtras => !_esIntro && !_esBienvenida && _paso > 1;
  bool get _esPregunta => !_esIntro && !_esBienvenida;

  void _setOtro(String campo, String v) {
    setState(() {
      switch (campo) {
        case 'orientacion': _orientacionOtro = v; break;
        case 'situacion': _situacionOtro = v; break;
        case 'educacion': _educacionOtro = v; break;
        case 'bebe': _bebeOtro = v; break;
        case 'fuma': _fumaOtro = v; break;
        case 'hijos': _hijosOtro = v; break;
        case 'personalidad': _personalidadOtro = v; break;
        case 'signo': _signoOtro = v; break;
        case 'mascotas': _mascotasOtro = v; break;
        case 'religion': _religionOtro = v; break;
      }
    });
  }

  bool _esOtro(String valor) => valor == 'Otro' || valor == 'Otra' || valor == 'Otros animales';

  Future<void> _guardar() async {
    setState(() => _cargando = true);
    try {
      String resolver(String valor, String otro) => _esOtro(valor) ? otro : valor;
      await (widget.db.update(widget.db.usuarios)
            ..where((u) => u.uuid.equals(widget.usuarioUuid)))
          .write(UsuariosCompanion(
            biografia: Value(_bioCtrl.text.trim()),
            intereses: Value(_intereses),
            orientacionSexual: Value(resolver(_orientacion, _orientacionOtro)),
            situacionSentimental: Value(resolver(_situacionSentimental, _situacionOtro)),
            altura: Value(_alturaNoDecir ? 'Prefiero no decirlo' : '${_alturaValor.toStringAsFixed(2)}m'),
            educacion: Value(resolver(_educacion, _educacionOtro)),
            trabajo: Value('${_cargoCtrl.text.trim()}${_cargoCtrl.text.trim().isNotEmpty && _empresaCtrl.text.trim().isNotEmpty ? ' - ' : ''}${_empresaCtrl.text.trim()}'),
            bebe: Value(resolver(_bebe, _bebeOtro)),
            fuma: Value(resolver(_fuma, _fumaOtro)),
            hijos: Value(resolver(_hijos, _hijosOtro)),
            personalidad: Value(resolver(_personalidad, _personalidadOtro)),
            signoZodiaco: Value(resolver(_signoZodiaco, _signoOtro)),
            mascotas: Value(resolver(_mascotas, _mascotasOtro)),
            religion: Value(resolver(_religion, _religionOtro)),
            fotoVerificacion: Value(_fotoVerificacion),
            perfilCompletado: const Value(true),
            pendienteDeSincronizar: const Value(true),
          ));
    } catch (_) {}
    if (mounted) {
      setState(() => _cargando = false);
      _irBienvenida();
    }
  }

  void _irBienvenida() {
    _pageCtrl.jumpToPage(_totalPasos - 1);
  }

  void _omitirAhora() {
    _omitido = true;
    _irBienvenida();
  }

  void _confirmarOmitir() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Omitir cuestionario?'),
        content: const Text('Puedes completarlo más tarde desde tu perfil.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Seguir respondiendo')),
          TextButton(
            onPressed: () { Navigator.pop(ctx); _omitirAhora(); },
            child: Text('Omitir', style: TextStyle(color: Colors.grey[600])),
          ),
        ],
      ),
    );
  }

  Future<void> _tomarFoto() async {
    final picker = ImagePicker();
    try {
      final foto = await picker.pickImage(source: ImageSource.camera, maxWidth: 1024);
      if (foto != null) {
        setState(() => _fotoVerificacion = foto.path);
      }
    } catch (_) {}
  }

  void _siguiente() {
    if (_esUltimoPaso) {
      _guardar();
      return;
    }
    _pageCtrl.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
  }

  void _atras() {
    _pageCtrl.previousPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    const primario = FlumiTema.colorPrimario;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _esPregunta
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.black87),
                onPressed: _confirmarOmitir,
              ),
              title: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: BarraProgresoRio(
                  progreso: (_paso) / (_totalPasos - 2),
                ),
              ),
              centerTitle: true,
            )
          : null,
      body: PageView(
        controller: _pageCtrl,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _paso = i),
        children: [
          _pasoIntro(primario),
          _pasoOrientacion(primario),
          _pasoSituacion(primario),
          _pasoIntereses(primario),
          _pasoSobreTi(primario),
          _pasoAltura(primario),
          _pasoEducacion(primario),
          _pasoTrabajo(primario),
          _pasoBebe(primario),
          _pasoFuma(primario),
          _pasoHijos(primario),
          _pasoPersonalidad(primario),
          _pasoSigno(primario),
          _pasoMascotas(primario),
          _pasoReligion(primario),
          _pasoFoto(primario),
          _pasoBienvenida(primario),
        ],
      ),
      bottomNavigationBar: _esPregunta ? _barraBotones(primario) : null,
    );
  }

  Widget _barraBotones(Color primario) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Row(
          mainAxisAlignment:
              _mostrarAtras ? MainAxisAlignment.spaceBetween : MainAxisAlignment.end,
          children: [
            if (_mostrarAtras) _botonCircularAtras(),
            _botonCircularSiguiente(primario),
          ],
        ),
      ),
    );
  }

  Widget _botonCircularAtras() {
    return SizedBox(
      width: 56,
      height: 56,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 2,
        child: IconButton(
          onPressed: _atras,
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Colors.grey, size: 24),
        ),
      ),
    );
  }

  Widget _botonCircularSiguiente(Color primario) {
    return SizedBox(
      width: 56,
      height: 56,
      child: ElevatedButton(
        onPressed: _cargando ? null : _siguiente,
        style: ElevatedButton.styleFrom(
          backgroundColor: primario,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          elevation: 0,
          padding: EdgeInsets.zero,
        ),
        child: _cargando
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.arrow_forward_ios_rounded, size: 22),
      ),
    );
  }

  Widget _pagina(String titulo, String subtitulo, Widget child) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(titulo, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 8),
            Text(subtitulo, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            const SizedBox(height: 24),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  Widget _selectorChips(String campo, List<String> opciones, String valor, ValueChanged<String> onChanged, Color primario) {
    final bgClaro = primario.withValues(alpha: 0.08);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: opciones.map((o) {
              final selected = o == valor;
              return GestureDetector(
                onTap: () => onChanged(o),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? primario : bgClaro,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: selected ? primario : Colors.grey[300]!),
                  ),
                  child: Text(o, style: TextStyle(fontSize: 14, color: selected ? Colors.white : Colors.grey[700])),
                ),
              );
            }).toList(),
          ),
          if (_esOtro(valor))
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Especifica...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primario.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primario, width: 1.5),
                  ),
                ),
                onChanged: (v) => _setOtro(campo, v),
              ),
            ),
        ],
      ),
    );
  }

  Widget _selectorMultiChip(List<String> opciones, List<String> seleccionados, Color primario) {
    final bgClaro = primario.withValues(alpha: 0.08);
    return SingleChildScrollView(
      child: Wrap(
        spacing: 8,
        runSpacing: 10,
        children: opciones.map((o) {
          final selected = seleccionados.contains(o);
          return GestureDetector(
            onTap: () => setState(() {
              if (selected) { seleccionados.remove(o); }
              else { seleccionados.add(o); }
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: selected ? primario : bgClaro,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: selected ? primario : Colors.grey[300]!),
              ),
              child: Text(o, style: TextStyle(fontSize: 14, color: selected ? Colors.white : Colors.grey[700])),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _pasoIntro(Color primario) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Container(
            height: 90, width: 90,
            decoration: BoxDecoration(color: primario.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(Icons.assignment, size: 50, color: primario),
          ),
          const SizedBox(height: 28),
          const Text('Completa tu perfil',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 14),
          Text(
            'Realiza este cuestionario para completar tu perfil\ny ayuda a otros a conocerte mejor.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.5),
          ),
          const Spacer(flex: 3),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _siguiente,
              style: ElevatedButton.styleFrom(
                backgroundColor: primario, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0,
              ),
              child: const Text('Ir al cuestionario', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 48,
            child: TextButton(
              onPressed: _omitirAhora,
              child: Text('Quizá más tarde', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _pasoBienvenida(Color primario) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Container(
            height: 100, width: 100,
            decoration: BoxDecoration(color: primario.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(Icons.check_circle, size: 60, color: primario),
          ),
          const SizedBox(height: 32),
          const Text('¡Todo listo!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          Text(
            _omitido
                ? 'Puedes completar tu perfil más tarde desde la sección de perfil.'
                : 'Tu perfil está completo. Ahora puedes empezar a conocer personas.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.4),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: () async {
                if (_omitido) {
                  await (widget.db.update(widget.db.usuarios)
                      ..where((u) => u.uuid.equals(widget.usuarioUuid)))
                    .write(const UsuariosCompanion(perfilCompletado: Value(true)));
                }
                if (mounted) widget.onCompletado();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primario, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0,
              ),
              child: const Text('Comenzar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _pasoOrientacion(Color primario) {
    return _pagina('Orientación sexual', 'Selecciona tu orientación sexual',
        _selectorChips('orientacion', _opcionesOrientacion, _orientacion, (v) => setState(() => _orientacion = v), primario));
  }

  Widget _pasoSituacion(Color primario) {
    return _pagina('Situación sentimental', '¿Cuál es tu situación actual?',
        _selectorChips('situacion', _opcionesSituacion, _situacionSentimental, (v) => setState(() => _situacionSentimental = v), primario));
  }

  Widget _pasoIntereses(Color primario) {
    return _pagina('Intereses', 'Selecciona tus intereses (puedes elegir varios)',
        _selectorMultiChip(_listaIntereses, _intereses, primario));
  }

  Widget _pasoSobreTi(Color primario) {
    return _pagina('Sobre ti', 'Escribe una breve descripción sobre ti',
        TextFormField(
          controller: _bioCtrl, maxLines: 5, style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Cuéntanos algo sobre ti...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primario.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primario, width: 1.5),
            ),
          ),
        ));
  }

  Widget _pasoAltura(Color primario) {
    return _pagina('Estatura', 'Selecciona tu estatura', LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            const Spacer(),
            if (!_alturaNoDecir)
              Center(
                child: Text(
                  '${_alturaValor.toStringAsFixed(2)} m',
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: primario),
                ),
              ),
            Slider(
              value: _alturaValor, min: 1.00, max: 3.00, divisions: 200,
              activeColor: primario,
              inactiveColor: primario.withValues(alpha: 0.2),
              label: '${_alturaValor.toStringAsFixed(2)}m',
              onChanged: _alturaNoDecir ? null : (v) => setState(() => _alturaValor = v),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _alturaNoDecir = !_alturaNoDecir),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _alturaNoDecir ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: _alturaNoDecir ? primario : Colors.grey[400],
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text('Prefiero no decirlo',
                      style: TextStyle(color: Colors.grey[600], fontSize: 15)),
                ],
              ),
            ),
            const Spacer(),
          ],
        );
      },
    ));
  }

  Widget _pasoEducacion(Color primario) {
    return _pagina('Educación', '¿Cuál es tu nivel educativo?',
        _selectorChips('educacion', _opcionesEducacion, _educacion, (v) => setState(() => _educacion = v), primario));
  }

  Widget _pasoTrabajo(Color primario) {
    return _pagina('¿A qué te dedicas?', 'Cuéntanos sobre tu trabajo',
        Column(
          children: [
            const SizedBox(height: 8),
            TextFormField(
              controller: _cargoCtrl, style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Cargo / Puesto',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primario.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primario, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _empresaCtrl, style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Empresa / Institución',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primario.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primario, width: 1.5),
                ),
              ),
            ),
          ],
        ));
  }

  Widget _pasoBebe(Color primario) {
    return _pagina('¿Bebes?', 'Selecciona tu consumo de alcohol',
        _selectorChips('bebe', _opcionesBebe, _bebe, (v) => setState(() => _bebe = v), primario));
  }

  Widget _pasoFuma(Color primario) {
    return _pagina('¿Fumas?', 'Selecciona tu consumo de tabaco',
        _selectorChips('fuma', _opcionesFuma, _fuma, (v) => setState(() => _fuma = v), primario));
  }

  Widget _pasoHijos(Color primario) {
    return _pagina('¿Tienes hijos?', 'Selecciona tu situación',
        _selectorChips('hijos', _opcionesHijos, _hijos, (v) => setState(() => _hijos = v), primario));
  }

  Widget _pasoPersonalidad(Color primario) {
    return _pagina('Personalidad', '¿Te consideras más reservado/a o extrovertido/a?',
        _selectorChips('personalidad', _opcionesPersonalidad, _personalidad, (v) => setState(() => _personalidad = v), primario));
  }

  Widget _pasoSigno(Color primario) {
    return _pagina('Signo del zodiaco', '¿Cuál es tu signo?',
        _selectorChips('signo', _opcionesSigno, _signoZodiaco, (v) => setState(() => _signoZodiaco = v), primario));
  }

  Widget _pasoMascotas(Color primario) {
    return _pagina('Mascotas', '¿Tienes mascotas?',
        _selectorChips('mascotas', _opcionesMascotas, _mascotas, (v) => setState(() => _mascotas = v), primario));
  }

  Widget _pasoReligion(Color primario) {
    return _pagina('Religión', '¿Cuál es tu religión o creencia?',
        _selectorChips('religion', _opcionesReligion, _religion, (v) => setState(() => _religion = v), primario));
  }

  Widget _pasoFoto(Color primario) {
    final tieneFoto = _fotoVerificacion.isNotEmpty;
    return _pagina('Verificar con foto', 'Toma una selfie para verificar tu identidad',
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (tieneFoto)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(File(_fotoVerificacion), height: 220, width: 220, fit: BoxFit.cover),
                )
              else
                Container(
                  height: 220, width: 220,
                  decoration: BoxDecoration(
                    color: primario.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primario.withValues(alpha: 0.3)),
                  ),
                  child: Icon(Icons.camera_alt, size: 60, color: primario.withValues(alpha: 0.5)),
                ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _tomarFoto,
                icon: Icon(tieneFoto ? Icons.refresh : Icons.camera_alt, size: 20),
                label: Text(tieneFoto ? 'Tomar otra' : 'Tomar foto'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primario, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ));
  }
}
