import 'dart:convert';

import 'package:drift/drift.dart';

import '../base_datos_local/database.dart';
import '../base_datos_local/tables.dart';

/// Mapeos entre el perfil de Supabase (Map) y el modelo local (Drift).
/// Se comparten entre SyncService (descarga/subida en segundo plano) y
/// PerfilRepositorio (lectura/escritura directa online-first).
class PerfilMapeo {
  PerfilMapeo._();

  /// Mapea el perfil remoto (Supabase) al companion local.
  static UsuariosCompanion perfilRemotoACompanion(
    Map<String, dynamic> p, {
    required bool esPropio,
  }) {
    final fechaNacRaw = p['fecha_nacimiento'] as String?;
    final fechaNac = fechaNacRaw != null ? parsearFecha(fechaNacRaw) : null;
    final edadRemota = p['edad'];
    final edad = (edadRemota is int && edadRemota > 0)
        ? edadRemota
        : (fechaNac != null ? calcularEdad(fechaNac.toIso8601String()) : 18);

    return UsuariosCompanion.insert(
      uuid: p['id'] as String,
      nombre: (p['nombre'] as String?) ?? '',
      edad: edad,
      genero: (p['genero'] as String?) ?? 'otro',
      buscaGenero: (p['busca_genero'] as String?) ?? 'otro',
      biografia: Value((p['biografia'] as String?) ?? ''),
      queBusca: Value((p['que_busca'] as String?) ?? ''),
      preferenciaEdadMin: Value(aInt(p['preferencia_edad_min'], 18)),
      preferenciaEdadMax: Value(aInt(p['preferencia_edad_max'], 99)),
      fechaNacimiento: Value(fechaNac),
      ciudad: Value((p['ciudad'] as String?) ?? ''),
      ubicacionLat: Value(aDouble(p['ubicacion_lat'], 0.0)),
      ubicacionLon: Value(aDouble(p['ubicacion_lon'], 0.0)),
      ultimaConexion: Value(parsearFecha(p['ultima_conexion'])),
      ocultarEnLinea: Value(aBool(p['ocultar_en_linea'], false)),
      ocultarEdad: Value(aBool(p['ocultar_edad'], false)),
      verificadoStatus: Value(aBool(p['verificado_status'], false)),
      scorePopularidad: Value(aInt(p['score_popularidad'], 0)),
      perfilCompletado: Value(aBool(p['perfil_completado'], false)),
      orientacionSexual: Value((p['orientacion_sexual'] as String?) ?? ''),
      situacionSentimental:
          Value((p['situacion_sentimental'] as String?) ?? ''),
      intereses: Value(aListaString(p['intereses'])),
      altura: Value((p['altura'] as String?) ?? ''),
      educacion: Value((p['educacion'] as String?) ?? ''),
      trabajo: Value((p['trabajo'] as String?) ?? ''),
      profesion: Value((p['profesion'] as String?) ?? ''),
      preferenciaRelacion: Value((p['preferencia_relacion'] as String?) ?? ''),
      bebe: Value((p['bebe'] as String?) ?? ''),
      fuma: Value((p['fuma'] as String?) ?? ''),
      hijos: Value((p['hijos'] as String?) ?? ''),
      personalidad: Value((p['personalidad'] as String?) ?? ''),
      signoZodiaco: Value((p['signo_zodiaco'] as String?) ?? ''),
      mascotas: Value((p['mascotas'] as String?) ?? ''),
      religion: Value((p['religion'] as String?) ?? ''),
      idiomas: Value((p['idiomas'] as String?) ?? ''),
      tatuajes: Value((p['tatuajes'] as String?) ?? ''),
      preguntasPerfil: Value(aPreguntas(p['preguntas_perfil'])),
      fotoVerificacion: Value((p['foto_verificacion'] as String?) ?? ''),
      fotosUrls: Value(aListaString(p['fotos_urls'])),
      creadoEn: Value(parsearFecha(p['creado_en']) ?? DateTime.now()),
      esPerfilPropio: Value(esPropio),
      pendienteDeSincronizar: const Value(false),
    );
  }

  /// Mapea el perfil remoto (Supabase) a la fila local [Usuario] en memoria
  /// (sin persistir). Se usa para consultas directas al RPC del feed.
  static Usuario perfilRemotoAUsuario(
    Map<String, dynamic> p, {
    required bool esPropio,
  }) {
    final fechaNacRaw = p['fecha_nacimiento'] as String?;
    final fechaNac = fechaNacRaw != null ? parsearFecha(fechaNacRaw) : null;
    final edadRemota = p['edad'];
    final edad = (edadRemota is int && edadRemota > 0)
        ? edadRemota
        : (fechaNac != null ? calcularEdad(fechaNac.toIso8601String()) : 18);

    return Usuario(
      uuid: p['id'] as String,
      nombre: (p['nombre'] as String?) ?? '',
      edad: edad,
      biografia: (p['biografia'] as String?) ?? '',
      fotosLocalesRutas: const [],
      fotosUrls: aListaString(p['fotos_urls']),
      preferenciaEdadMin: aInt(p['preferencia_edad_min'], 18),
      preferenciaEdadMax: aInt(p['preferencia_edad_max'], 99),
      genero: (p['genero'] as String?) ?? 'otro',
      buscaGenero: (p['busca_genero'] as String?) ?? 'otro',
      queBusca: (p['que_busca'] as String?) ?? '',
      fechaNacimiento: fechaNac,
      ciudad: (p['ciudad'] as String?) ?? '',
      ubicacionLat: aDouble(p['ubicacion_lat'], 0.0),
      ubicacionLon: aDouble(p['ubicacion_lon'], 0.0),
      ultimaConexion: parsearFecha(p['ultima_conexion']),
      ocultarEnLinea: aBool(p['ocultar_en_linea'], false),
      ocultarEdad: aBool(p['ocultar_edad'], false),
      verificadoStatus: aBool(p['verificado_status'], false),
      scorePopularidad: aInt(p['score_popularidad'], 0),
      pendienteDeSincronizar: false,
      esPerfilPropio: esPropio,
      perfilCompletado: aBool(p['perfil_completado'], false),
      orientacionSexual: (p['orientacion_sexual'] as String?) ?? '',
      situacionSentimental: (p['situacion_sentimental'] as String?) ?? '',
      intereses: aListaString(p['intereses']),
      altura: (p['altura'] as String?) ?? '',
      educacion: (p['educacion'] as String?) ?? '',
      trabajo: (p['trabajo'] as String?) ?? '',
      profesion: (p['profesion'] as String?) ?? '',
      preferenciaRelacion: (p['preferencia_relacion'] as String?) ?? '',
      bebe: (p['bebe'] as String?) ?? '',
      fuma: (p['fuma'] as String?) ?? '',
      hijos: (p['hijos'] as String?) ?? '',
      personalidad: (p['personalidad'] as String?) ?? '',
      signoZodiaco: (p['signo_zodiaco'] as String?) ?? '',
      mascotas: (p['mascotas'] as String?) ?? '',
      religion: (p['religion'] as String?) ?? '',
      idiomas: (p['idiomas'] as String?) ?? '',
      tatuajes: (p['tatuajes'] as String?) ?? '',
      preguntasPerfil: aPreguntas(p['preguntas_perfil']),
      fotoVerificacion: (p['foto_verificacion'] as String?) ?? '',
      creadoEn: parsearFecha(p['creado_en']) ?? DateTime.now(),
    );
  }

  /// Convierte el perfil local (completo) en el mapa que se sube a Supabase.
  /// 'genero' y 'busca_genero' se normalizan a minúsculas porque la UI los
  /// guarda capitalizados y el CHECK constraint de Supabase solo admite
  /// ('hombre','mujer','otro','mujer trans','hombre trans','no binario','género fluido').
  static Map<String, dynamic> perfilARemoto(Usuario perfil) {
    return {
      'nombre': perfil.nombre,
      'biografia': perfil.biografia,
      'genero': perfil.genero.toLowerCase(),
      'busca_genero': perfil.buscaGenero.toLowerCase(),
      'que_busca': perfil.queBusca,
      'preferencia_edad_min': perfil.preferenciaEdadMin,
      'preferencia_edad_max': perfil.preferenciaEdadMax,
      'fecha_nacimiento': perfil.fechaNacimiento?.toIso8601String().substring(0, 10),
      'ciudad': perfil.ciudad,
      'ubicacion_lat': perfil.ubicacionLat,
      'ubicacion_lon': perfil.ubicacionLon,
      'ultima_conexion': perfil.ultimaConexion?.toIso8601String(),
      'ocultar_en_linea': perfil.ocultarEnLinea,
      'ocultar_edad': perfil.ocultarEdad,
      'perfil_completado': perfil.perfilCompletado,
      'orientacion_sexual': perfil.orientacionSexual,
      'situacion_sentimental': perfil.situacionSentimental,
      'intereses': perfil.intereses,
      'altura': perfil.altura,
      'educacion': perfil.educacion,
      'trabajo': perfil.trabajo,
      'profesion': perfil.profesion,
      'preferencia_relacion': perfil.preferenciaRelacion,
      'bebe': perfil.bebe,
      'fuma': perfil.fuma,
      'hijos': perfil.hijos,
      'personalidad': perfil.personalidad,
      'signo_zodiaco': perfil.signoZodiaco,
      'mascotas': perfil.mascotas,
      'religion': perfil.religion,
      'idiomas': perfil.idiomas,
      'tatuajes': perfil.tatuajes,
      'preguntas_perfil':
          perfil.preguntasPerfil.map((e) => e.toJson()).toList(),
      'foto_verificacion': perfil.fotoVerificacion,
      'fotos_urls': perfil.fotosUrls,
      'edad': perfil.edad,
    };
  }

  /// Convierte un companion (posiblemente parcial) al mapa remoto, tomando
  /// como base [base] (fila local existente) para los campos ausentes.
  static Map<String, dynamic> perfilARemotoDesdeCompanion(
    UsuariosCompanion c, {
    Usuario? base,
  }) {
    T o<T>(Value<T> v, T d) => v.present ? v.value : d;

    return {
      'nombre': o(c.nombre, base?.nombre ?? ''),
      'biografia': o(c.biografia, base?.biografia ?? ''),
      'genero': o(c.genero, base?.genero ?? 'otro').toLowerCase(),
      'busca_genero':
          o(c.buscaGenero, base?.buscaGenero ?? 'otro').toLowerCase(),
      'que_busca': o(c.queBusca, base?.queBusca ?? ''),
      'preferencia_edad_min':
          o(c.preferenciaEdadMin, base?.preferenciaEdadMin ?? 18),
      'preferencia_edad_max':
          o(c.preferenciaEdadMax, base?.preferenciaEdadMax ?? 99),
      'fecha_nacimiento':
          _isoFecha(o(c.fechaNacimiento, base?.fechaNacimiento)),
      'ciudad': o(c.ciudad, base?.ciudad ?? ''),
      'ubicacion_lat': o(c.ubicacionLat, base?.ubicacionLat ?? 0.0),
      'ubicacion_lon': o(c.ubicacionLon, base?.ubicacionLon ?? 0.0),
      'ultima_conexion':
          o(c.ultimaConexion, base?.ultimaConexion)?.toIso8601String(),
      'ocultar_en_linea': o(c.ocultarEnLinea, base?.ocultarEnLinea ?? false),
      'ocultar_edad': o(c.ocultarEdad, base?.ocultarEdad ?? false),
      'perfil_completado':
          o(c.perfilCompletado, base?.perfilCompletado ?? false),
      'orientacion_sexual':
          o(c.orientacionSexual, base?.orientacionSexual ?? ''),
      'situacion_sentimental':
          o(c.situacionSentimental, base?.situacionSentimental ?? ''),
      'intereses': o(c.intereses, base?.intereses ?? const <String>[]),
      'altura': o(c.altura, base?.altura ?? ''),
      'educacion': o(c.educacion, base?.educacion ?? ''),
      'trabajo': o(c.trabajo, base?.trabajo ?? ''),
      'profesion': o(c.profesion, base?.profesion ?? ''),
      'preferencia_relacion':
          o(c.preferenciaRelacion, base?.preferenciaRelacion ?? ''),
      'bebe': o(c.bebe, base?.bebe ?? ''),
      'fuma': o(c.fuma, base?.fuma ?? ''),
      'hijos': o(c.hijos, base?.hijos ?? ''),
      'personalidad': o(c.personalidad, base?.personalidad ?? ''),
      'signo_zodiaco': o(c.signoZodiaco, base?.signoZodiaco ?? ''),
      'mascotas': o(c.mascotas, base?.mascotas ?? ''),
      'religion': o(c.religion, base?.religion ?? ''),
      'idiomas': o(c.idiomas, base?.idiomas ?? ''),
      'tatuajes': o(c.tatuajes, base?.tatuajes ?? ''),
      'preguntas_perfil': o(
        c.preguntasPerfil,
        base?.preguntasPerfil ?? const <PreguntaRespuesta>[],
      ).map((e) => e.toJson()).toList(),
      'foto_verificacion': o(c.fotoVerificacion, base?.fotoVerificacion ?? ''),
      'fotos_urls': o(c.fotosUrls, base?.fotosUrls ?? const <String>[]),
      'edad': o(c.edad, base?.edad ?? 18),
    };
  }

  // ------------------------------------------------------------
  // Utilidades de parseo
  // ------------------------------------------------------------
  static String? _isoFecha(DateTime? fecha) =>
      fecha?.toIso8601String().substring(0, 10);

  static DateTime? parsearFecha(dynamic valor) {
    if (valor == null) return null;
    if (valor is DateTime) return valor;
    if (valor is String) return DateTime.tryParse(valor);
    return null;
  }

  static int aInt(dynamic valor, int defecto) {
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();
    if (valor is String) return int.tryParse(valor) ?? defecto;
    return defecto;
  }

  static double aDouble(dynamic valor, double defecto) {
    if (valor is double) return valor;
    if (valor is int) return valor.toDouble();
    if (valor is num) return valor.toDouble();
    if (valor is String) return double.tryParse(valor) ?? defecto;
    return defecto;
  }

  static bool aBool(dynamic valor, bool defecto) {
    if (valor is bool) return valor;
    if (valor is String) return valor.toLowerCase() == 'true';
    return defecto;
  }

  static List<String> aListaString(dynamic valor) {
    if (valor == null) return [];
    if (valor is List) return valor.map((e) => e.toString()).toList();
    if (valor is String && valor.isNotEmpty) {
      try {
        final decodificado = jsonDecode(valor);
        if (decodificado is List) {
          return decodificado.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  static List<PreguntaRespuesta> aPreguntas(dynamic valor) {
    if (valor == null) return [];
    dynamic lista = valor;
    if (valor is String && valor.isNotEmpty) {
      try {
        lista = jsonDecode(valor);
      } catch (_) {
        return [];
      }
    }
    if (lista is! List) return [];
    return lista.whereType<Map>().map((m) {
      final mapa = Map<String, dynamic>.from(m);
      return PreguntaRespuesta(
        pregunta: (mapa['pregunta'] ?? '').toString(),
        respuesta: (mapa['respuesta'] ?? '').toString(),
      );
    }).toList();
  }

  static int calcularEdad(String fechaNacimientoIso) {
    final nacimiento = DateTime.parse(fechaNacimientoIso);
    final hoy = DateTime.now();
    var edad = hoy.year - nacimiento.year;
    if (hoy.month < nacimiento.month ||
        (hoy.month == nacimiento.month && hoy.day < nacimiento.day)) {
      edad--;
    }
    return edad;
  }
}