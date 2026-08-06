import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../base_datos_local/database.dart';

const _uuid = Uuid();

const _carpetaFotosPrueba =
    'C:/_Proyectos_Flutter/flumi_app/test/features/perfiles';

const _assetFotosPrueba = 'assets/fotos_prueba';

const _carpetasPrueba = [
  'Alice',
  'Bob',
  'Carla',
  'David',
  'Elena',
  'Julio Cesar',
];

String _normalizar(String s) {
  const conAcentos = 'áéíóúüñ';
  const sinAcentos = 'aeiouun';
  final b = StringBuffer();
  for (final ch in s.trim().toLowerCase().split('')) {
    final i = conAcentos.indexOf(ch);
    b.write(i >= 0 ? sinAcentos[i] : ch);
  }
  return b.toString();
}

Future<String> _resolverCarpeta(String nombre) async {
  final dirLocal = Directory(_carpetaFotosPrueba);
  if (dirLocal.existsSync()) {
    final carpetas = dirLocal
        .listSync(followLinks: false)
        .whereType<Directory>()
        .map((d) => d.path.split(Platform.pathSeparator).last)
        .toList();
    final n = _normalizar(nombre);
    for (final c in carpetas) {
      if (_normalizar(c) == n) return c;
    }
    if (carpetas.isNotEmpty) return carpetas.first;
    return '';
  }
  final n = _normalizar(nombre);
  for (final c in _carpetasPrueba) {
    if (_normalizar(c) == n) return c;
  }
  return _carpetasPrueba.first;
}

Future<List<String>> _fotosPrueba(String nombre) async {
  final carpeta = await _resolverCarpeta(nombre);
  if (carpeta.isEmpty) return const [];
  final dirLocal = Directory('$_carpetaFotosPrueba/$carpeta');
  if (dirLocal.existsSync()) {
    return [
      for (var i = 1; i <= 4; i++)
        if (File('${dirLocal.path}/imagen$i.png').existsSync())
          '${dirLocal.path}/imagen$i.png',
    ];
  }
  final docs = await getApplicationDocumentsDirectory();
  final dirDestino = Directory('${docs.path}/fotos_prueba/$carpeta');
  final rutas = <String>[];
  for (var i = 1; i <= 4; i++) {
    final destino = File('${dirDestino.path}/imagen$i.png');
    if (!destino.existsSync()) {
      try {
        final datos = await rootBundle.load(
            '$_assetFotosPrueba/${Uri.encodeComponent(carpeta)}/imagen$i.png');
        await dirDestino.create(recursive: true);
        await destino.writeAsBytes(datos.buffer.asUint8List(), flush: true);
      } catch (_) {
        continue;
      }
    }
    rutas.add(destino.path);
  }
  return rutas;
}

class InteraccionMock {
  final String usuarioId;
  final DateTime timestamp;
  InteraccionMock({required this.usuarioId, required this.timestamp});
}

class GeneradorMock {
  static List<InteraccionMock> obtenerLikesRecibidos() {
    final ids = _mockUsuarios.map((u) => u.uuid.value).toList();
    return [
      InteraccionMock(
          usuarioId: ids[0],
          timestamp: DateTime.now().subtract(const Duration(minutes: 10))),
      InteraccionMock(
          usuarioId: ids[1],
          timestamp: DateTime.now().subtract(const Duration(hours: 2))),
      InteraccionMock(
          usuarioId: ids[2],
          timestamp: DateTime.now().subtract(const Duration(days: 1))),
      InteraccionMock(
          usuarioId: ids[3],
          timestamp: DateTime.now().subtract(const Duration(days: 3))),
    ];
  }

  static List<InteraccionMock> obtenerVisitas() {
    final ids = _mockUsuarios.map((u) => u.uuid.value).toList();
    return [
      InteraccionMock(
          usuarioId: ids[4],
          timestamp: DateTime.now().subtract(const Duration(minutes: 5))),
      InteraccionMock(
          usuarioId: ids[0],
          timestamp: DateTime.now().subtract(const Duration(hours: 1))),
      InteraccionMock(
          usuarioId: ids[3],
          timestamp: DateTime.now().subtract(const Duration(days: 1))),
    ];
  }

  static List<InteraccionMock> obtenerMisLikes() {
    final ids = _mockUsuarios.map((u) => u.uuid.value).toList();
    return [
      InteraccionMock(
          usuarioId: ids[0],
          timestamp: DateTime.now().subtract(const Duration(days: 2))),
      InteraccionMock(
          usuarioId: ids[4],
          timestamp: DateTime.now().subtract(const Duration(days: 1))),
    ];
  }

  static Future<void> sembrarSiVacio(AppDatabase db) async {
    final idsMock = _mockUsuarios.map((u) => u.uuid.value).toSet();
    final todos = await (db.select(db.usuarios)).get();

    final hayPropio = todos.any((u) => u.esPerfilPropio);
    final mockExistentes =
        todos.where((u) => idsMock.contains(u.uuid)).toList();

    for (final m in mockExistentes) {
      await (db.delete(db.usuarios)..where((u) => u.uuid.equals(m.uuid))).go();
    }

    if (!hayPropio) {
      final noMock = todos.where((u) => !idsMock.contains(u.uuid));
      for (final n in noMock) {
        await (db.delete(db.usuarios)..where((u) => u.uuid.equals(n.uuid)))
            .go();
      }
    }

    for (final u in _mockUsuarios) {
      await db.into(db.usuarios).insert(u);
      final fotos = await _fotosPrueba(u.nombre.value);
      if (fotos.isNotEmpty) {
        await (db.update(db.usuarios)
              ..where((w) => w.uuid.equals(u.uuid.value)))
            .write(UsuariosCompanion(fotosLocalesRutas: Value(fotos)));
      }
    }

    if (hayPropio) {
      final propio = todos.firstWhere((u) => u.esPerfilPropio);
      final fotos = await _fotosPrueba(propio.nombre);
      if (fotos.isNotEmpty) {
        await (db.update(db.usuarios)..where((u) => u.uuid.equals(propio.uuid)))
            .write(UsuariosCompanion(fotosLocalesRutas: Value(fotos)));
      }
    }
  }

  static Future<Usuario> crearUsuarioPropio(
      AppDatabase db, String nombre) async {
    final id = _uuid.v4();
    final companion = UsuariosCompanion.insert(
      uuid: id,
      nombre: nombre,
      edad: 25,
      genero: 'mujer',
      buscaGenero: 'hombre',
      biografia: Value('Bienvenido a Flumi \u2014 modo desarrollo'),
      preferenciaEdadMin: Value(22),
      preferenciaEdadMax: Value(35),
      queBusca: Value('relacion'),
      intereses: Value(<String>[
        '\u2764\ufe0f Leer',
        '\u2601\ufe0f Caf\u00e9',
        '\u2708\ufe0f Viajar',
        '\ud83c\udfac Cine',
        '\ud83c\udfb6 M\u00fasica',
      ]),
      fotosLocalesRutas: Value(await _fotosPrueba(nombre)),
      altura: Value('1.65'),
      educacion: Value('Universidad'),
      trabajo: Value('Dise\u00f1adora gr\u00e1fica'),
      bebe: Value('no'),
      fuma: Value('no'),
      hijos: Value('no'),
      personalidad: Value('extrovertida'),
      signoZodiaco: Value('libra'),
      mascotas: Value('gato'),
      fotoVerificacion: Value('auto'),
      esPerfilPropio: const Value(true),
      verificadoStatus: const Value(true),
      scorePopularidad: Value(100),
      pendienteDeSincronizar: const Value(false),
      creadoEn: Value(DateTime.now()),
    );
    await db.into(db.usuarios).insert(companion);
    return (await (db.select(db.usuarios)..where((u) => u.uuid.equals(id)))
        .getSingle());
  }

  static Future<void> sembrarConversacionesSiVacio(
      AppDatabase db, String miId) async {
    final hayMensajes = await (db.select(db.mensajes)).get();
    if (hayMensajes.isNotEmpty) return;

    final todos = await (db.select(db.usuarios)).get();
    final mapa = {for (final u in todos) u.uuid: u};
    final idsMock = _mockUsuarios.map((u) => u.uuid.value).toList();
    final otros = idsMock.where(mapa.containsKey).toList();
    if (otros.isEmpty) return;

    final ahora = DateTime.now();

    Future<void> match(String otro, Duration atras) async {
      await db.into(db.matches).insert(MatchesCompanion.insert(
            uuid: _uuid.v4(),
            usuarioAId: miId,
            usuarioBId: otro,
            timestampMatch: ahora.subtract(atras),
            pendienteDeSincronizar: const Value(false),
          ));
    }

    Future<void> mensaje(String otro, String contenido, Duration atras,
        {required bool esMio}) async {
      await db.into(db.mensajes).insert(MensajesCompanion.insert(
            uuid: _uuid.v4(),
            emisorId: esMio ? miId : otro,
            receptorId: esMio ? otro : miId,
            contenido: contenido,
            timestamp: ahora.subtract(atras),
            pendienteDeSincronizar: const Value(false),
          ));
    }

    if (otros.isNotEmpty) {
      await match(otros[0], const Duration(days: 3));
      await mensaje(otros[0], 'Â¡Hola! Vi que te gusta el cafÃ© ðŸ˜„',
          const Duration(days: 2, hours: 20),
          esMio: false);
      await mensaje(otros[0], 'Â¡Hola! SÃ­, soy adicto jaja',
          const Duration(days: 2, hours: 18),
          esMio: true);
      await mensaje(otros[0], 'Â¿CuÃ¡l es tu lugar favorito de la ciudad?',
          const Duration(days: 1, hours: 5),
          esMio: false);
      await mensaje(otros[0], 'El de la esquina de 23, sin dudas',
          const Duration(days: 1, hours: 3),
          esMio: true);
      await mensaje(
          otros[0],
          'Â¡Buena elecciÃ³n! DeberÃ­amos ir algÃºn dÃ­a â˜•',
          const Duration(hours: 5),
          esMio: false);
    }
    if (otros.length > 1) {
      await match(otros[1], const Duration(days: 2));
      await mensaje(otros[1], 'Hola ðŸ‘‹', const Duration(days: 1, hours: 10),
          esMio: false);
      await mensaje(otros[1], 'Â¿Te gusta la fotografÃ­a?',
          const Duration(days: 1, hours: 8),
          esMio: false);
      await mensaje(otros[1], 'Â¡Mucho! Sobre todo atardeceres',
          const Duration(days: 1, hours: 7),
          esMio: true);
      await mensaje(otros[1], 'DeberÃ­amos salir a tomar fotos algÃºn dÃ­a',
          const Duration(hours: 8),
          esMio: false);
    }
    if (otros.length > 2) {
      await match(otros[2], const Duration(days: 1));
      await mensaje(otros[2], 'Hey! Â¿QuÃ© tal?', const Duration(hours: 6),
          esMio: false);
      await mensaje(otros[2], 'Todo bien, Â¿y tÃº?', const Duration(hours: 5),
          esMio: true);
    }
    if (otros.length > 3) {
      await match(otros[3], const Duration(hours: 5));
    }
  }

  static final _mockUsuarios = [
    UsuariosCompanion.insert(
      uuid: 'aaaaaaaa-0000-4000-8000-000000000001',
      nombre: 'Alice',
      edad: 25,
      genero: 'mujer',
      buscaGenero: 'hombre',
      biografia: Value(
          'Amante del caf\u00e9 y los libros. Me encanta perderme en una buena historia y descubrir nuevos lugares para leer.'),
      intereses: Value(<String>[
        '\u2764\ufe0f Leer',
        '\u2601\ufe0f Caf\u00e9',
        '\u2708\ufe0f Viajar',
        '\ud83c\udfac Cine',
        '\ud83c\udfb6 M\u00fasica'
      ]),
      altura: Value('1.65'),
      educacion: Value('Universidad'),
      trabajo: Value('Dise\u00f1adora gr\u00e1fica'),
      bebe: Value('no'),
      fuma: Value('no'),
      hijos: Value('no'),
      personalidad: Value('extrovertida'),
      signoZodiaco: Value('libra'),
      mascotas: Value('gato'),
      religion: Value(''),
      fotoVerificacion: Value('auto'),
      verificadoStatus: const Value(true),
      scorePopularidad: Value(90),
      queBusca: const Value('relacion'),
      ultimaSincronizacionTimestamp: Value(DateTime.now()),
      perfilCompletado: const Value(true),
      pendienteDeSincronizar: const Value(false),
    ),
    UsuariosCompanion.insert(
      uuid: 'aaaaaaaa-0000-4000-8000-000000000002',
      nombre: 'Bob',
      edad: 28,
      genero: 'hombre',
      buscaGenero: 'mujer',
      biografia: Value(
          'Fot\u00f3grafo y viajero. Siempre buscando el mejor atardecer. Si te gusta la aventura, tenemos algo de qu\u00e9 hablar.'),
      intereses: Value(<String>[
        '\ud83d\udcf7 Fotograf\u00eda',
        '\u2708\ufe0f Viajar',
        '\u26bd F\u00fatbol',
        '\ud83c\udfc3 Running',
        '\ud83c\udfb8 Guitarra'
      ]),
      altura: Value('1.80'),
      educacion: Value('Universidad'),
      trabajo: Value('Fot\u00f3grafo freelance'),
      bebe: Value('no'),
      fuma: Value('social'),
      hijos: Value('no'),
      personalidad: Value('creativa'),
      signoZodiaco: Value('acuario'),
      mascotas: Value('perro'),
      religion: Value(''),
      fotoVerificacion: Value('manual'),
      verificadoStatus: const Value(true),
      scorePopularidad: Value(80),
      queBusca: const Value('relacion'),
      ultimaSincronizacionTimestamp: Value(DateTime.now()),
      perfilCompletado: const Value(true),
      pendienteDeSincronizar: const Value(false),
    ),
    UsuariosCompanion.insert(
      uuid: 'aaaaaaaa-0000-4000-8000-000000000003',
      nombre: 'Carla',
      edad: 22,
      genero: 'mujer',
      buscaGenero: 'otro',
      biografia: Value(
          'M\u00fasica y cine independiente. Toco el ukelele y veo pel\u00edculas de culto. Busco compa\u00f1\u00edas para conciertos y debates nocturnos.'),
      intereses: Value(<String>[
        '\ud83c\udfb6 M\u00fasica',
        '\ud83c\udfac Cine',
        '\ud83c\udfa8 Arte',
        '\ud83e\udde0 Filosof\u00eda',
        '\u2615 Caf\u00e9'
      ]),
      altura: Value('1.58'),
      educacion: Value('En curso'),
      trabajo: Value('Estudiante de artes'),
      bebe: Value('no'),
      fuma: Value('si'),
      hijos: Value('no'),
      personalidad: Value('introvertida'),
      signoZodiaco: Value('piscis'),
      mascotas: Value('gato'),
      religion: Value(''),
      fotoVerificacion: Value('auto'),
      verificadoStatus: const Value(true),
      scorePopularidad: Value(70),
      queBusca: const Value('casual'),
      perfilCompletado: const Value(true),
      pendienteDeSincronizar: const Value(false),
    ),
    UsuariosCompanion.insert(
      uuid: 'aaaaaaaa-0000-4000-8000-000000000004',
      nombre: 'David',
      edad: 30,
      genero: 'hombre',
      buscaGenero: 'mujer',
      biografia: Value(
          'Chef aficionado y amante del buen vino. Los domingos los dedico a cocinar recetas nuevas. \u00bfTe animas a ser mi catadora?'),
      intereses: Value(<String>[
        '\ud83c\udf7d\ufe0f Cocina',
        '\ud83c\udf77 Vino',
        '\u2708\ufe0f Viajar',
        '\ud83c\udfc4 Surf',
        '\ud83d\udcda Libros'
      ]),
      altura: Value('1.75'),
      educacion: Value('Universidad'),
      trabajo: Value('Ingeniero de software'),
      bebe: Value('no'),
      fuma: Value('no'),
      hijos: Value('no'),
      personalidad: Value('extrovertida'),
      signoZodiaco: Value('tauro'),
      mascotas: Value(''),
      religion: Value(''),
      fotoVerificacion: Value('manual'),
      verificadoStatus: const Value(false),
      scorePopularidad: Value(60),
      queBusca: const Value('amistad'),
      perfilCompletado: const Value(true),
      pendienteDeSincronizar: const Value(false),
    ),
    UsuariosCompanion.insert(
      uuid: 'aaaaaaaa-0000-4000-8000-000000000005',
      nombre: 'Elena',
      edad: 27,
      genero: 'mujer',
      buscaGenero: 'hombre',
      biografia: Value(
          'Yoga y meditaci\u00f3n son mi estilo de vida. Creo en el equilibrio y la conexi\u00f3n genuina. Busco a alguien que disfrute tanto el silencio como la charla.'),
      intereses: Value(<String>[
        '\ud83e\uddd8 Yoga',
        '\ud83c\udf31 Naturaleza',
        '\u2615 Caf\u00e9',
        '\ud83d\udcda Libros',
        '\ud83c\udfa8 Pintura'
      ]),
      altura: Value('1.70'),
      educacion: Value('Posgrado'),
      trabajo: Value('Psic\u00f3loga'),
      bebe: Value('no'),
      fuma: Value('no'),
      hijos: Value('no'),
      personalidad: Value('emp\u00e1tica'),
      signoZodiaco: Value('cancer'),
      mascotas: Value(''),
      religion: Value(''),
      fotoVerificacion: Value('auto'),
      verificadoStatus: const Value(true),
      scorePopularidad: Value(85),
      queBusca: const Value('relacion'),
      perfilCompletado: const Value(true),
      pendienteDeSincronizar: const Value(false),
    ),
  ];
}
