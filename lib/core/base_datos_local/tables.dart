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

  RealColumn get ubicacionLat => real().withDefault(const Constant(0.0))();
  RealColumn get ubicacionLon => real().withDefault(const Constant(0.0))();

  DateTimeColumn get ultimaSincronizacionTimestamp => dateTime().nullable()();

  BoolColumn get verificadoStatus => boolean().withDefault(const Constant(false))();
  IntColumn get scorePopularidad => integer().withDefault(const Constant(0))();

  BoolColumn get pendienteDeSincronizar => boolean().withDefault(const Constant(false))();
  BoolColumn get esPerfilPropio => boolean().withDefault(const Constant(false))();

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
