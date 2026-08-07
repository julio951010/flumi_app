import 'package:flutter/material.dart';
import '../../../core/base_datos_local/database.dart';
import '../../../core/base_datos_local/tables.dart';
import '../../../core/servicios/notificacion_servicio.dart';
import '../../configuracion/pantallas/informacion_basica_pantalla.dart';
import '../../encuentros/pantallas/cerca_de_ti_pantalla.dart'
    show PerfilDetallePage;
import '../perfil_repositorio.dart';
import '../perfil_etiquetas.dart';
import 'subpaginas_perfil.dart';

class EditarPerfilPantalla extends StatefulWidget {
  final Usuario perfil;
  final PerfilRepositorio repositorio;

  const EditarPerfilPantalla({
    super.key,
    required this.perfil,
    required this.repositorio,
  });

  @override
  State<EditarPerfilPantalla> createState() => _EditarPerfilPantallaState();
}

typedef _Opcion = OpcionEtiqueta;

class _EditarPerfilPantallaState extends State<EditarPerfilPantalla> {
  Usuario? _perfil;
  bool _cargando = true;

  static const _opcionesBusca = opcionesBuscaGenero;
  static const _opcionesQueBusca = opcionesQueBusca;
  static const _opcionesOrientacionSexual = opcionesOrientacionSexual;
  static const _opcionesSituacion = opcionesSituacion;
  static const _opcionesEducacion = opcionesEducacion;
  static const _opcionesTrabajo = opcionesTrabajo;
  static const _opcionesHijos = opcionesHijos;
  static const _opcionesTabaco = opcionesTabaco;
  static const _opcionesAlcohol = opcionesAlcohol;
  static const _opcionesSigno = opcionesSigno;
  static const _opcionesMascotas = opcionesMascotas;
  static const _opcionesReligion = opcionesReligion;
  static const _opcionesTatuajes = opcionesTatuajes;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  Future<void> _recargar() async {
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() {
      _perfil = perfil;
      _cargando = false;
    });
  }

  Future<void> _abrir(Widget pagina) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => pagina));
    if (mounted) _recargar();
  }

  int get _porcentajeCompletado {
    final p = _perfil;
    if (p == null) return 0;
    final creados = [
      p.fotosLocalesRutas.isNotEmpty,
      p.nombre.trim().isNotEmpty,
      p.fechaNacimiento != null,
      p.genero.isNotEmpty,
      p.biografia.trim().isNotEmpty,
      p.ciudad.trim().isNotEmpty,
      p.orientacionSexual.isNotEmpty,
      p.situacionSentimental.isNotEmpty,
      p.queBusca.isNotEmpty,
      p.buscaGenero.isNotEmpty,
      p.educacion.isNotEmpty,
      p.trabajo.trim().isNotEmpty,
      p.hijos.isNotEmpty,
      p.fuma.isNotEmpty,
      p.bebe.isNotEmpty,
      p.idiomas.trim().isNotEmpty,
      p.altura.trim().isNotEmpty,
      p.signoZodiaco.isNotEmpty,
      p.mascotas.isNotEmpty,
      p.religion.isNotEmpty,
      p.personalidad.isNotEmpty,
      p.tatuajes.isNotEmpty,
      p.intereses.isNotEmpty,
    ];
    final completos = creados.where((c) => c).length;
    return (completos / creados.length * 100).round();
  }

  void _vistaPrevia() {
    final perfil = _perfil;
    if (perfil == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PerfilDetallePage(
          usuario: perfil,
          gusta: true,
          esMatch: true,
          esMeGusta: true,
          soloVista: true,
        ),
      ),
    );
  }

  String _valorTexto(String v) => v.trim().isEmpty ? 'Sin definir' : v;

  String _alturaTexto(String valor) {
    final s = valor.trim();
    if (s.isEmpty) return 'Sin definir';
    if (s.toLowerCase() == 'prefiero no decirlo') {
      return '\ud83d\ude48 Prefiero no decirlo';
    }
    final pies = RegExp(r"(\d+)\s*'\s*(\d+)").firstMatch(s);
    if (pies != null) {
      final cm =
          (int.parse(pies.group(1)!) * 12 + int.parse(pies.group(2)!)) *
              2.54;
      return '${cm.round()} cm';
    }
    final num = double.tryParse(s.replaceAll(',', '.'));
    if (num == null) return s;
    if (num < 5) return '${(num * 100).round()} cm';
    return '${num.round()} cm';
  }

  String _opcionTexto(List<_Opcion> opciones, String valor) {
    if (valor.isEmpty) return 'Sin definir';
    for (final o in opciones) {
      if (o.$2 == valor) return o.$1;
    }
    return valor;
  }

  static const _personalidadLegacy = {
    'extrovertida': '\ud83d\udde3\ufe0f Extrovertido/a',
    'introvertida': '\ud83e\uddd8 Introvertido/a',
    'ambas': '\u2696\ufe0f Ambivertido/a',
    'creativa': '\ud83c\udfa8 Creativo / Imaginativo',
    'empatica': '\ud83e\udd17 Emp\u00e1tico/a / Comprensivo/a',
    'divertida': '\ud83d\ude04 Divertido/a / Alegre',
  };

  String _personalidadTexto(String valor) {
    if (valor.isEmpty) return 'Sin definir';
    final partes = valor
        .split(',')
        .map((p) => _personalidadLegacy[p.trim()] ?? p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    return partes.isEmpty ? 'Sin definir' : partes.join(', ');
  }

  String _signoTexto(String valor) {
    if (valor.isEmpty) return 'Sin definir';
    if (valor == 'prefiero_no_decirlo') {
      return '\ud83d\ude48 Prefiero no decirlo';
    }
    return _opcionTexto(_opcionesSigno, valor);
  }

  static const _orientacionesLegacy = {
    'homosexual': 'Gay',
    'otro': 'Otro',
    'no_comparto': 'Prefiero no decirlo',
  };

  String _orientacionTexto(String valor) {
    if (valor.isEmpty) return 'Sin definir';
    return _orientacionesLegacy[valor] ??
        _opcionTexto(_opcionesOrientacionSexual, valor);
  }

  static const _situacionesLegacy = {
    'en_relacion': 'En una relación',
    'abierto': 'Abierto/a',
  };

  String _situacionTexto(String valor) {
    if (valor.isEmpty) return 'Sin definir';
    return _situacionesLegacy[valor] ?? _opcionTexto(_opcionesSituacion, valor);
  }

  static const _educacionesLegacy = {
    'formacion_profesional': '\ud83c\udf93 Ense\u00f1anza T\u00e9cnica y Profesional',
    'universidad': '\ud83c\udf93 Educaci\u00f3n Superior',
    'bachillerato': '\ud83c\udf93 Educaci\u00f3n Secundaria',
    'en_curso': '\ud83c\udf93 Educaci\u00f3n Superior',
  };

  String _educacionTexto(String valor) {
    if (valor.isEmpty) return 'Sin definir';
    return _educacionesLegacy[valor] ?? _opcionTexto(_opcionesEducacion, valor);
  }

  String _trabajoTexto(String valor) {
    if (valor.isEmpty) return 'Sin definir';
    return _opcionTexto(_opcionesTrabajo, valor);
  }

  static const _hijosLegacy = {
    'si': '\ud83d\udc68\u200d\ud83d\udc66 Ya tengo hijos y no quiero m\u00e1s',
    'no': '\u274c No quiero tener hijos',
  };

  String _hijosTexto(String valor) {
    if (valor.isEmpty) return 'Sin definir';
    return _hijosLegacy[valor] ?? _opcionTexto(_opcionesHijos, valor);
  }

  static const _tabacoLegacy = {
    'no': '\ud83d\udead No fumo',
    'social': '\ud83d\udeac Fumo socialmente',
    'si': '\ud83d\udeac Fumo a diario',
  };

  String _tabacoTexto(String valor) {
    if (valor.isEmpty) return 'Sin definir';
    return _tabacoLegacy[valor] ?? _opcionTexto(_opcionesTabaco, valor);
  }

  static const _alcoholLegacy = {
    'no': '\ud83d\udeab\ud83c\udf77 No bebo',
    'social': '\ud83c\udf77 Bebo socialmente',
    'si': '\ud83c\udf7a Bebo con moderaci\u00f3n',
  };

  String _alcoholTexto(String valor) {
    if (valor.isEmpty) return 'Sin definir';
    return _alcoholLegacy[valor] ?? _opcionTexto(_opcionesAlcohol, valor);
  }

  static const _mascotasLegacy = {
    'ave': 'Otras mascotas',
    'otro': 'Otras mascotas',
    'otras': 'Otras mascotas',
    'ninguna': '\ud83d\udeab No tengo mascotas y no quiero',
  };

  String _mascotasTexto(String valor) {
    if (valor.isEmpty) return 'Sin definir';
    return _mascotasLegacy[valor] ?? _opcionTexto(_opcionesMascotas, valor);
  }

  static const _religionLegacy = {
    'otra': 'Otra',
  };

  String _religionTexto(String valor) {
    if (valor.isEmpty) return 'Sin definir';
    return _religionLegacy[valor] ?? _opcionTexto(_opcionesReligion, valor);
  }

  static const _tatuajesLegacy = {
    'si': 'Tengo alg\u00fan tatuaje',
    'no': 'No tengo tatuajes',
  };

  String _tatuajesTexto(String valor) {
    if (valor.isEmpty) return 'Sin definir';
    return _tatuajesLegacy[valor] ?? _opcionTexto(_opcionesTatuajes, valor);
  }

  static const _buscaGeneroLegacy = {
    'hombre': '\ud83d\udc68 Hombres',
    'mujer': '\ud83d\udc69 Mujeres',
    'ambos': '\ud83c\udf08 Todos/as',
    'otro': '\ud83d\ude48 Prefiero no decirlo',
  };

  String _buscaGeneroTexto(String valor) {
    if (valor.isEmpty) return 'Sin definir';
    final etiquetas = valor
        .split(',')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .map((c) => _buscaGeneroLegacy[c] ??
            _opcionTexto(_opcionesBusca, c))
        .toList();
    return etiquetas.join(' \u00b7 ');
  }

  String _rangoEdadTexto(int min, int max) {
    if (min == 18 && max == 99) return 'Sin definir';
    return '$min a $max a\u00f1os';
  }

  String _fechaTexto(DateTime? f) {
    if (f == null) return 'Sin definir';
    return '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
  }

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;
    final p = _perfil;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Editar perfil',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  _cabecera(primario),
                  const SizedBox(height: 20),
                  _seccionTitulo('Fotos de perfil'),
                  const SizedBox(height: 10),
                  _grillaFotos(primario),
                  const SizedBox(height: 12),
                  _botonVerificar(primario),
                  const SizedBox(height: 24),
                  _seccionTitulo('Información básica'),
                  const SizedBox(height: 4),
                  _item(
                    context,
                    Icons.person_outline,
                    'Nombre',
                    _valorTexto(p?.nombre ?? ''),
                    () => _abrir(ActualizarNombrePantalla(
                        repositorio: widget.repositorio)),
                  ),
                  const Divider(height: 1),
                  _item(
                    context,
                    Icons.cake_outlined,
                    'Fecha de nacimiento',
                    _fechaTexto(p?.fechaNacimiento),
                    () => _abrir(ActualizarFechaPantalla(
                        repositorio: widget.repositorio)),
                  ),
                  const Divider(height: 1),
                  _item(
                    context,
                    Icons.wc_outlined,
                    'Género',
                    _valorTexto(_capitalizar(p?.genero ?? '')),
                    () => _abrir(ActualizarGeneroPantalla(
                        repositorio: widget.repositorio)),
                  ),
                  const Divider(height: 1),
                  _item(
                    context,
                    Icons.location_on_outlined,
                    'Ubicación',
                    _valorTexto(p?.ciudad ?? ''),
                    () => _abrir(ActualizarUbicacionPantalla(
                        repositorio: widget.repositorio)),
                  ),
                  const SizedBox(height: 24),
                  _seccionTitulo('Sobre mí'),
                  const SizedBox(height: 10),
                  _tarjetaSobreMi(primario, p?.biografia ?? ''),
                  const SizedBox(height: 24),
                  _seccionTitulo('Preferencias de búsqueda'),
                  const SizedBox(height: 4),
                  _item(
                    context,
                    Icons.search_outlined,
                    '¿Qué buscas?',
                    _opcionTexto(_opcionesQueBusca, p?.queBusca ?? ''),
                    () => _abrir(
                        QueBuscaPantalla(repositorio: widget.repositorio)),
                  ),
                  const Divider(height: 1),
                  _item(
                    context,
                    Icons.people_outline,
                    '¿A quién quieres conocer?',
                    _buscaGeneroTexto(p?.buscaGenero ?? ''),
                    () => _abrir(
                        QuieroConocerPantalla(repositorio: widget.repositorio)),
                  ),
                  const Divider(height: 1),
                  _item(
                    context,
                    Icons.tune,
                    'Rango de edad ideal',
                    _rangoEdadTexto(p?.preferenciaEdadMin ?? 18,
                        p?.preferenciaEdadMax ?? 99),
                    () => _abrir(RangoEdadPantalla(
                        repositorio: widget.repositorio)),
                  ),
                  const SizedBox(height: 24),
                  _seccionTitulo('Vida personal'),
                  const SizedBox(height: 4),
                  _item(
                    context,
                    Icons.favorite_outline,
                    'Orientación sexual',
                    _orientacionTexto(p?.orientacionSexual ?? ''),
                    () => _abrir(
                        OrientacionSexualPantalla(
                            repositorio: widget.repositorio)),
                  ),
                  const Divider(height: 1),
                  _item(
                    context,
                    Icons.favorite_border,
                    'Estado civil / Relación',
                    _situacionTexto(p?.situacionSentimental ?? ''),
                    () => _abrir(SituacionSentimentalPantalla(
                        repositorio: widget.repositorio)),
                  ),
                  const Divider(height: 1),
                  _item(
                    context,
                    Icons.child_care_outlined,
                    '¿Tienes hijos?',
                    _hijosTexto(p?.hijos ?? ''),
                    () => _abrir(HijosPantalla(
                      repositorio: widget.repositorio,
                    )),
                  ),
                  const Divider(height: 1),
                  _item(
                    context,
                    Icons.church_outlined,
                    'Religión / Creencias',
                    _religionTexto(p?.religion ?? ''),
                    () => _abrir(ReligionPantalla(
                      repositorio: widget.repositorio,
                    )),
                  ),
                  const SizedBox(height: 24),
                  _seccionTitulo('Profesión y estudios'),
                  const SizedBox(height: 4),
                  _item(
                    context,
                    Icons.school_outlined,
                    'Estudios',
                    _educacionTexto(p?.educacion ?? ''),
                    () => _abrir(NivelEducativoPantalla(
                      repositorio: widget.repositorio,
                    )),
                  ),
                  const Divider(height: 1),
                  _item(
                    context,
                    Icons.badge_outlined,
                    '¿A qué te dedicas?',
                    _valorTexto(p?.profesion ?? ''),
                    () => _abrir(ProfesionPantalla(
                      repositorio: widget.repositorio,
                    )),
                  ),
                  const Divider(height: 1),
                  _item(
                    context,
                    Icons.work_outline,
                    'Sector laboral',
                    _trabajoTexto(p?.trabajo ?? ''),
                    () => _abrir(TrabajoPantalla(
                      repositorio: widget.repositorio,
                    )),
                  ),
                  const SizedBox(height: 24),
                  _seccionTitulo('Estilo de vida'),
                  const SizedBox(height: 4),
                  _item(
                    context,
                    Icons.smoke_free_outlined,
                    '¿Fumas?',
                    _tabacoTexto(p?.fuma ?? ''),
                    () => _abrir(TabacoPantalla(
                      repositorio: widget.repositorio,
                    )),
                  ),
                  const Divider(height: 1),
                  _item(
                    context,
                    Icons.sports_bar_outlined,
                    '¿Bebes alcohol?',
                    _alcoholTexto(p?.bebe ?? ''),
                    () => _abrir(AlcoholPantalla(
                      repositorio: widget.repositorio,
                    )),
                  ),
                  const Divider(height: 1),
                  _item(
                    context,
                    Icons.pets_outlined,
                    '¿Tienes mascotas?',
                    _mascotasTexto(p?.mascotas ?? ''),
                    () => _abrir(MascotasPantalla(
                      repositorio: widget.repositorio,
                    )),
                  ),
                  const Divider(height: 1),
                  _item(
                    context,
                    Icons.colorize_outlined,
                    '¿Tienes tatuajes?',
                    _tatuajesTexto(p?.tatuajes ?? ''),
                    () => _abrir(TatuajesPantalla(
                      repositorio: widget.repositorio,
                    )),
                  ),
                  const SizedBox(height: 24),
                  _seccionTitulo('Personalidad y apariencia'),
                  const SizedBox(height: 4),
                  _item(
                    context,
                    Icons.psychology_outlined,
                    'Personalidad',
                    _personalidadTexto(p?.personalidad ?? ''),
                    () => _abrir(PersonalidadPantalla(
                      repositorio: widget.repositorio,
                    )),
                  ),
                  const Divider(height: 1),
                  _item(
                    context,
                    Icons.height,
                    'Estatura',
                    _alturaTexto(p?.altura ?? ''),
                    () => _abrir(EstaturaPantalla(
                      repositorio: widget.repositorio,
                    )),
                  ),
                  const Divider(height: 1),
                  _item(
                    context,
                    Icons.star_outline,
                    'Signo del zodíaco',
                    _signoTexto(p?.signoZodiaco ?? ''),
                    () => _abrir(SignoZodiacalPantalla(
                      repositorio: widget.repositorio,
                    )),
                  ),
                  const SizedBox(height: 24),
                  _seccionTitulo('Idiomas'),
                  const SizedBox(height: 10),
                  _tarjetaIdiomas(primario, p?.idiomas ?? ''),
                  const SizedBox(height: 24),
                  _seccionTitulo('Intereses'),
                  const SizedBox(height: 10),
                  _tarjetaIntereses(primario, p?.intereses ?? const []),
                  const SizedBox(height: 24),
                  _seccionTitulo('Preguntas del perfil'),
                  const SizedBox(height: 10),
                  _seccionPreguntas(primario, p?.preguntasPerfil ?? const []),
                ],
              ),
      ),
    );
  }

  String _capitalizar(String v) {
    if (v.isEmpty) return '';
    return v[0].toUpperCase() + v.substring(1);
  }

  Widget _item(BuildContext context, IconData icono, String titulo,
      String valor, VoidCallback onTap) {
    final secundario = Theme.of(context).colorScheme.secondary;
    return ListTile(
      leading: Icon(icono, color: secundario),
      title: Text(
        titulo,
        style: const TextStyle(fontSize: 15, color: Colors.black87),
      ),
      subtitle: Text(
        valor,
        style: TextStyle(
          color: valor == 'Sin definir' ? Colors.grey[400] : Colors.black87,
          fontSize: 13,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
    );
  }

  Widget _cabecera(Color primario) {
    final porcentaje = _porcentajeCompletado;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'Perfil $porcentaje% completado',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Flexible(
          child: ElevatedButton.icon(
            onPressed: _vistaPrevia,
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('Vista previa', style: TextStyle(fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: primario,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    );
  }

  Widget _grillaFotos(Color primario) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: List.generate(4, (index) {
        return InkWell(
          onTap: () => NotificacionServicio.advertencia(
              context, 'Subir fotos estará disponible próximamente.'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primario.withValues(alpha: 0.3)),
            ),
            child: index == 0
                ? Icon(Icons.add_a_photo_outlined,
                    color: primario.withValues(alpha: 0.6))
                : Icon(Icons.add, color: Colors.grey[400]),
          ),
        );
      }),
    );
  }

  Widget _tarjetaSobreMi(Color primario, String biografia) {
    final vacia = biografia.trim().isEmpty;
    return InkWell(
      onTap: () => _abrir(SobreMiPantalla(repositorio: widget.repositorio)),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: primario.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primario.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(vacia ? Icons.edit_outlined : Icons.auto_stories_outlined,
                color: primario, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: vacia
                  ? const Text(
                      'Cuéntanos algo sobre ti',
                      style: TextStyle(fontSize: 14, color: Colors.black45),
                    )
                  : Text(
                      biografia,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, color: Colors.black87),
                    ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaIdiomas(Color color, String idiomas) {
    final lista = idiomas
        .split(',')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();
    final vacia = lista.isEmpty;
    return InkWell(
      onTap: () => _abrir(IdiomasPantalla(repositorio: widget.repositorio)),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.translate, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: vacia
                  ? const Text(
                      '¿Qué idiomas hablas?',
                      style: TextStyle(fontSize: 14, color: Colors.black45),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: lista
.map((idioma) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  idioma,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaIntereses(Color color, List<String> intereses) {
    final vacia = intereses.isEmpty;
    return InkWell(
      onTap: () => _abrir(InteresesPerfilPantalla(
          repositorio: widget.repositorio)),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.interests_outlined, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: vacia
                  ? const Text(
                      '¿Qué te apasiona?',
                      style: TextStyle(fontSize: 14, color: Colors.black45),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: intereses
                          .map((interes) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  interes,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _botonVerificar(Color primario) {
    return InkWell(
      onTap: () => NotificacionServicio.advertencia(
          context, 'La verificación estará disponible próximamente.'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: primario.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primario.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.verified_outlined, color: primario, size: 22),
            const SizedBox(width: 10),
            const Text(
              'Verificar perfil',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _seccionPreguntas(Color color, List<PreguntaRespuesta> preguntas) {
    const maxPreguntas = 3;
    if (preguntas.isEmpty) {
      return InkWell(
        onTap: () => _abrir(PreguntasPantalla(
            repositorio: widget.repositorio)),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.help_outline, color: color, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Preguntas para conocerte mejor',
                  style: TextStyle(fontSize: 14, color: Colors.black45),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final pregunta in preguntas)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => _abrir(PreguntasPantalla(
                  repositorio: widget.repositorio)),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.question_answer_outlined,
                        color: color, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pregunta.pregunta,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pregunta.respuesta,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (preguntas.length < maxPreguntas)
          InkWell(
            onTap: () => _abrir(PreguntasPantalla(
                repositorio: widget.repositorio)),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: color.withValues(alpha: 0.5)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Responder pregunta',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.add, size: 20, color: Colors.black54),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _seccionTitulo(String titulo) {
    return Text(
      titulo,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }
}