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

  TextColumn get fotosUrls => text()
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

  DateTimeColumn get ultimaConexion => dateTime().nullable()();
  BoolColumn get ocultarEnLinea => boolean().withDefault(const Constant(false))();
  BoolColumn get ocultarEdad => boolean().withDefault(const Constant(false))();
  BoolColumn get ocultarPerfil => boolean().withDefault(const Constant(false))();
  BoolColumn get ocultarVisitas => boolean().withDefault(const Constant(false))();

  BoolColumn get verificadoStatus => boolean().withDefault(const Constant(false))();
  IntColumn get scorePopularidad => integer().withDefault(const Constant(0))();

  BoolColumn get pendienteDeSincronizar => boolean().withDefault(const Constant(false))();
  BoolColumn get esPerfilPropio => boolean().withDefault(const Constant(false))();
  BoolColumn get perfilCompletado => boolean().withDefault(const Constant(false))();
  /// true para usuarios con rol de administrador: tienen acceso a todas las
  /// funciones de la app sin necesidad de plan (se sincroniza desde
  /// `profiles.is_admin`).
  BoolColumn get isAdmin => boolean().withDefault(const Constant(false))();

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

class Suscripciones extends Table {
  TextColumn get usuarioId => text()();
  TextColumn get plan => text().withDefault(const Constant('gratis'))();
  DateTimeColumn get inicio => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get vence => dateTime().nullable()();
  BoolColumn get activa => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {usuarioId};
}

class UsosDiarios extends Table {
  TextColumn get usuarioId => text()();
  DateTimeColumn get fecha => dateTime()();
  IntColumn get meGustasUsados => integer().withDefault(const Constant(0))();
  IntColumn get deshacerUsados => integer().withDefault(const Constant(0))();
  IntColumn get superlikesUsados => integer().withDefault(const Constant(0))();
  IntColumn get boostsUsados => integer().withDefault(const Constant(0))();
  IntColumn get vistasCercaUsadas => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {usuarioId, fecha};
}

class Visitas extends Table {
  TextColumn get uuid => text()();
  TextColumn get visitanteId => text()();
  TextColumn get visitadoId => text()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get pendienteDeSincronizar => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {uuid};
}

class HistorialLikes extends Table {
  TextColumn get uuid => text()();
  TextColumn get usuarioId => text()();
  TextColumn get usuarioLikeadoId => text()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get pendienteDeSincronizar => boolean().withDefault(const Constant(true))();

  /// Hasta qué mensaje el receptor ha leído la conversación sin match
  /// (like-only). Espejo de matches.leido_hasta para que el badge de no
  /// leídos funcione también sin match.
  DateTimeColumn get leidoHasta => dateTime().nullable()();

  /// true si este like fue un Superlike (emitido o recibido).
  BoolColumn get esSuper => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {uuid};
}

class Rechazos extends Table {
  TextColumn get uuid => text()();
  TextColumn get usuarioId => text()();
  TextColumn get rechazadoId => text()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get pendienteDeSincronizar => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {uuid};
}

/// Conversaciones que el usuario borró SOLO para él (estilo WhatsApp): el
/// match y los mensajes siguen en el servidor y en el otro cliente; esta
/// tabla local oculta la conversación de la lista sin que reaparezca al
/// sincronizar. Cuando cualquiera de los dos escribe de nuevo, la conversación
/// vuelve a mostrarse pero el historial anterior al borrado sigue oculto
/// (el corte es permanente; solo se ven los mensajes posteriores al borrado).
class ConversacionesEliminadas extends Table {
  TextColumn get otroUsuarioId => text()();
  DateTimeColumn get eliminadoEn => dateTime().withDefault(currentDateAndTime)();
  /// true cuando la conversación retomó actividad: ya no se oculta de la
  /// lista, pero eliminadoEn sigue filtrando el historial anterior al borrado.
  BoolColumn get reactivada => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {otroUsuarioId};
}

/// Marca de "leído hasta" de una conversación, guardada localmente por
/// conversación (otroUsuarioId). Es la fuente de verdad local del estado de
/// lectura del usuario, independiente de `matches`/`historial_likes`, lo que
/// permite marcar como leídas conversaciones que no tienen match ni like
/// (p. ej. las cuentas oficiales de sistema: Administrador y Flumi).
class ConversacionesLeidas extends Table {
  TextColumn get otroUsuarioId => text()();
  DateTimeColumn get leidoHasta => dateTime()();

  @override
  Set<Column> get primaryKey => {otroUsuarioId};
}

class NotificacionesAbiertas extends Table {
  /// Id de la notificación de bandeja ya abierta (ej. 'mensaje:<uuid>:<millis>').
  TextColumn get notificacionId => text()();
  DateTimeColumn get abiertaEn => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {notificacionId};
}
