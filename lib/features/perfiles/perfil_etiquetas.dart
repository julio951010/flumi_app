typedef OpcionEtiqueta = (String, String);

const opcionesBuscaGenero = <OpcionEtiqueta>[
  ('\ud83d\udc68 Hombres', 'hombres'),
  ('\ud83d\udc69 Mujeres', 'mujeres'),
  ('\u26a7\ufe0f Personas no binarias', 'no_binarias'),
  ('\ud83c\udf08 Todos/as', 'todos'),
  ('\ud83d\ude48 Prefiero no decirlo', 'prefiero_no_decirlo'),
];

const opcionesGenero = <String>[
  'Mujer',
  'Hombre',
  'Mujer trans',
  'Hombre trans',
  'No binario',
  'G\u00e9nero fluido',
];

const opcionesQueBusca = <OpcionEtiqueta>[
  ('\u2764\ufe0f Busco una relaci\u00f3n estable', 'relacion'),
  ('\ud83d\udd25 Busco algo casual / sin compromiso', 'casual'),
  ('\ud83d\udcac Busco amistad / conocer gente', 'amistad'),
  ('\ud83c\udf31 Abierto a lo que surja', 'abierto_a_lo_que_surja'),
];

const opcionesOrientacionSexual = <OpcionEtiqueta>[
  ('Heterosexual', 'heterosexual'),
  ('Gay', 'gay'),
  ('Lesbiana', 'lesbiana'),
  ('Bisexual', 'bisexual'),
  ('Pansexual', 'pansexual'),
  ('Asexual', 'asexual'),
  ('Queer', 'queer'),
  ('Prefiero no decirlo', 'prefiero no decirlo'),
];

const opcionesSituacion = <OpcionEtiqueta>[
  ('\ud83d\udc9a Soltero/a', 'soltero'),
  ('\ud83d\udc94 Separado/a', 'separado'),
  ('\ud83d\udd4a\ufe0f En una relaci\u00f3n abierta', 'en_relacion_abierta'),
  ('\ud83c\udf39 Viudo/a', 'viudo'),
  ('\ud83c\udf00 Es complicado', 'complicado'),
  ('\ud83e\udd10 Prefiero no decirlo', 'prefiero_no_decirlo'),
];

const opcionesEducacion = <OpcionEtiqueta>[
  ('\ud83d\udcda Educaci\u00f3n primaria', 'primaria'),
  ('\ud83d\udcd6 Educaci\u00f3n secundaria / Bachillerato', 'secundaria'),
  ('\ud83d\udee0\ufe0f Formaci\u00f3n profesional / Ciclo formativo',
      'formacion_profesional'),
  ('\ud83c\udf93 Universidad (Grado / Licenciatura)', 'universidad'),
  ('\ud83c\udf93 Postgrado / M\u00e1ster / Doctorado', 'posgrado'),
  ('\ud83d\ude48 Prefiero no decirlo', 'prefiero_no_decirlo'),
];

const opcionesTrabajo = <OpcionEtiqueta>[
  ('\ud83c\udfe2 Sector privado', 'sector_privado'),
  ('\ud83c\udfdb\ufe0f Sector p\u00fablico', 'sector_publico'),
  ('\ud83d\udcbb Trabajo independiente', 'independiente'),
  ('\ud83d\udcbc Emprendedor', 'emprendedor'),
  ('\ud83c\udfe0 Ama de casa', 'ama_de_casa'),
  ('\ud83d\udcda Estudiante', 'estudiante'),
  ('\ud83c\udf05 Jubilado', 'jubilado'),
  ('\ud83d\udd0d Buscando trabajo', 'buscando_trabajo'),
  ('\ud83d\ude48 Prefiero no decirlo', 'prefiero_no_decirlo'),
];

const opcionesHijos = <OpcionEtiqueta>[
  ('\u274c No quiero tener hijos', 'no_quiero'),
  ('\ud83e\udd30 Me gustar\u00eda tener hijos', 'quiero'),
  ('\ud83d\udc68\u200d\ud83d\udc66 Ya tengo hijos y no quiero m\u00e1s',
      'tengo_no_mas'),
  ('\ud83d\udc68\u200d\ud83d\udc67\u200d\ud83d\udc66 Ya tengo hijos y me gustar\u00eda tener m\u00e1s',
      'tengo_mas'),
  ('\ud83e\uddd1\u200d\ud83e\uddb3 Ya tengo hijos y son adultos',
      'tengo_adultos'),
  ('\ud83e\udd14 No estoy seguro/a de querer hijos', 'no_se'),
  ('\ud83d\ude48 Prefiero no decirlo', 'prefiero_no_decirlo'),
];

const opcionesTabaco = <OpcionEtiqueta>[
  ('\ud83d\udead No fumo', 'no_fumo'),
  ('\ud83d\udeac Fumo socialmente', 'fumo_social'),
  ('\ud83d\udeac Fumo a diario', 'fumo_diario'),
  ('\ud83d\udead Dej\u00e9 de fumar', 'deje_de_fumar'),
  ('\ud83d\udead Estoy dejando de fumar', 'dejando_de_fumar'),
  ('\ud83d\ude48 Prefiero no decirlo', 'prefiero_no_decirlo'),
];

const opcionesAlcohol = <OpcionEtiqueta>[
  ('\ud83d\udeab\ud83c\udf77 No bebo', 'no_bebo'),
  ('\ud83c\udf77 Bebo socialmente', 'bebo_social'),
  ('\ud83c\udf7a Bebo con moderaci\u00f3n', 'bebo_moderacion'),
  ('\ud83d\ude48 Prefiero no decirlo', 'prefiero_no_decirlo'),
];

const opcionesSigno = <OpcionEtiqueta>[
  ('\u2648 Aries', 'aries'),
  ('\u2649 Tauro', 'tauro'),
  ('\u264a G\u00e9minis', 'geminis'),
  ('\u264b C\u00e1ncer', 'cancer'),
  ('\u264c Leo', 'leo'),
  ('\u264d Virgo', 'virgo'),
  ('\u264e Libra', 'libra'),
  ('\u264f Escorpio', 'escorpio'),
  ('\u2650 Sagitario', 'sagitario'),
  ('\u2651 Capricornio', 'capricornio'),
  ('\u2652 Acuario', 'acuario'),
  ('\u2653 Piscis', 'piscis'),
];

const opcionesMascotas = <OpcionEtiqueta>[
  ('\ud83d\udc15 Tengo perro(s)', 'perro'),
  ('\ud83d\udc08 Tengo gato(s)', 'gato'),
  ('\ud83d\udc15\ud83d\udc08 Tengo perros y gatos', 'perros_gatos'),
  ('\u2764\ufe0f No tengo mascotas pero me encantan', 'no_tengo_encantan'),
  ('\ud83d\udeab No tengo mascotas y no quiero', 'no_tengo_no_quiero'),
  ('\ud83d\ude48 Prefiero no decirlo', 'prefiero_no_decirlo'),
];

const opcionesReligion = <OpcionEtiqueta>[
  ('\u26ea Cat\u00f3lica', 'catolica'),
  ('\u271d\ufe0f Cristiana', 'cristiana'),
  ('\u2721\ufe0f Jud\u00eda', 'judia'),
  ('\u262a\ufe0f Musulmana', 'musulmana'),
  ('\u2638\ufe0f Budista', 'budista'),
  ('\ud83d\udd49\ufe0f Hind\u00fa', 'hindu'),
  ('\ud83c\udf3f Espiritual pero no religioso/a', 'espiritual'),
  ('\ud83e\udd14 Agn\u00f3stico/a', 'agnostico'),
  ('\ud83d\udeab\u271d\ufe0f Ateo/a', 'ateo'),
  ('\ud83d\ude48 Prefiero no decirlo', 'prefiero_no_decirlo'),
];

const opcionesTatuajes = <OpcionEtiqueta>[
  ('No tengo tatuajes', 'no_tengo'),
  ('Tengo alg\u00fan tatuaje', 'tengo_alguno'),
  ('Tengo varios tatuajes', 'tengo_varios'),
  ('Me encantar\u00eda hacerme un tatuaje', 'me_gustaria'),
  ('Prefiero no decirlo', 'prefiero_no_decirlo'),
];

const _personalidadLegacy = {
  'extrovertida': '\ud83d\udde3\ufe0f Extrovertido/a',
  'introvertida': '\ud83e\uddd8 Introvertido/a',
  'ambas': '\u2696\ufe0f Ambivertido/a',
  'creativa': '\ud83c\udfa8 Creativo / Imaginativo',
  'empatica': '\ud83e\udd17 Emp\u00e1tico/a / Comprensivo/a',
  'divertida': '\ud83d\ude04 Divertido/a / Alegre',
};

List<String> listaPersonalidad(String valor) {
  if (valor.trim().isEmpty) return const [];
  final partes = valor
      .split(',')
      .map((p) => _personalidadLegacy[p.trim()] ?? p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  return partes;
}

String textoPersonalidad(String valor) {
  final partes = listaPersonalidad(valor);
  return partes.isEmpty ? 'Sin definir' : partes.join(', ');
}

String opcionTexto(List<OpcionEtiqueta> opciones, String valor) {
  if (valor.isEmpty) return 'Sin definir';
  for (final o in opciones) {
    if (o.$2 == valor) return o.$1;
  }
  return valor;
}

String alturaTexto(String valor) {
  final s = valor.trim();
  if (s.isEmpty) return 'Sin definir';
  if (s.toLowerCase() == 'prefiero no decirlo') {
    return '\ud83d\ude48 Prefiero no decirlo';
  }
  final pies = RegExp(r"(\d+)\s*'\s*(\d+)").firstMatch(s);
  if (pies != null) {
    final cm =
        (int.parse(pies.group(1)!) * 12 + int.parse(pies.group(2)!)) * 2.54;
    return '${cm.round()} cm';
  }
  final num = double.tryParse(s.replaceAll(',', '.'));
  if (num == null) return s;
  if (num < 5) return '${(num * 100).round()} cm';
  return '${num.round()} cm';
}

String signoTexto(String valor) {
  return valor == 'prefiero_no_decirlo' && valor.isNotEmpty
      ? '\ud83d\ude48 Prefiero no decirlo'
      : opcionTexto(opcionesSigno, valor);
}

const _orientacionesLegacy = {
  'homosexual': 'Gay',
  'otro': 'Otro',
  'no_comparto': 'Prefiero no decirlo',
};

String orientacionTexto(String valor) {
  if (valor.isEmpty) return 'Sin definir';
  return _orientacionesLegacy[valor] ??
      opcionTexto(opcionesOrientacionSexual, valor);
}

const _situacionesLegacy = {
  'en_relacion': '\ud83d\udc93 En una relaci\u00f3n',
  'abierto': 'Abierto/a',
};

String situacionTexto(String valor) {
  if (valor.isEmpty) return 'Sin definir';
  return _situacionesLegacy[valor] ?? opcionTexto(opcionesSituacion, valor);
}

const _educacionesLegacy = {
  'bachillerato': '\ud83d\udcd6 Educaci\u00f3n secundaria / Bachillerato',
  'en_curso': '\ud83c\udf93 Universidad (Grado / Licenciatura)',
};

String educacionTexto(String valor) {
  if (valor.isEmpty) return 'Sin definir';
  return _educacionesLegacy[valor] ?? opcionTexto(opcionesEducacion, valor);
}

String trabajoTexto(String valor) {
  if (valor.isEmpty) return 'Sin definir';
  return opcionTexto(opcionesTrabajo, valor);
}

const _hijosLegacy = {
  'si': '\ud83d\udc68\u200d\ud83d\udc66 Ya tengo hijos y no quiero m\u00e1s',
  'no': '\u274c No quiero tener hijos',
};

String hijosTexto(String valor) {
  if (valor.isEmpty) return 'Sin definir';
  return _hijosLegacy[valor] ?? opcionTexto(opcionesHijos, valor);
}

const _tabacoLegacy = {
  'no': '\ud83d\udead No fumo',
  'social': '\ud83d\udeac Fumo socialmente',
  'si': '\ud83d\udeac Fumo a diario',
};

String tabacoTexto(String valor) {
  if (valor.isEmpty) return 'Sin definir';
  return _tabacoLegacy[valor] ?? opcionTexto(opcionesTabaco, valor);
}

const _alcoholLegacy = {
  'no': '\ud83d\udeab\ud83c\udf77 No bebo',
  'social': '\ud83c\udf77 Bebo socialmente',
  'si': '\ud83c\udf7a Bebo con moderaci\u00f3n',
};

String alcoholTexto(String valor) {
  if (valor.isEmpty) return 'Sin definir';
  return _alcoholLegacy[valor] ?? opcionTexto(opcionesAlcohol, valor);
}

const _mascotasLegacy = {
  'ave': 'Otras mascotas',
  'otro': 'Otras mascotas',
  'otras': 'Otras mascotas',
  'ninguna': '\ud83d\udeab No tengo mascotas y no quiero',
};

String mascotasTexto(String valor) {
  if (valor.isEmpty) return 'Sin definir';
  return _mascotasLegacy[valor] ?? opcionTexto(opcionesMascotas, valor);
}

const _religionLegacy = {
  'otra': 'Otra',
};

String religionTexto(String valor) {
  if (valor.isEmpty) return 'Sin definir';
  return _religionLegacy[valor] ?? opcionTexto(opcionesReligion, valor);
}

const _tatuajesLegacy = {
  'si': 'Tengo alg\u00fan tatuaje',
  'no': 'No tengo tatuajes',
};

String tatuajesTexto(String valor) {
  if (valor.isEmpty) return 'Sin definir';
  return _tatuajesLegacy[valor] ?? opcionTexto(opcionesTatuajes, valor);
}

const _buscaGeneroLegacy = {
  'hombre': '\ud83d\udc68 Hombres',
  'mujer': '\ud83d\udc69 Mujeres',
  'ambos': '\ud83c\udf08 Todos/as',
  'otro': '\ud83d\ude48 Prefiero no decirlo',
};

String buscaGeneroTexto(String valor) {
  if (valor.isEmpty) return 'Sin definir';
  final etiquetas = valor
      .split(',')
      .map((c) => c.trim())
      .where((c) => c.isNotEmpty)
      .map((c) => _buscaGeneroLegacy[c] ??
          opcionTexto(opcionesBuscaGenero, c))
      .toList();
  return etiquetas.join(' \u00b7 ');
}

String rangoEdadTexto(int min, int max) {
  if (min == 18 && max == 99) return 'Sin definir';
  return '$min a $max a\u00f1os';
}

String fechaTexto(DateTime? f) {
  if (f == null) return 'Sin definir';
  return '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
}

String capitalizar(String v) {
  if (v.isEmpty) return '';
  return v[0].toUpperCase() + v.substring(1);
}

String valorTexto(String v) => v.trim().isEmpty ? 'Sin definir' : v;

const categoriasIntereses = <(String, List<String>)>[
  ('🏃 Deportes y actividad física', [
    '⚽ Fútbol',
    '🏀 Baloncesto',
    '🎾 Tenis',
    '🏸 Pádel',
    '⛳ Golf',
    '🏃 Running / Atletismo',
    '🏊 Natación',
    '🚴 Ciclismo',
    '🥾 Senderismo / Montaña',
    '🧗 Escalada',
    '🏄 Surf',
    '🎿 Snowboard / Esquí',
    '🧘 Yoga',
    '🧘‍♀️ Pilates',
    '💪 CrossFit',
    '🏋️ Gimnasio / Fitness',
    '🥋 Artes marciales',
    '🥊 Boxeo',
    '⛸️ Patinaje',
    '🏐 Voleibol',
    '🏉 Rugby',
    '⚾ Béisbol',
  ]),
  ('🎨 Arte y cultura', [
    '🎬 Cine',
    '🎭 Teatro',
    '🏛️ Museos',
    '🎨 Pintura',
    '✏️ Dibujo',
    '🗿 Escultura',
    '📷 Fotografía',
    '📚 Literatura / Lectura',
    '📝 Poesía',
    '✍️ Escritura',
    '💃 Danza',
    '🩰 Ballet',
    '🎻 Música clásica',
    '🎵 Ópera',
  ]),
  ('🎵 Música', [
    '🎸 Rock',
    '🎤 Pop',
    '🎵 Reggaetón',
    '🇰🇷 K-pop',
    '🎷 Jazz',
    '🎛️ Música electrónica',
    '🎶 Indie',
    '💃 Salsa',
    '🎵 Bachata',
    '🤘 Metal',
    '🎤 Hip-hop / Rap',
    '🤠 Country',
    '💃 Flamenco',
    '🎵 Tango',
    '🎤 Cantar / Karaoke',
    '🎹 Tocar un instrumento',
  ]),
  ('🍽️ Gastronomía', [
    '🍳 Cocina / Repostería',
    '🍽️ Gastronomía',
    '🍷 Vino / Enología',
    '🍺 Cerveza artesanal',
    '☕ Café / Cafeterías',
    '🌱 Comida vegana / Vegetariana',
    '🍣 Comida asiática',
    '🍝 Comida italiana',
    '🌮 Comida mexicana',
    '🥩 Parrillas / Barbacoa',
    '🧀 Quesos / Catas',
    '🍜 Restaurantes / Foodie',
  ]),
  ('✈️ Viajes y aventura', [
    '✈️ Viajar',
    '🎒 Mochilero / Backpacker',
    '🏡 Turismo rural',
    '🏙️ Ciudades europeas',
    '🏖️ Playas / Mar',
    '🚢 Cruceros',
    '🚗 Viajes en carretera',
    '📸 Fotografía de viaje',
    '⛺ Acampar / Camping',
    '🏕️ Glamping',
  ]),
  ('🌿 Naturaleza y animales', [
    '🌿 Naturaleza',
    '🐾 Animales',
    '🐕 Perros',
    '🐈 Gatos',
    '🥾 Senderismo',
    '🌻 Jardinería',
    '🌍 Ecología',
    '🦅 Observación de aves',
    '🌱 Plantas / Suculentas',
  ]),
  ('🎮 Ocio y entretenimiento', [
    '🎮 Videojuegos',
    '📺 Series / TV',
    '🎌 Anime / Manga',
    '📖 Cómics',
    '🎬 Cine',
    '🎲 Juegos de mesa',
    '🧩 Puzzles / Rompecabezas',
    '🎩 Magia',
    '🎭 Stand-up / Comedia',
  ]),
  ('🧘 Estilo de vida y bienestar', [
    '🧘 Meditación',
    '🌿 Mindfulness',
    '📈 Desarrollo personal',
    '👗 Moda / Estilo',
    '📱 Tecnología / Gadgets',
    '🚀 Startups / Emprendimiento',
    '🗳️ Política / Actualidad',
    '✊ Activismo',
    '🤝 Voluntariado',
    '♻️ Sostenibilidad',
  ]),
  ('🎨 Creatividad y hobbies', [
    '📷 Fotografía',
    '✍️ Escritura creativa',
    '🎨 Dibujo / Ilustración',
    '🧶 Manualidades / DIY',
    '🏺 Cerámica',
    '🌻 Jardinería',
    '🍳 Cocina',
    '💃 Baile',
  ]),
  ('🔬 Ciencia y conocimiento', [
    '🔬 Ciencia',
    '🌌 Astronomía',
    '📜 Historia',
    '💭 Filosofía',
    '🧠 Psicología',
    '💻 Tecnología',
    '🤖 Inteligencia artificial',
    '⚙️ Robótica',
  ]),
];

const categoriasPersonalidad = <(String, List<String>)>[
  ('Energía social (Cómo te relacionas)', [
    '🗣️ Extrovertido/a',
    '🧘 Introvertido/a',
    '⚖️ Ambivertido/a',
  ]),
  ('Estilo de pensamiento', [
    '🧠 Racional / Lógico',
    '❤️ Emocional / Sentimental',
    '🎨 Creativo / Imaginativo',
    '🔍 Analítico / Detallista',
  ]),
  ('Actitud ante la vida', [
    '😄 Divertido/a / Alegre',
    '🤔 Serio/a / Reflexivo/a',
    '⚡ Espontáneo/a / Impulsivo/a',
    '🗂 Planificador/a / Organizado/a',
  ]),
  ('Estilo de relación', [
    '🤗 Empático/a / Comprensivo/a',
    '🤔 Independiente / Autosuficiente',
    '🤝 Leal / Fiel',
  ]),
  ('Otros rasgos', [
    '💬 Curioso/a / Aprendiz',
    '🌊 Aventurero/a',
    '🌊 Tranquilo/a / Pacífico/a',
    '👑 Competitivo/a',
  ]),
];

const idiomasDisponibles = <String>[
  'Español', 'Inglés', 'Francés', 'Alemán', 'Italiano',
  'Portugués', 'Catalán', 'Euskera', 'Gallego', 'Valenciano',
  'Árabe', 'Chino', 'Japonés', 'Coreano', 'Ruso', 'Hindi',
  'Neerlandés', 'Griego', 'Turco', 'Sueco', 'Noruego', 'Danés',
  'Polaco', 'Hebreo', 'Filipino', 'Vietnamita', 'Tailandés',
  'Ucraniano', 'Checo', 'Rumano', 'Húngaro', 'Persa', 'Suajili',
];

const listaProfesiones = <String>[
  'Médico/a', 'Enfermero/a', 'Psicólogo/a', 'Fisioterapeuta',
  'Nutricionista', 'Dentista', 'Veterinario/a', 'Farmacéutico/a',
  'Profesor/a', 'Maestro/a', 'Educador/a social', 'Pedagogo/a',
  'Investigador/a', 'Ingeniero/a informático/a', 'Desarrollador/a',
  'Programador/a', 'Diseñador/a UX/UI', 'Analista de datos',
  'Científico/a de datos', 'Product Manager', 'Scrum Master',
  'Arquitecto/a', 'Diseñador/a gráfico/a', 'Diseñador/a de interiores',
  'Artista plástico/a', 'Ilustrador/a', 'Fotógrafo/a', 'Músico/a',
  'Actor/Actriz', 'Escritor/a', 'Periodista', 'Creador/a de contenido',
  'Abogado/a', 'Economista', 'Contador/a', 'Asesor/a financiero/a',
  'Consultor/a', 'Director/a ejecutivo/a', 'Administrador/a de empresas',
  'Recursos humanos', 'Comercial', 'Marketing',
  'Ingeniero/a civil', 'Ingeniero/a industrial', 'Ingeniero/a mecánico/a',
  'Ingeniero/a eléctrico/a', 'Ingeniero/a químico/a',
  'Chef', 'Cocinero/a', 'Camarero/a', 'Recepcionista',
  'Gestor/a de hoteles', 'Guía turístico/a', 'Azafato/a de vuelo',
  'Estudiante', 'Ama de casa', 'Cuidador/a', 'Militar', 'Policía',
  'Bombero/a', 'Conductor/a', 'Transportista', 'Jubilado/a',
  'Empresario/a', 'Emprendedor/a', 'Tatuador/a',
];

const categoriasPreguntas = <(String, List<String>)>[
  ('💘 Citas y romance', [
    '¿Cuál es tu plan de cita ideal?',
    '¿Qué es lo que más valoras en una relación?',
    '¿Cuál es la mejor cita que has tenido?',
    '¿Qué harías en una primera cita para causar buena impresión?',
    '¿Cuál es el gesto más romántico que has recibido?',
    '¿Qué te hace sentir especial en una relación?',
  ]),
  ('😄 Humor y personalidad', [
    '¿Cuál es tu mejor chiste malo?',
    '¿Qué serie o película puedes ver una y otra vez?',
    '¿Cuál es tu mayor manía o rareza?',
    '¿Qué es lo que nunca te esperarías de mí?',
    '¿Qué cosa vergonzosa te ha pasado en una cita?',
    '¿Cuál es tu canción de karaoke infalible?',
  ]),
  ('✈️ Viajes y aventura', [
    '¿Cuál es tu destino de viaje soñado?',
    '¿Cuál ha sido tu mejor viaje?',
    '¿Prefieres playa o montaña? ¿Por qué?',
    '¿Qué país te gustaría visitar y por qué?',
    '¿Cuál es la aventura más loca que has hecho?',
    '¿Viajarías solo/a o siempre acompañado/a?',
  ]),
  ('🍽️ Gastronomía y vida', [
    '¿Qué plato define tu personalidad?',
    '¿Cuál es tu comida favorita para una cita?',
    '¿Eres más de cocinar o de pedir delivery?',
    '¿Qué no puede faltar en tu nevera?',
    '¿Cuál es tu restaurante favorito y por qué?',
    '¿Qué comida no soportas?',
  ]),
  ('💭 Reflexión y valores', [
    '¿Qué es lo que más te apasiona en la vida?',
    '¿Cuál es el mejor consejo que has recibido?',
    '¿Qué harías si te tocara la lotería?',
    '¿Qué es lo que más te asusta de una relación?',
    '¿Cuál es tu mayor logro personal?',
    '¿Qué te hace feliz de verdad?',
  ]),
];