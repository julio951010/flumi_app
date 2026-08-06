import 'package:drift/drift.dart';
import 'dart:convert';

class ListaStringConverter extends TypeConverter<List<String>, String> {
  const ListaStringConverter();

  @override
  List<String> fromSql(String fromDb) {
    if (fromDb.isEmpty) return [];
    return (jsonDecode(fromDb) as List).cast<String>();
  }

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

class PreguntaRespuesta {
  const PreguntaRespuesta({required this.pregunta, required this.respuesta});

  final String pregunta;
  final String respuesta;

  Map<String, dynamic> toJson() =>
      {'pregunta': pregunta, 'respuesta': respuesta};

  factory PreguntaRespuesta.fromJson(Map<String, dynamic> json) =>
      PreguntaRespuesta(
        pregunta: json['pregunta'] as String? ?? '',
        respuesta: json['respuesta'] as String? ?? '',
      );
}

class ListaPreguntasConverter
    extends TypeConverter<List<PreguntaRespuesta>, String> {
  const ListaPreguntasConverter();

  @override
  List<PreguntaRespuesta> fromSql(String fromDb) {
    if (fromDb.isEmpty) return [];
    return (jsonDecode(fromDb) as List)
        .map((e) => PreguntaRespuesta.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  String toSql(List<PreguntaRespuesta> value) =>
      jsonEncode(value.map((e) => e.toJson()).toList());
}

class Usuarios extends Table {
  TextColumn get uuid => text()();
  TextColumn get nombre => text()();
  IntColumn get edad => integer()();
  TextColumn get biografia => text().withDefault(const Constant(''))();
  TextColumn get fotosLocalesRutas => text()
      .map(const ListaStringConverter())
      .withDefault(const Constant('[]'))();

  IntColumn get preferenciaEdadMin => integer().withDefault(const Constant(18))();
  IntColumn get preferenciaEdadMax => integer().withDefault(const Constant(99))();

  TextColumn get genero => text()();
  TextColumn get buscaGenero => text()();
  TextColumn get queBusca => text().withDefault(const Constant(''))();

  DateTimeColumn get fechaNacimiento => dateTime().nullable()();
  TextColumn get ciudad => text().withDefault(const Constant(''))();

  RealColumn get ubicacionLat => real().withDefault(const Constant(0.0))();
  RealColumn get ubicacionLon => real().withDefault(const Constant(0.0))();

  DateTimeColumn get ultimaSincronizacionTimestamp => dateTime().nullable()();

  BoolColumn get verificadoStatus => boolean().withDefault(const Constant(false))();
  IntColumn get scorePopularidad => integer().withDefault(const Constant(0))();

  BoolColumn get pendienteDeSincronizar => boolean().withDefault(const Constant(false))();
  BoolColumn get esPerfilPropio => boolean().withDefault(const Constant(false))();
  BoolColumn get perfilCompletado => boolean().withDefault(const Constant(false))();

  TextColumn get orientacionSexual => text().withDefault(const Constant(''))();
  TextColumn get situacionSentimental => text().withDefault(const Constant(''))();
  TextColumn get intereses => text()
      .map(const ListaStringConverter())
      .withDefault(const Constant('[]'))();
  TextColumn get altura => text().withDefault(const Constant(''))();
  TextColumn get educacion => text().withDefault(const Constant(''))();
  TextColumn get trabajo => text().withDefault(const Constant(''))();
  TextColumn get profesion => text().withDefault(const Constant(''))();
  TextColumn get preferenciaRelacion => text().withDefault(const Constant(''))();
  TextColumn get bebe => text().withDefault(const Constant(''))();
  TextColumn get fuma => text().withDefault(const Constant(''))();
  TextColumn get hijos => text().withDefault(const Constant(''))();
  TextColumn get personalidad => text().withDefault(const Constant(''))();
  TextColumn get signoZodiaco => text().withDefault(const Constant(''))();
  TextColumn get mascotas => text().withDefault(const Constant(''))();
  TextColumn get religion => text().withDefault(const Constant(''))();
  TextColumn get idiomas => text().withDefault(const Constant(''))();
  TextColumn get tatuajes => text().withDefault(const Constant(''))();
  TextColumn get preguntasPerfil => text()
      .map(const ListaPreguntasConverter())
      .withDefault(const Constant('[]'))();
  TextColumn get fotoVerificacion => text().withDefault(const Constant(''))();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {uuid};
}

class Mensajes extends Table {
  TextColumn get uuid => text()();
  TextColumn get emisorId => text()();
  TextColumn get receptorId => text()();
  TextColumn get contenido => text()();
  DateTimeColumn get timestamp => dateTime()();

  TextColumn get estadoEnvio => text().withDefault(const Constant('enviando'))();

  BoolColumn get pendienteDeSincronizar => boolean().withDefault(const Constant(true))();
  IntColumn get intentosDeSincronizacion => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {uuid};
}

class Matches extends Table {
  TextColumn get uuid => text()();
  TextColumn get usuarioAId => text()();
  TextColumn get usuarioBId => text()();
  DateTimeColumn get timestampMatch => dateTime()();

  BoolColumn get pendienteDeSincronizar => boolean().withDefault(const Constant(true))();

  TextColumn get ultimoMensajePreview => text().nullable()();
  DateTimeColumn get ultimoMensajeTimestamp => dateTime().nullable()();
  DateTimeColumn get leidoHasta => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {uuid};
}

class Reportes extends Table {
  TextColumn get uuid => text()();
  TextColumn get reportanteId => text()();
  TextColumn get reportadoId => text()();

  TextColumn get motivo => text()();
  TextColumn get detalle => text().withDefault(const Constant(''))();
  DateTimeColumn get timestamp => dateTime()();

  BoolColumn get pendienteDeSincronizar => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {uuid};
}

class Bloqueos extends Table {
  TextColumn get uuid => text()();
  TextColumn get bloqueadorId => text()();
  TextColumn get bloqueadoId => text()();
  DateTimeColumn get timestamp => dateTime()();

  BoolColumn get pendienteDeSincronizar => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {uuid};
}
