import 'package:drift/drift.dart';

import 'conexion.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Usuarios, Mensajes, Matches, Reportes, Bloqueos, Suscripciones, UsosDiarios, Visitas, HistorialLikes, Rechazos, NotificacionesAbiertas, ConversacionesEliminadas, ConversacionesLeidas])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? abrirConexion());

  @override
  int get schemaVersion => 22;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      // Limpieza de seguridad: elimina filas viejas e incompletas (creadas
      // por versiones anteriores de la app) que tengan NULL en columnas que
      // el esquema actual exige no nulas. Leerlas haría crashear el mapeo de
      // drift (Null check operator used on a null value). Es seguro borrarlas:
      // el perfil real se vuelve a descargar de Supabase al iniciar sesión.
      await customStatement('''
        DELETE FROM usuarios
        WHERE uuid IS NULL
           OR nombre IS NULL
           OR edad IS NULL
           OR biografia IS NULL
           OR fotos_locales_rutas IS NULL
           OR fotos_urls IS NULL
           OR preferencia_edad_min IS NULL
           OR preferencia_edad_max IS NULL
           OR genero IS NULL
           OR busca_genero IS NULL
           OR que_busca IS NULL
           OR ciudad IS NULL
           OR ubicacion_lat IS NULL
           OR ubicacion_lon IS NULL
           OR ocultar_en_linea IS NULL
           OR ocultar_edad IS NULL
           OR verificado_status IS NULL
           OR score_popularidad IS NULL
           OR pendiente_de_sincronizar IS NULL
           OR es_perfil_propio IS NULL
           OR perfil_completado IS NULL
           OR orientacion_sexual IS NULL
           OR situacion_sentimental IS NULL
           OR intereses IS NULL
           OR altura IS NULL
           OR educacion IS NULL
           OR trabajo IS NULL
           OR profesion IS NULL
           OR preferencia_relacion IS NULL
           OR bebe IS NULL
           OR fuma IS NULL
           OR hijos IS NULL
           OR personalidad IS NULL
           OR signo_zodiaco IS NULL
           OR mascotas IS NULL
           OR religion IS NULL
           OR idiomas IS NULL
           OR tatuajes IS NULL
           OR preguntas_perfil IS NULL
           OR foto_verificacion IS NULL
           OR creado_en IS NULL;
      ''');
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.addColumn(usuarios, usuarios.perfilCompletado);
      }
      if (from < 3) {
        await m.addColumn(usuarios, usuarios.queBusca);
      }
      if (from < 4) {
        await m.addColumn(usuarios, usuarios.orientacionSexual);
        await m.addColumn(usuarios, usuarios.situacionSentimental);
        await m.addColumn(usuarios, usuarios.intereses);
        await m.addColumn(usuarios, usuarios.altura);
        await m.addColumn(usuarios, usuarios.educacion);
        await m.addColumn(usuarios, usuarios.trabajo);
        await m.addColumn(usuarios, usuarios.bebe);
        await m.addColumn(usuarios, usuarios.fuma);
        await m.addColumn(usuarios, usuarios.hijos);
        await m.addColumn(usuarios, usuarios.personalidad);
        await m.addColumn(usuarios, usuarios.signoZodiaco);
        await m.addColumn(usuarios, usuarios.mascotas);
        await m.addColumn(usuarios, usuarios.religion);
        await m.addColumn(usuarios, usuarios.fotoVerificacion);
      }
      if (from < 5) {
        await m.addColumn(matches, matches.leidoHasta);
      }
      if (from < 6) {
        await m.addColumn(usuarios, usuarios.fechaNacimiento);
        await m.addColumn(usuarios, usuarios.ciudad);
      }
      if (from < 7) {
        await m.addColumn(usuarios, usuarios.profesion);
        await m.addColumn(usuarios, usuarios.preferenciaRelacion);
        await m.addColumn(usuarios, usuarios.idiomas);
        await m.addColumn(usuarios, usuarios.tatuajes);
      }
      if (from < 8) {
        await m.addColumn(usuarios, usuarios.preguntasPerfil);
      }
      if (from < 9) {
        await m.createTable(suscripciones);
        await m.createTable(usosDiarios);
      }
      if (from < 10) {
        await m.createTable(visitas);
        await m.createTable(historialLikes);
        await m.addColumn(usuarios, usuarios.ultimaConexion);
        await m.addColumn(usuarios, usuarios.ocultarEnLinea);
        await m.addColumn(usuarios, usuarios.ocultarEdad);
      }
      if (from < 11) {
        await m.createTable(rechazos);
      }
      if (from < 12) {
        await m.createTable(notificacionesAbiertas);
      }
      if (from < 13) {
        await m.addColumn(historialLikes, historialLikes.leidoHasta);
      }
      if (from < 14) {
        await m.createTable(conversacionesEliminadas);
      }
      if (from < 15) {
        await m.addColumn(
            conversacionesEliminadas, conversacionesEliminadas.reactivada);
      }
      if (from < 16) {
        await m.addColumn(usuarios, usuarios.ocultarPerfil);
        await m.addColumn(usuarios, usuarios.ocultarVisitas);
      }
      if (from < 17) {
        await m.addColumn(historialLikes, historialLikes.esSuper);
      }
      if (from < 18) {
        await m.createTable(conversacionesLeidas);
      }
      if (from < 19) {
        await m.addColumn(usuarios, usuarios.isAdmin);
      }
      if (from < 20) {
        await m.addColumn(suscripciones, suscripciones.planReserva);
        await m.addColumn(suscripciones, suscripciones.venceReserva);
      }
      if (from < 21) {
        await m.addColumn(suscripciones, suscripciones.inicioReserva);
      }
      if (from < 22) {
        await m.addColumn(usuarios, usuarios.gestoVerificacion);
      }
    },
  );
}
