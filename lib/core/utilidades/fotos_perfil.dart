import '../base_datos_local/database.dart';

/// Fotos a mostrar: prioriza las URLs remotas (persistencia real en la BD)
/// y cae a las rutas locales solo si no hay remotas.
List<String> fotosParaMostrar(Usuario perfil) {
  final remotas = perfil.fotosUrls.where((u) => u.isNotEmpty).toList();
  if (remotas.isNotEmpty) return remotas;
  return perfil.fotosLocalesRutas;
}
