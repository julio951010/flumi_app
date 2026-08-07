import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;

import '../../../core/base_datos_local/database.dart';
import '../../../core/base_datos_local/tables.dart';
import '../../../core/estilos/tema.dart';
import '../../../widgets_comunes/barra_progreso_rio.dart';
import '../../perfiles/perfil_etiquetas.dart';
import 'widgets/autocomplete_opcion.dart';
import 'widgets/busca_genero_opcion.dart';
import 'widgets/campo_personalizado_opcion.dart';
import 'widgets/preguntas_perfil_opcion.dart';
import 'widgets/rango_edad_opcion.dart';
import 'widgets/selector_categorias.dart';
import 'widgets/selector_multi_opciones.dart';
import 'widgets/selector_opciones.dart';
import 'widgets/selector_opciones_layout.dart';
import 'widgets/signo_zodiacal_opcion.dart';
import 'widgets/slider_opcion.dart';
import 'widgets/text_area_opcion.dart';

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
  DateTime? _fechaNacimiento;

  final _bioCtrl = TextEditingController();
  final _orientacionPropiaCtrl = TextEditingController();
  final _religionPropiaCtrl = TextEditingController();
  final _mascotasPropiaCtrl = TextEditingController();
  final Set<String> _buscaGenero = {};
  RangeValues _rangoEdad = const RangeValues(18, 99);
  String _orientacion = '';
  String _situacion = '';
  String _hijos = '';
  String _religion = '';
  String _educacion = '';
  final _profesionCtrl = TextEditingController();
  String _trabajo = '';
  String _fuma = '';
  String _bebe = '';
  String _mascotas = '';
  String _tatuajes = '';
  final Set<String> _personalidad = {};
  double _alturaCm = 175;
  bool _prefieroNoDecirAltura = false;
  String _signo = '';
  final Set<String> _idiomas = {};
  final Set<String> _intereses = {};
  final List<PreguntaRespuesta> _preguntasRespondidas = [];

  static const _maxPreguntas = 3;

  static const _totalPasos = 22;

  @override
  void initState() {
    super.initState();
    _cargarFechaNacimiento();
  }

  Future<void> _cargarFechaNacimiento() async {
    final perfil = await (widget.db.select(widget.db.usuarios)
          ..where((u) => u.uuid.equals(widget.usuarioUuid)))
        .getSingleOrNull();
    if (perfil != null && mounted) {
      setState(() => _fechaNacimiento = perfil.fechaNacimiento);
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _bioCtrl.dispose();
    _orientacionPropiaCtrl.dispose();
    _religionPropiaCtrl.dispose();
    _mascotasPropiaCtrl.dispose();
    _profesionCtrl.dispose();
    super.dispose();
  }

  bool get _esIntro => _paso == 0;
  bool get _esBienvenida => _paso >= _totalPasos - 1;
  bool get _esUltimoPaso => _paso == _totalPasos - 2;
  bool get _mostrarAtras => !_esIntro && !_esBienvenida && _paso > 1;
  bool get _esPregunta => !_esIntro && !_esBienvenida;

  static String comboCodigo(List<(String, String)> opciones, String seleccion) {
    if (seleccion.isEmpty) return '';
    for (final o in opciones) {
      if (o.$1 == seleccion) return o.$2;
    }
    return seleccion;
  }

  String _valorBuscaGenero() {
    if (_buscaGenero.contains('prefiero_no_decirlo')) {
      return 'prefiero_no_decirlo';
    }
    if (_buscaGenero.contains('todos')) {
      return 'todos';
    }
    return _buscaGenero.toList().join(',');
  }

  UsuariosCompanion _companionDelPaso(int paso) {
    switch (paso) {
      case 1:
        return UsuariosCompanion(
          biografia: Value(_bioCtrl.text.trim()),
          pendienteDeSincronizar: const Value(true),
        );
      case 2:
        return UsuariosCompanion(
          buscaGenero: Value(_valorBuscaGenero()),
          pendienteDeSincronizar: const Value(true),
        );
      case 3:
        return UsuariosCompanion(
          preferenciaEdadMin: Value(_rangoEdad.start.round()),
          preferenciaEdadMax: Value(_rangoEdad.end.round()),
          pendienteDeSincronizar: const Value(true),
        );
      case 4:
        return UsuariosCompanion(
          orientacionSexual: Value(_orientacion.isNotEmpty
              ? _orientacion
              : _orientacionPropiaCtrl.text.trim()),
          pendienteDeSincronizar: const Value(true),
        );
      case 5:
        return UsuariosCompanion(
          situacionSentimental: Value(comboCodigo(opcionesSituacion, _situacion)),
          pendienteDeSincronizar: const Value(true),
        );
      case 6:
        return UsuariosCompanion(
          hijos: Value(comboCodigo(opcionesHijos, _hijos)),
          pendienteDeSincronizar: const Value(true),
        );
      case 7:
        return UsuariosCompanion(
          religion: Value(_religion.isNotEmpty
              ? _religion
              : _religionPropiaCtrl.text.trim()),
          pendienteDeSincronizar: const Value(true),
        );
      case 8:
        return UsuariosCompanion(
          educacion: Value(comboCodigo(opcionesEducacion, _educacion)),
          pendienteDeSincronizar: const Value(true),
        );
      case 9:
        return UsuariosCompanion(
          profesion: Value(_profesionCtrl.text.trim()),
          pendienteDeSincronizar: const Value(true),
        );
      case 10:
        return UsuariosCompanion(
          trabajo: Value(comboCodigo(opcionesTrabajo, _trabajo)),
          pendienteDeSincronizar: const Value(true),
        );
      case 11:
        return UsuariosCompanion(
          fuma: Value(comboCodigo(opcionesTabaco, _fuma)),
          pendienteDeSincronizar: const Value(true),
        );
      case 12:
        return UsuariosCompanion(
          bebe: Value(comboCodigo(opcionesAlcohol, _bebe)),
          pendienteDeSincronizar: const Value(true),
        );
      case 13:
        return UsuariosCompanion(
          mascotas: Value(_mascotas.isNotEmpty
              ? _mascotas
              : _mascotasPropiaCtrl.text.trim()),
          pendienteDeSincronizar: const Value(true),
        );
      case 14:
        return UsuariosCompanion(
          tatuajes: Value(comboCodigo(opcionesTatuajes, _tatuajes)),
          pendienteDeSincronizar: const Value(true),
        );
      case 15:
        return UsuariosCompanion(
          personalidad: Value(_personalidad.join(', ')),
          pendienteDeSincronizar: const Value(true),
        );
      case 16:
        return UsuariosCompanion(
          altura: Value(_prefieroNoDecirAltura
              ? 'Prefiero no decirlo'
              : '${_alturaCm.round()}'),
          pendienteDeSincronizar: const Value(true),
        );
      case 17:
        return UsuariosCompanion(
          signoZodiaco: Value(comboCodigo(opcionesSigno, _signo)),
          pendienteDeSincronizar: const Value(true),
        );
      case 18:
        return UsuariosCompanion(
          idiomas: Value(_idiomas.toList().join(', ')),
          pendienteDeSincronizar: const Value(true),
        );
      case 19:
        return UsuariosCompanion(
          intereses: Value(_intereses.toList()),
          pendienteDeSincronizar: const Value(true),
        );
      case 20:
        return UsuariosCompanion(
          preguntasPerfil: Value(List.of(_preguntasRespondidas)),
          perfilCompletado: const Value(true),
          pendienteDeSincronizar: const Value(true),
        );
      default:
        return const UsuariosCompanion(
          pendienteDeSincronizar: Value(true),
        );
    }
  }

  Future<void> _guardarPaso() async {
    setState(() => _cargando = true);
    try {
      await (widget.db.update(widget.db.usuarios)
            ..where((u) => u.uuid.equals(widget.usuarioUuid)))
          .write(_companionDelPaso(_paso));
    } catch (_) {}
    if (mounted) setState(() => _cargando = false);
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

  Future<void> _siguiente() async {
    await _guardarPaso();
    if (!mounted) return;
    if (_esUltimoPaso) {
      _irBienvenida();
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
          _pagina('Sobre mí', 'Cuéntanos algo sobre ti. ¿Qué te hace único/a?',
              TextAreaOpcion(
                controller: _bioCtrl,
                hint: 'Escribe algo que no se vea en tu perfil.',
                maxLines: 6,
                maxLength: 500,
                onCambio: (_) {},
              )),
          _pagina('¿A quién te gustaría conocer?',
              'Elige las opciones que te interesen. Puedes seleccionar varias.',
              BuscaGeneroOpcion(
                seleccionados: _buscaGenero,
                onCambio: (nuevo) {
                  setState(() {
                    _buscaGenero
                      ..clear()
                      ..addAll(nuevo);
                  });
                },
              )),
          _pagina('Rango de edad ideal',
              '¿Entre qué edades te gustaría que estuviera tu match?',
              RangoEdadOpcion(
                rango: _rangoEdad,
                minimo: 18,
                maximo: 99,
                deshabilitado: false,
                onCambio: (v) => setState(() => _rangoEdad = v),
              )),
          _pagina('¿Cuál es tu orientación sexual?',
              'Elige la que mejor te describa',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectorOpciones(
                    valorActual: _orientacion,
                    opciones: opcionesOrientacionSexual,
                    dobleColumna: true,
                    onSeleccion: (v) => setState(() {
                      _orientacion = v;
                      _orientacionPropiaCtrl.clear();
                    }),
                  ),
                  const SizedBox(height: 24),
                  CampoPersonalizadoOpcion(
                    controlador: _orientacionPropiaCtrl,
                    habilitado: !_cargando,
                    onCambio: (v) {
                      if (v.trim().isNotEmpty && _orientacion.isNotEmpty) {
                        setState(() => _orientacion = '');
                      }
                    },
                  ),
                ],
              )),
          _pagina('Cuéntanos sobre tu vida sentimental ahora mismo',
              'Esto ayuda a que te conectemos con personas compatibles.',
              SelectorOpciones(
                valorActual: _situacion,
                opciones: opcionesSituacion,
                onSeleccion: (v) => setState(() => _situacion = v),
              )),
          _pagina('¿Tienes hijos?',
              'Es importante para conectar con personas compatibles.',
              SelectorOpciones(
                valorActual: _hijos,
                opciones: opcionesHijos,
                onSeleccion: (v) => setState(() => _hijos = v),
              )),
          _pagina('¿Cuál es tu religión o creencia?',
              'Compartir tus valores ayuda a conectar con personas afines.',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectorOpcionesLayout(
                    valorActual: _religion,
                    filas: [
                      [opcionesReligion[0], opcionesReligion[1]],
                      [opcionesReligion[2], opcionesReligion[3]],
                      [opcionesReligion[4], opcionesReligion[5]],
                      [opcionesReligion[7], opcionesReligion[8]],
                      [opcionesReligion[6]],
                      [opcionesReligion[9]],
                    ],
                    onSeleccion: (v) => setState(() {
                      _religion = v;
                      _religionPropiaCtrl.clear();
                    }),
                  ),
                  const SizedBox(height: 14),
                  CampoPersonalizadoOpcion(
                    controlador: _religionPropiaCtrl,
                    habilitado: !_cargando,
                    onCambio: (v) {
                      if (v.trim().isNotEmpty && _religion.isNotEmpty) {
                        setState(() => _religion = '');
                      }
                    },
                  ),
                ],
              )),
          _pagina('¿Cuál es tu nivel de estudios?',
              'Esto ayuda a conectar con personas con intereses afines.',
              SelectorOpciones(
                valorActual: _educacion,
                opciones: opcionesEducacion,
                onSeleccion: (v) => setState(() => _educacion = v),
              )),
          _pagina('¿Cuál es tu profesión?',
              'Compartir tu profesión ayuda a conectar con personas afines.',
              AutocompleteOpcion(
                controller: _profesionCtrl,
                sugerencias: listaProfesiones,
                hint: 'Escribe tu profesión...',
                onCambio: (_) {},
              )),
          _pagina('¿En qué sector trabajas?',
              'Ayuda a conocer un poco más sobre tu día a día.',
              SelectorOpcionesLayout(
                valorActual: _trabajo,
                filas: [
                  [opcionesTrabajo[1]],
                  [opcionesTrabajo[0]],
                  [opcionesTrabajo[2]],
                  [opcionesTrabajo[3], opcionesTrabajo[4]],
                  [opcionesTrabajo[5], opcionesTrabajo[6]],
                  [opcionesTrabajo[7]],
                  [opcionesTrabajo[8]],
                ],
                onSeleccion: (v) => setState(() => _trabajo = v),
              )),
          _pagina('¿Fumas?',
              'Ayuda a conectar con personas con hábitos similares.',
              SelectorOpciones(
                valorActual: _fuma,
                opciones: opcionesTabaco,
                onSeleccion: (v) => setState(() => _fuma = v),
              )),
          _pagina('¿Bebes alcohol?',
              'Ayuda a conectar con personas con hábitos similares.',
              SelectorOpciones(
                valorActual: _bebe,
                opciones: opcionesAlcohol,
                onSeleccion: (v) => setState(() => _bebe = v),
              )),
          _pagina('¿Tienes mascotas?',
              'Compartir el amor por los animales siempre suma.',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectorOpciones(
                    valorActual: _mascotas,
                    opciones: opcionesMascotas,
                    onSeleccion: (v) => setState(() {
                      _mascotas = v;
                      _mascotasPropiaCtrl.clear();
                    }),
                  ),
                  const SizedBox(height: 24),
                  CampoPersonalizadoOpcion(
                    controlador: _mascotasPropiaCtrl,
                    habilitado: !_cargando,
                    onCambio: (v) {
                      if (v.trim().isNotEmpty && _mascotas.isNotEmpty) {
                        setState(() => _mascotas = '');
                      }
                    },
                  ),
                ],
              )),
          _pagina('¿Tienes tatuajes?',
              'El arte en la piel dice mucho sobre ti.',
              SelectorOpciones(
                valorActual: _tatuajes,
                opciones: opcionesTatuajes,
                onSeleccion: (v) => setState(() => _tatuajes = v),
              )),
          _pagina('¿Cómo describirías tu personalidad?',
              'Elige hasta 3 opciones que mejor te definas.',
              SelectorCategorias(
                categorias: categoriasPersonalidad,
                seleccionados: _personalidad,
                maxSeleccion: 3,
                onCambio: (nuevo) {
                  setState(() {
                    _personalidad
                      ..clear()
                      ..addAll(nuevo);
                  });
                },
              )),
          _pagina('¿Cuál es tu estatura?',
              'Un detalle más para que te conozcan mejor.',
              SliderOpcion(
                valor: _alturaCm,
                prefieroNoDecir: _prefieroNoDecirAltura,
                min: 140,
                max: 220,
                divisions: 80,
                formatoEtiqueta: (v) => '${v.round()} cm',
                etiquetaPrefieroNoDecir: 'Prefiero no decirlo',
                onCambio: (v, pnd) => setState(() {
                  _alturaCm = v;
                  _prefieroNoDecirAltura = pnd;
                }),
              )),
          _pagina('¿Cuál es tu signo del zodíaco?',
              'Un dato divertido para conectar con personas afines.',
              SignoZodiacalOpcion(
                fechaNacimiento: _fechaNacimiento,
                valorActual: _signo,
                onCambio: (v) => setState(() => _signo = v),
              )),
          _pagina('¿Qué idiomas hablas?',
              'Compartir idiomas ayuda a conectar con personas de todo el mundo.',
              SelectorMultiOpciones(
                seleccionados: _idiomas,
                opciones: idiomasDisponibles,
                onCambio: (nuevo) {
                  setState(() {
                    _idiomas
                      ..clear()
                      ..addAll(nuevo);
                  });
                },
              )),
          _pagina('Tus intereses',
              'Elige hasta 10 intereses para conectar con personas afines.',
              SelectorCategorias(
                categorias: categoriasIntereses,
                seleccionados: _intereses,
                maxSeleccion: 10,
                onCambio: (nuevo) {
                  setState(() {
                    _intereses
                      ..clear()
                      ..addAll(nuevo);
                  });
                },
              )),
          _pagina('Preguntas para conocerte mejor',
              'Responde 3 preguntas para que la gente sepa cómo eres realmente.',
              SizedBox(
                height: 400,
                child: PreguntasPerfilOpcion(
                  preguntas: _preguntasRespondidas,
                  onCambio: (nuevo) {
                    setState(() {
                      _preguntasRespondidas
                        ..clear()
                        ..addAll(nuevo);
                    });
                  },
                  maxPreguntas: _maxPreguntas,
                ),
              )),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              subtitulo,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pasoIntro(Color primario) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 90, width: 90,
              decoration: BoxDecoration(color: primario.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.assignment, size: 50, color: primario),
            ),
            const SizedBox(height: 28),
            const Text('Completa tu perfil',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Realiza este cuestionario para completar tu perfil\ny ayuda a otros a conocerte mejor.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.5),
              ),
            ),
            const SizedBox(height: 40),
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
      ),
    );
  }

  Widget _pasoBienvenida(Color primario) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 100, width: 100,
              decoration: BoxDecoration(color: primario.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.check_circle, size: 60, color: primario),
            ),
            const SizedBox(height: 32),
            const Text('¡Todo listo!',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _omitido
                    ? 'Puedes completar tu perfil más tarde desde la sección de perfil.'
                    : 'Tu perfil está completo. Ahora puedes empezar a conocer personas.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.4),
              ),
            ),
            const SizedBox(height: 40),
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
      ),
    );
  }
}
