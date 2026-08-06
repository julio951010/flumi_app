import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../core/base_datos_local/database.dart';
import '../../../core/base_datos_local/tables.dart';
import '../../../core/estilos/tema.dart';
import '../../../widgets_comunes/barra_progreso_rio.dart';
import '../../perfiles/perfil_etiquetas.dart';

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

  final _bioCtrl = TextEditingController();
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
  static const _maxCaracteresRespuesta = 300;

  static const _totalPasos = 22;

  static const _generosBusca = [
    '\ud83d\udc68 Hombres',
    '\ud83d\udc69 Mujeres',
    '\u26a7\ufe0f Personas no binarias',
  ];
  static const _etiquetaTodos = '\ud83c\udf08 Todos/as';
  static const _etiquetaPrefieroBusca = '\ud83d\ude48 Prefiero no decirlo';

  static const _listaProfesiones = [
    'M\u00e9dico/a', 'Enfermero/a', 'Psic\u00f3logo/a', 'Fisioterapeuta',
    'Nutricionista', 'Dentista', 'Veterinario/a', 'Farmac\u00e9utico/a',
    'Ingeniero/a', 'Arquitecto/a', 'Dise\u00f1ador/a gr\u00e1fico',
    'Desarrollador/a de software', 'Analista de datos', 'Cient\u00edfico/a',
    'Investigador/a', 'Profesor/a', 'Maestro/a', 'Abogado/a', 'Juez/a',
    'Contador/a', 'Economista', 'Administrador/a de empresas',
    'Gerente / Directivo/a', 'Empresario/a', 'Emprendedor/a',
    'Periodista', 'Escritor/a', 'Editor/a', 'Traductor/a',
    'Publicista / Marketing', 'Comercial / Ventas', 'Recursos Humanos',
    'Chef', 'Cocinero/a', 'Mesero/a', 'Bartender', 'Panadero/a',
    'Agricultor/a', 'Ganadero/a', 'Pescador/a', 'Electricista',
    'Plomero/a', 'Carpintero/a', 'Alba\u00f1il', 'Soldador/a',
    'Mec\u00e1nico/a', 'Conductor/a', 'Piloto', 'Marinero/a',
    'Polic\u00eda', 'Bombero/a', 'Militar', 'Guardia de seguridad',
    'Artista', 'M\u00fasico/a', 'Actor/Actriz', 'Bailar\u00edn/Bailarina',
    'Fot\u00f3grafo/a', 'Dise\u00f1ador/a de moda', 'Modelo',
    'Deportista / Atleta', 'Entrenador/a personal', 'Masajista',
    'Estilista / Peluquero/a', 'Cosmet\u00f3logo/a', 'Tatuador/a',
    'Vendedor/a', 'Comerciante', 'Ama de casa', 'Estudiante',
    'Jubilado/a', 'Desempleado/a', 'Otro',
  ];

  static const _idiomasDisponibles = [
    'Espa\u00f1ol', 'Ingl\u00e9s', 'Franc\u00e9s', 'Alem\u00e1n', 'Italiano',
    'Portugu\u00e9s', 'Catal\u00e1n', 'Euskera', 'Gallego', 'Valenciano',
    '\u00c1rabe', 'Chino', 'Japon\u00e9s', 'Coreano', 'Ruso', 'Hindi',
    'Neerland\u00e9s', 'Griego', 'Turco', 'Sueco', 'Noruego', 'Dan\u00e9s',
    'Polaco', 'Hebreo', 'Filipino', 'Vietnamita', 'Tailand\u00e9s',
    'Ucraniano', 'Checo', 'Rumano', 'H\u00fangaro', 'Persa', 'Suajili',
  ];

  static const _categoriasIntereses = <(String, List<String>)>[
    ('\ud83c\udfc3 Deportes y actividad f\u00edsica', [
      '\u26bd F\u00fatbol',
      '\ud83c\udfc0 Baloncesto',
      '\ud83c\udfbe Tenis',
      '\ud83c\udff8 P\u00e1del',
      '\u26f3 Golf',
      '\ud83c\udfc3 Running / Atletismo',
      '\ud83c\udfca Nataci\u00f3n',
      '\ud83d\udeb4 Ciclismo',
      '\ud83e\udd9e Senderismo / Monta\u00f1a',
      '\ud83e\uddd7 Escalada',
      '\ud83c\udfc4 Surf',
      '\ud83c\udfbf Snowboard / Esqu\u00ed',
      '\ud83e\uddd8 Yoga',
      '\ud83e\uddd8\u200d\u2640\ufe0f Pilates',
      '\ud83d\udcaa CrossFit',
      '\ud83c\udfcb\ufe0f Gimnasio / Fitness',
      '\ud83e\udd4b Artes marciales',
      '\ud83e\udd4a Boxeo',
      '\u26f8\ufe0f Patinaje',
      '\ud83c\udfd0 Voleibol',
      '\ud83c\udfd5 Rugby',
      '\u26be B\u00e9isbol',
    ]),
    ('\ud83c\udfa8 Arte y cultura', [
      '\ud83c\udfac Cine',
      '\ud83c\udfad Teatro',
      '\ud83c\udfdb\ufe0f Museos',
      '\ud83c\udfa8 Pintura',
      '\u270f\ufe0f Dibujo',
      '\ud83d\udcf7 Fotograf\u00eda',
      '\ud83d\udcda Literatura / Lectura',
      '\u270d\ufe0f Escritura',
      '\ud83d\udc83 Danza',
      '\ud83e\uddbd Ballet',
      '\ud83c\udfbb M\u00fasica cl\u00e1sica',
      '\ud83c\udfb5 \u00d3pera',
    ]),
    ('\ud83c\udfb5 M\u00fasica', [
      '\ud83c\udfb8 Rock',
      '\ud83c\udfa4 Pop',
      '\ud83c\udfb5 Reggaet\u00f3n',
      '\ud83c\udf0d K-pop',
      '\ud83c\udfb7 Jazz',
      '\ud83c\udfb9 M\u00fasica electr\u00f3nica',
      '\ud83c\udfb6 Indie',
      '\ud83d\udc83 Salsa',
      '\ud83c\udfb5 Bachata',
      '\ud83e\udd18 Metal',
      '\ud83c\udfa4 Hip-hop / Rap',
      '\ud83c\udfa4 Cantar / Karaoke',
      '\ud83c\udfb9 Tocar un instrumento',
    ]),
    ('\ud83c\udf54 Gastronom\u00eda', [
      '\ud83c\udf57 Cocina / Reposter\u00eda',
      '\ud83c\udf54 Gastronom\u00eda',
      '\ud83c\udf77 Vino / Enolog\u00eda',
      '\ud83c\udf7a Cerveza artesanal',
      '\u2615 Caf\u00e9 / Cafeter\u00edas',
      '\ud83c\udf31 Comida vegana / Vegetariana',
      '\ud83c\udf5c Comida asi\u00e1tica',
      '\ud83c\udf5d Comida italiana',
      '\ud83c\udf6d Comida mexicana',
      '\ud83e\udd69 Parrillas / Barbacoa',
      '\ud83e\uddc0 Quesos / Catas',
      '\ud83c\udf5c Restaurantes / Foodie',
    ]),
    ('\u2708\ufe0f Viajes y aventura', [
      '\u2708\ufe0f Viajar',
      '\ud83c\udf92 Mochilero / Backpacker',
      '\ud83c\udfe1 Turismo rural',
      '\ud83c\udfd9\ufe0f Ciudades europeas',
      '\ud83c\udfd6\ufe0f Playas / Mar',
      '\ud83d\udea2 Cruceros',
      '\ud83d\ude97 Viajes en carretera',
      '\ud83d\udcf8 Fotograf\u00eda de viaje',
      '\u26fa Acampar / Camping',
      '\ud83c\udfd5\ufe0f Glamping',
    ]),
    ('\ud83c\udf3f Naturaleza y animales', [
      '\ud83c\udf3f Naturaleza',
      '\ud83d\udc3e Animales',
      '\ud83d\udc15 Perros',
      '\ud83d\udc31 Gatos',
      '\ud83e\udd9e Senderismo',
      '\ud83c\udf3b Jardiner\u00eda',
      '\ud83c\udf0d Ecolog\u00eda',
      '\ud83e\udd85 Observaci\u00f3n de aves',
      '\ud83c\udf31 Plantas / Suculentas',
    ]),
    ('\ud83c\udfae Ocio y entretenimiento', [
      '\ud83c\udfae Videojuegos',
      '\ud83d\udcfa Series / TV',
      '\ud83c\udf8c Anime / Manga',
      '\ud83d\udcd6 C\u00f3mics',
      '\ud83c\udfac Cine',
      '\ud83c\udfb2 Juegos de mesa',
      '\ud83e\udde9 Puzzles / Rompecabezas',
      '\ud83c\udfa9 Magia',
      '\ud83c\udfad Stand-up / Comedia',
    ]),
    ('\ud83e\uddd8 Estilo de vida y bienestar', [
      '\ud83e\uddd8 Meditaci\u00f3n',
      '\ud83c\udf3f Mindfulness',
      '\ud83d\udcc8 Desarrollo personal',
      '\ud83d\udc57 Moda / Estilo',
      '\ud83d\udcf1 Tecnolog\u00eda / Gadgets',
      '\ud83d\ude80 Startups / Emprendimiento',
      '\ud83d\uddf3\ufe0f Pol\u00edtica / Actualidad',
      '\ud83d\udc5c Activismo',
      '\ud83e\udd1d Voluntariado',
      '\u267b\ufe0f Sostenibilidad',
    ]),
    ('\ud83c\udfa8 Creatividad y hobbies', [
      '\ud83d\udcf7 Fotograf\u00eda',
      '\u270d\ufe0f Escritura creativa',
      '\ud83c\udfa8 Dibujo / Ilustraci\u00f3n',
      '\ud83e\uddf6 Manualidades / DIY',
      '\ud83c\udf91 Cer\u00e1mica',
      '\ud83c\udf3b Jardiner\u00eda',
      '\ud83c\udf57 Cocina',
      '\ud83d\udc83 Baile',
    ]),
    ('\ud83d\udd2c Ciencia y conocimiento', [
      '\ud83d\udd2c Ciencia',
      '\ud83c\udf0c Astronom\u00eda',
      '\ud83d\udcdc Historia',
      '\ud83d\udcad Filosof\u00eda',
      '\ud83e\udde0 Psicolog\u00eda',
      '\ud83d\udcbb Tecnolog\u00eda',
      '\ud83e\udd16 Inteligencia artificial',
      '\u2699\ufe0f Rob\u00f3tica',
    ]),
  ];

  static const _categoriasPersonalidad = <(String, List<String>)>[
    ('Energ\u00eda social (C\u00f3mo te relacionas)', [
      '\ud83d\udde3\ufe0f Extrovertido/a',
      '\ud83e\uddd8 Introvertido/a',
      '\u2696\ufe0f Ambivertido/a',
    ]),
    ('Estilo de pensamiento', [
      '\ud83e\udde0 Racional / L\u00f3gico',
      '\u2764\ufe0f Emocional / Sentimental',
      '\ud83c\udfa8 Creativo / Imaginativo',
      '\ud83d\udd0d Anal\u00edtico / Detallista',
    ]),
    ('Actitud ante la vida', [
      '\ud83d\ude04 Divertido/a / Alegre',
      '\ud83e\udd14 Serio/a / Reflexivo/a',
      '\u26a1 Espont\u00e1neo/a / Impulsivo/a',
      '\ud83d\udccb Planificador/a / Organizado/a',
    ]),
    ('Estilo de relaci\u00f3n', [
      '\ud83e\udd17 Emp\u00e1tico/a / Comprensivo/a',
      '\ud83e\udd85 Independiente / Autosuficiente',
      '\ud83e\udd1d Leal / Fiel',
    ]),
    ('Otros rasgos', [
      '\ud83d\udd2c Curioso/a / Aprendiz',
      '\ud83c\udfc4 Aventurero/a',
      '\ud83c\udf0a Tranquilo/a / Pac\u00edfico/a',
      '\ud83c\udfc6 Competitivo/a',
    ]),
  ];

  static const _categoriasPreguntas = <(String, List<String>)>[
    ('\ud83d\udc98 Citas y romance', [
      '\u00bfCu\u00e1l es tu plan de cita ideal?',
      '\u00bfQu\u00e9 es lo que m\u00e1s valoras en una relaci\u00f3n?',
      '\u00bfCu\u00e1l es la mejor cita que has tenido?',
      '\u00bfQu\u00e9 har\u00edas en una primera cita para causar buena impresi\u00f3n?',
      '\u00bfCu\u00e1l es el gesto m\u00e1s rom\u00e1ntico que has recibido?',
      '\u00bfQu\u00e9 te hace sentir especial en una relaci\u00f3n?',
    ]),
    ('\ud83d\ude04 Humor y personalidad', [
      '\u00bfCu\u00e1l es tu mejor chiste malo?',
      '\u00bfQu\u00e9 serie o pel\u00edcula puedes ver una y otra vez?',
      '\u00bfCu\u00e1l es tu mayor man\u00eda o rareza?',
      '\u00bfQu\u00e9 es lo que nunca te esperar\u00edas de m\u00ed?',
      '\u00bfQu\u00e9 cosa vergonzosa te ha pasado en una cita?',
      '\u00bfCu\u00e1l es tu canci\u00f3n de karaoke infalible?',
    ]),
    ('\u2708\ufe0f Viajes y aventura', [
      '\u00bfCu\u00e1l es tu destino de viaje so\u00f1ado?',
      '\u00bfCu\u00e1l ha sido tu mejor viaje?',
      '\u00bfPrefieres playa o monta\u00f1a? \u00bfPor qu\u00e9?',
      '\u00bfQu\u00e9 pa\u00eds te gustar\u00eda visitar y por qu\u00e9?',
      '\u00bfCu\u00e1l es la aventura m\u00e1s loca que has hecho?',
      '\u00bfViajar\u00edas solo/a o siempre acompa\u00f1ado/a?',
    ]),
    ('\ud83c\udf54 Gastronom\u00eda y vida', [
      '\u00bfQu\u00e9 plato define tu personalidad?',
      '\u00bfCu\u00e1l es tu comida favorita para una cita?',
      '\u00bfEres m\u00e1s de cocinar o de pedir delivery?',
      '\u00bfQu\u00e9 no puede faltar en tu nevera?',
      '\u00bfCu\u00e1l es tu restaurante favorito y por qu\u00e9?',
      '\u00bfQu\u00e9 comida no soportas?',
    ]),
    ('\ud83d\udcad Reflexi\u00f3n y valores', [
      '\u00bfQu\u00e9 es lo que m\u00e1s te apasiona en la vida?',
      '\u00bfCu\u00e1l es el mejor consejo que has recibido?',
      '\u00bfQu\u00e9 har\u00edas si te tocara la loter\u00eda?',
      '\u00bfQu\u00e9 es lo que m\u00e1s te asusta de una relaci\u00f3n?',
      '\u00bfCu\u00e1l es tu mayor logro personal?',
      '\u00bfQu\u00e9 te hace feliz de verdad?',
    ]),
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    _bioCtrl.dispose();
    _profesionCtrl.dispose();
    super.dispose();
  }

  bool get _esIntro => _paso == 0;
  bool get _esBienvenida => _paso >= _totalPasos - 1;
  bool get _esUltimoPaso => _paso == _totalPasos - 2;
  bool get _mostrarAtras => !_esIntro && !_esBienvenida && _paso > 1;
  bool get _esPregunta => !_esIntro && !_esBienvenida;

  String _comboCodigo(List<(String, String)> opciones, String seleccion) {
    if (seleccion.isEmpty) return '';
    for (final o in opciones) {
      if (o.$1 == seleccion) return o.$2;
    }
    return seleccion;
  }

  void _alternarBuscaGenero(String etiqueta) {
    setState(() {
      if (etiqueta == _etiquetaPrefieroBusca) {
        _buscaGenero..clear()..add(etiqueta);
        return;
      }
      _buscaGenero.remove(_etiquetaPrefieroBusca);
      if (etiqueta == _etiquetaTodos) {
        if (_buscaGenero.contains(_etiquetaTodos)) {
          _buscaGenero.remove(_etiquetaTodos);
          _buscaGenero.removeAll(_generosBusca);
        } else {
          _buscaGenero.add(_etiquetaTodos);
          _buscaGenero.addAll(_generosBusca);
        }
        return;
      }
      if (_buscaGenero.contains(etiqueta)) {
        _buscaGenero.remove(etiqueta);
      } else {
        _buscaGenero.add(etiqueta);
      }
      final todos = _generosBusca.every(_buscaGenero.contains);
      if (todos) {
        _buscaGenero.add(_etiquetaTodos);
      } else {
        _buscaGenero.remove(_etiquetaTodos);
      }
    });
  }

  String _valorBuscaGenero() {
    if (_buscaGenero.contains(_etiquetaPrefieroBusca)) {
      return 'prefiero_no_decirlo';
    }
    if (_buscaGenero.contains(_etiquetaTodos)) {
      return 'todos';
    }
    final etiquetas = _buscaGenero
        .map((e) => _comboCodigo(opcionesBuscaGenero, e))
        .toList();
    return etiquetas.join(',');
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
          orientacionSexual: Value(_comboCodigo(opcionesOrientacionSexual, _orientacion)),
          pendienteDeSincronizar: const Value(true),
        );
      case 5:
        return UsuariosCompanion(
          situacionSentimental: Value(_comboCodigo(opcionesSituacion, _situacion)),
          pendienteDeSincronizar: const Value(true),
        );
      case 6:
        return UsuariosCompanion(
          hijos: Value(_comboCodigo(opcionesHijos, _hijos)),
          pendienteDeSincronizar: const Value(true),
        );
      case 7:
        return UsuariosCompanion(
          religion: Value(_comboCodigo(opcionesReligion, _religion)),
          pendienteDeSincronizar: const Value(true),
        );
      case 8:
        return UsuariosCompanion(
          educacion: Value(_comboCodigo(opcionesEducacion, _educacion)),
          pendienteDeSincronizar: const Value(true),
        );
      case 9:
        return UsuariosCompanion(
          profesion: Value(_profesionCtrl.text.trim()),
          pendienteDeSincronizar: const Value(true),
        );
      case 10:
        return UsuariosCompanion(
          trabajo: Value(_comboCodigo(opcionesTrabajo, _trabajo)),
          pendienteDeSincronizar: const Value(true),
        );
      case 11:
        return UsuariosCompanion(
          fuma: Value(_comboCodigo(opcionesTabaco, _fuma)),
          pendienteDeSincronizar: const Value(true),
        );
      case 12:
        return UsuariosCompanion(
          bebe: Value(_comboCodigo(opcionesAlcohol, _bebe)),
          pendienteDeSincronizar: const Value(true),
        );
      case 13:
        return UsuariosCompanion(
          mascotas: Value(_comboCodigo(opcionesMascotas, _mascotas)),
          pendienteDeSincronizar: const Value(true),
        );
      case 14:
        return UsuariosCompanion(
          tatuajes: Value(_comboCodigo(opcionesTatuajes, _tatuajes)),
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
          signoZodiaco: Value(_comboCodigo(opcionesSigno, _signo)),
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

  String _usadasPorOtros(int indice) {
    final usadas = <String>[];
    for (var i = 0; i < _preguntasRespondidas.length; i++) {
      if (i != indice) usadas.add(_preguntasRespondidas[i].pregunta);
    }
    return usadas.join('|');
  }

  Future<void> _elegirPregunta(int indice) async {
    final usadas = _usadasPorOtros(indice).split('|').toSet();
    final elegida = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _SelectorPregunta(
        categorias: _categoriasPreguntas,
        usadas: usadas,
      ),
    );
    if (elegida == null || !mounted) return;
    final respuesta = await _escribirRespuesta(
      pregunta: elegida,
      inicial: indice < _preguntasRespondidas.length
          ? _preguntasRespondidas[indice].respuesta
          : '',
    );
    if (respuesta == null || !mounted) return;
    setState(() {
      if (indice < _preguntasRespondidas.length) {
        _preguntasRespondidas[indice] =
            PreguntaRespuesta(pregunta: elegida, respuesta: respuesta);
      } else {
        _preguntasRespondidas.add(
            PreguntaRespuesta(pregunta: elegida, respuesta: respuesta));
      }
    });
  }

  Future<String?> _escribirRespuesta(
      {required String pregunta, required String inicial}) {
    final controller = TextEditingController(text: inicial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Tu respuesta',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pregunta,
              style: const TextStyle(
                  fontSize: 14, color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              maxLength: _maxCaracteresRespuesta,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Escribe tu respuesta...',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.black54)),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim()),
            child: const Text('Guardar',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
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
          _pasoSobreMi(primario),
          _pasoBuscaGenero(primario),
          _pasoRangoEdad(primario),
          _pasoOrientacion(primario),
          _pasoSituacion(primario),
          _pasoHijos(primario),
          _pasoReligion(primario),
          _pasoEducacion(primario),
          _pasoProfesion(primario),
          _pasoTrabajo(primario),
          _pasoFuma(primario),
          _pasoBebe(primario),
          _pasoMascotas(primario),
          _pasoTatuajes(primario),
          _pasoPersonalidad(primario),
          _pasoEstatura(primario),
          _pasoSigno(primario),
          _pasoIdiomas(primario),
          _pasoIntereses(primario),
          _pasoPreguntas(primario),
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

  Widget _selectorChips(List<String> opciones, String valor, ValueChanged<String> onChanged, Color primario) {
    final bgClaro = primario.withValues(alpha: 0.08);
    return SingleChildScrollView(
      child: Wrap(
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
    );
  }

  Widget _selectorMultiChip(List<String> opciones, Set<String> seleccionados, Color primario,
      {ValueChanged<String>? onToggle}) {
    final bgClaro = primario.withValues(alpha: 0.08);
    return SingleChildScrollView(
      child: Wrap(
        spacing: 8,
        runSpacing: 10,
        children: opciones.map((o) {
          final selected = seleccionados.contains(o);
          return GestureDetector(
            onTap: () => onToggle != null ? onToggle(o) : setState(() {
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

  Widget _selectorCategorias(List<(String, List<String>)> categorias, Set<String> seleccionadas, Color primario) {
    final bgClaro = primario.withValues(alpha: 0.08);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final categoria in categorias) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                categoria.$1,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600]),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: categoria.$2.map((o) {
                final selected = seleccionadas.contains(o);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) { seleccionadas.remove(o); }
                    else { seleccionadas.add(o); }
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
            const SizedBox(height: 10),
          ],
        ],
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

  Widget _pasoSobreMi(Color primario) {
    return _pagina('Sobre mí', 'Escribe algo que no se vea en tu perfil.',
        TextField(
          controller: _bioCtrl,
          maxLines: 5,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Cuéntanos algo sobre ti...',
            filled: true,
            fillColor: primario.withValues(alpha: 0.05),
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

  Widget _pasoBuscaGenero(Color primario) {
    return _pagina('¿A quién te gustaría conocer?',
        'Elige las opciones que te interesen. Puedes seleccionar varias.',
        Column(
          children: [
            _selectorMultiChip(
              [for (final o in opcionesBuscaGenero) o.$1],
              _buscaGenero,
              primario,
              onToggle: _alternarBuscaGenero,
            ),
          ],
        ));
  }

  Widget _pasoRangoEdad(Color primario) {
    return _pagina('Rango de edad ideal',
        '¿Entre qué edades te gustaría que estuviera tu match?', LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            const Spacer(),
            Text(
              '${_rangoEdad.start.round()} a ${_rangoEdad.end.round()} años',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: primario),
            ),
            const SizedBox(height: 24),
            RangeSlider(
              values: _rangoEdad,
              min: 18,
              max: 99,
              divisions: 81,
              activeColor: primario,
              inactiveColor: primario.withValues(alpha: 0.2),
              labels: RangeLabels('${_rangoEdad.start.round()}', '${_rangoEdad.end.round()}'),
              onChanged: (v) => setState(() => _rangoEdad = v),
            ),
            const Spacer(),
          ],
        );
      },
    ));
  }

  Widget _pasoOrientacion(Color primario) {
    return _pagina('¿Cuál es tu orientación sexual?', 'Elige la que mejor te describa',
        _selectorChips([for (final o in opcionesOrientacionSexual) o.$1], _orientacion, (v) => setState(() => _orientacion = v), primario));
  }

  Widget _pasoSituacion(Color primario) {
    return _pagina('Cuéntanos sobre tu vida sentimental ahora mismo',
        'Esto ayuda a que te conectemos con personas compatibles.',
        _selectorChips([for (final o in opcionesSituacion) o.$1], _situacion, (v) => setState(() => _situacion = v), primario));
  }

  Widget _pasoHijos(Color primario) {
    return _pagina('¿Tienes hijos?', 'Es importante para conectar con personas compatibles.',
        _selectorChips([for (final o in opcionesHijos) o.$1], _hijos, (v) => setState(() => _hijos = v), primario));
  }

  Widget _pasoReligion(Color primario) {
    return _pagina('¿Cuál es tu religión o creencia?',
        'Compartir tus valores ayuda a conectar con personas afines.',
        _selectorChips([for (final o in opcionesReligion) o.$1], _religion, (v) => setState(() => _religion = v), primario));
  }

  Widget _pasoEducacion(Color primario) {
    return _pagina('¿Cuál es tu nivel de estudios?',
        'Esto ayuda a conectar con personas con intereses afines.',
        _selectorChips([for (final o in opcionesEducacion) o.$1], _educacion, (v) => setState(() => _educacion = v), primario));
  }

  Widget _pasoProfesion(Color primario) {
    return _pagina('¿Cuál es tu profesión?',
        'Compartir tu profesión ayuda a conectar con personas afines.',
        Column(
          children: [
            TextFormField(
              controller: _profesionCtrl,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Escribe tu profesión...',
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
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: _listaProfesiones.map((p) {
                    return GestureDetector(
                      onTap: () => setState(() => _profesionCtrl.text = p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: primario.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: primario.withValues(alpha: 0.3)),
                        ),
                        child: Text(p, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ));
  }

  Widget _pasoTrabajo(Color primario) {
    return _pagina('¿En qué sector trabajas?',
        'Ayuda a conocer un poco más sobre tu día a día.',
        _selectorChips([for (final o in opcionesTrabajo) o.$1], _trabajo, (v) => setState(() => _trabajo = v), primario));
  }

  Widget _pasoFuma(Color primario) {
    return _pagina('¿Fumas?', 'Ayuda a conectar con personas con hábitos similares.',
        _selectorChips([for (final o in opcionesTabaco) o.$1], _fuma, (v) => setState(() => _fuma = v), primario));
  }

  Widget _pasoBebe(Color primario) {
    return _pagina('¿Bebes alcohol?', 'Ayuda a conectar con personas con hábitos similares.',
        _selectorChips([for (final o in opcionesAlcohol) o.$1], _bebe, (v) => setState(() => _bebe = v), primario));
  }

  Widget _pasoMascotas(Color primario) {
    return _pagina('¿Tienes mascotas?', 'Compartir el amor por los animales siempre suma.',
        _selectorChips([for (final o in opcionesMascotas) o.$1], _mascotas, (v) => setState(() => _mascotas = v), primario));
  }

  Widget _pasoTatuajes(Color primario) {
    return _pagina('¿Tienes tatuajes?', 'El arte en la piel dice mucho sobre ti.',
        _selectorChips([for (final o in opcionesTatuajes) o.$1], _tatuajes, (v) => setState(() => _tatuajes = v), primario));
  }

  Widget _pasoPersonalidad(Color primario) {
    return _pagina('¿Cómo describirías tu personalidad?',
        'Elige hasta 3 opciones que mejor te definan.',
        _selectorCategorias(_categoriasPersonalidad, _personalidad, primario));
  }

  Widget _pasoEstatura(Color primario) {
    return _pagina('¿Cuál es tu estatura?', 'Elige tu estatura', LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            const Spacer(),
            Text(
              _prefieroNoDecirAltura
                  ? 'Prefiero no decirlo'
                  : '${_alturaCm.round()} cm',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: primario),
            ),
            const SizedBox(height: 24),
            Slider(
              value: _prefieroNoDecirAltura ? 175 : _alturaCm,
              min: 130,
              max: 230,
              divisions: 100,
              activeColor: primario,
              inactiveColor: primario.withValues(alpha: 0.2),
              onChanged: (v) => setState(() {
                _alturaCm = v;
                _prefieroNoDecirAltura = false;
              }),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => setState(() => _prefieroNoDecirAltura = !_prefieroNoDecirAltura),
              icon: Icon(
                _prefieroNoDecirAltura
                    ? Icons.check_box_outlined
                    : Icons.check_box_outline_blank,
                size: 20,
                color: primario,
              ),
              label: Text(
                'Prefiero no decirlo',
                style: TextStyle(fontSize: 14, color: primario),
              ),
            ),
            const Spacer(),
          ],
        );
      },
    ));
  }

  Widget _pasoSigno(Color primario) {
    return _pagina('¿Cuál es tu signo del zodíaco?',
        'Un dato divertido para conectar con personas afines.',
        _selectorChips([for (final o in opcionesSigno) o.$1], _signo, (v) => setState(() => _signo = v), primario));
  }

  Widget _pasoIdiomas(Color primario) {
    return _pagina('¿Qué idiomas hablas?',
        'Compartir idiomas ayuda a conectar con personas de todo el mundo.',
        _selectorMultiChip(_idiomasDisponibles, _idiomas, primario));
  }

  Widget _pasoIntereses(Color primario) {
    return _pagina('Tus intereses',
        'Elige hasta 10 intereses para conectar con personas afines.',
        _selectorCategorias(_categoriasIntereses, _intereses, primario));
  }

  Widget _pasoPreguntas(Color primario) {
    return _pagina('Preguntas para conocerte mejor',
        'Responde 3 preguntas para que la gente sepa cómo eres realmente.',
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < _preguntasRespondidas.length; i++)
                _tarjetaPregunta(primario, i),
              if (_preguntasRespondidas.length < _maxPreguntas)
                _tarjetaAnadirPregunta(primario, _preguntasRespondidas.length),
            ],
          ),
        ));
  }

  Widget _tarjetaPregunta(Color primario, int indice) {
    final item = _preguntasRespondidas[indice];
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primario.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pregunta ${indice + 1}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: primario),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _preguntasRespondidas.removeAt(indice);
                  });
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: Colors.redAccent,
                ),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Quitar',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          Text(
            item.pregunta,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                height: 1.35),
          ),
          const SizedBox(height: 8),
          Text(
            item.respuesta.isEmpty
                ? 'Sin responder aún'
                : item.respuesta,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: item.respuesta.isEmpty
                  ? Colors.grey[400]
                  : Colors.black54,
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              final respuesta = await _escribirRespuesta(
                pregunta: item.pregunta,
                inicial: item.respuesta,
              );
              if (respuesta == null || !mounted) return;
              setState(() {
                _preguntasRespondidas[indice] = PreguntaRespuesta(
                    pregunta: item.pregunta, respuesta: respuesta);
              });
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: primario,
            ),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Editar respuesta',
                style:
                    TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaAnadirPregunta(Color primario, int indice) {
    return InkWell(
      onTap: () => _elegirPregunta(indice),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: primario.withValues(alpha: 0.5)),
          color: primario.withValues(alpha: 0.05),
        ),
        child: Column(
          children: [
            Icon(Icons.add_circle_outline, color: primario, size: 28),
            const SizedBox(height: 6),
            Text(
              'Añadir pregunta',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: primario),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectorPregunta extends StatelessWidget {
  final List<(String, List<String>)> categorias;
  final Set<String> usadas;

  const _SelectorPregunta({required this.categorias, required this.usadas});

  @override
  Widget build(BuildContext context) {
    const primario = FlumiTema.colorPrimario;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                'Elige una pregunta',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Las preguntas ya usadas no se muestran.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  for (final categoria in categorias) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        categoria.$1,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: primario,
                        ),
                      ),
                    ),
                    for (final pregunta in categoria.$2)
                      if (!usadas.contains(pregunta))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            pregunta,
                            style: const TextStyle(
                                fontSize: 14, color: Colors.black87),
                          ),
                          trailing: Icon(Icons.chevron_right,
                              color: Colors.grey[400], size: 20),
                          onTap: () => Navigator.pop(context, pregunta),
                        ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
