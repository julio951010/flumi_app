import '../../core/base_datos_local/database.dart';

bool estaCompletadoCampo(String? v) {
  if (v == null) return false;
  final t = v.trim().toLowerCase();
  if (t.isEmpty) return false;
  return !(t.contains('prefiero no decirlo') ||
      t.contains('prefiero_no_decirlo') ||
      t == 'no_comparto' ||
      t == 'otro');
}

int calcularCompletadoPerfil(Usuario p) {
  final checks = <bool>[
    // La ubicación real es obligatoria: sin ella el perfil cae en (0,0) y no
    // aparece en el feed de nadie.
    p.ubicacionLat != 0 || p.ubicacionLon != 0,
    // El género es obligatorio...
    p.genero.trim().isNotEmpty,
    estaCompletadoCampo(p.biografia),
    p.fotosLocalesRutas.isNotEmpty || p.fotosUrls.isNotEmpty,
    p.preferenciaEdadMin != 18 || p.preferenciaEdadMax != 99,
    estaCompletadoCampo(p.queBusca),
    p.intereses.isNotEmpty,
    estaCompletadoCampo(p.altura),
    estaCompletadoCampo(p.educacion),
    estaCompletadoCampo(p.trabajo),
    estaCompletadoCampo(p.bebe) ||
        estaCompletadoCampo(p.fuma) ||
        estaCompletadoCampo(p.hijos),
    estaCompletadoCampo(p.personalidad),
    estaCompletadoCampo(p.signoZodiaco),
    estaCompletadoCampo(p.mascotas) || estaCompletadoCampo(p.religion),
  ];
  return (checks.where((c) => c).length * 100 / checks.length).round();
}