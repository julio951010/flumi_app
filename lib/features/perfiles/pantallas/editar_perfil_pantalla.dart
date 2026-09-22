import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:drift/drift.dart' hide Column;

import '../../../core/base_datos_local/database.dart';
import '../../../core/base_datos_local/tables.dart';
import '../../../core/servicios/notificacion_servicio.dart';
import '../../../core/servicios/perfil_foto_servicio.dart';
import '../../../widgets_comunes/foto_perfil.dart';
import '../../../widgets_comunes/placeholder_foto.dart';
import '../../../widgets_comunes/flumi_loader.dart';
import '../../../widgets_comunes/recortar_imagen_pantalla.dart';
import '../../configuracion/pantallas/informacion_basica_pantalla.dart';
import '../../encuentros/pantallas/cerca_de_ti_pantalla.dart'
    show PerfilDetallePage;
import '../perfil_completado.dart';
import '../perfil_repositorio.dart';
import '../perfil_etiquetas.dart';
import 'subpaginas_perfil.dart';
import 'verificacion_cuenta_pantalla.dart';

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
  final _picker = ImagePicker();

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
    return calcularCompletadoPerfil(p);
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
          titulo: 'Vista previa',
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
    if (valor.isEmpty) {
      // Sin signo guardado: lo calculamos de la fecha de nacimiento.
      final fecha = _perfil?.fechaNacimiento;
      if (fecha != null) {
        final codigo = calcularSignoZodiacal(fecha);
        if (codigo != null) {
          return '${_opcionTexto(_opcionesSigno, codigo)} (autom\u00e1tico)';
        }
      }
      return 'Sin definir';
    }
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
            ? const CargandoBlanco()
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  _cabecera(primario),
                  const SizedBox(height: 20),
                  _seccionTitulo('Fotos de perfil'),
                  const SizedBox(height: 10),
                  _grillaFotos(primario),
                  const SizedBox(height: 8),
                  Text(
                    'Mantén presionado para reordenar. La primera foto es tu foto de perfil.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
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
        ElevatedButton.icon(
          onPressed: _vistaPrevia,
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: const Text('Vista previa'),
          style: ElevatedButton.styleFrom(
            backgroundColor: primario,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }

  // Fotos a mostrar en la grilla: prioriza la URL remota de cada índice
  // (persistente) y cae a la ruta local (en web son blobs que mueren al
  // recargar la página). Usa la longitud máxima de ambas listas porque un
  // perfil descargado del servidor solo trae URLs (las locales van vacías).
  List<String> get _fotosGrilla {
    final locales = _perfil?.fotosLocalesRutas ?? const <String>[];
    final urls = _perfil?.fotosUrls ?? const <String>[];
    final total = locales.length > urls.length ? locales.length : urls.length;
    return List<String>.generate(total, (i) {
      final url = i < urls.length ? urls[i] : '';
      final local = i < locales.length ? locales[i] : '';
      return url.isNotEmpty ? url : local;
    }, growable: true);
  }

  Widget _grillaFotos(Color primario) {
    final fotos = _fotosGrilla;
    const total = 4;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: List.generate(total, (index) {
          final tieneFoto = index < fotos.length;
          if (tieneFoto) {
            return _celdaFoto(index, fotos[index], primario);
          }
          return _celdaAgregar(primario);
        }),
      ),
    );
  }

  Widget _celdaFoto(int index, String ruta, Color primario) {
    final esPortada = index == 0;
    final contenido = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: esPortada ? Border.all(color: primario, width: 3) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _fotoWidget(ruta),
            if (esPortada)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: primario,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Perfil',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != index,
      onAcceptWithDetails: (details) => _reordenarFotos(details.data, index),
      builder: (context, candidate, rejected) {
        final resaltado = candidate.isNotEmpty;
        return LongPressDraggable<int>(
          data: index,
          dragAnchorStrategy: childDragAnchorStrategy,
          feedback: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72,
              height: 72,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _fotoWidget(ruta),
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.4, child: contenido),
          child: Container(
            decoration: resaltado
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primario, width: 2),
                  )
                : null,
            child: GestureDetector(
              onTap: () => _mostrarOpcionesFoto(index),
              child: contenido,
            ),
          ),
        );
      },
    );
  }

  Widget _celdaAgregar(Color primario) {
    return InkWell(
      onTap: _seleccionarFoto,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primario.withValues(alpha: 0.3)),
        ),
        child: Icon(Icons.add_a_photo_outlined,
            color: primario.withValues(alpha: 0.6)),
      ),
    );
  }

  Future<void> _reordenarFotos(int from, int to) async {
    final perfil = _perfil;
    if (perfil == null) return;
    final total = _fotosGrilla.length;
    if (from < 0 || from >= total) return;
    if (to < 0 || to >= total) return;
    if (from == to) return;
    // Se rellenan ambas listas hasta `total` (el mismo largo que usa la
    // grilla visible) antes de reordenar — si se reordena directo sobre
    // fotosLocalesRutas/fotosUrls tal como estén, una de las dos podría
    // ser más corta (p. ej. tras sincronizar el perfil desde Supabase) y
    // el reordenamiento fallar en silencio o desalinear una respecto a
    // la otra.
    final nuevas = [...perfil.fotosLocalesRutas];
    while (nuevas.length < total) {
      nuevas.add('');
    }
    final nuevasUrls = [...perfil.fotosUrls];
    while (nuevasUrls.length < total) {
      nuevasUrls.add('');
    }
    final item = nuevas.removeAt(from);
    nuevas.insert(to, item);
    final itemUrl = nuevasUrls.removeAt(from);
    nuevasUrls.insert(to, itemUrl);
    await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
      uuid: Value(perfil.uuid),
      fotosLocalesRutas: Value(nuevas),
      fotosUrls: Value(nuevasUrls),
      pendienteDeSincronizar: const Value(true),
    ));
    if (!mounted) return;
    setState(() => _perfil = perfil.copyWith(
        fotosLocalesRutas: nuevas,
        fotosUrls: nuevasUrls,
        pendienteDeSincronizar: true));
  }

  Widget _fotoWidget(String ruta) {
    if (kIsWeb && (ruta.startsWith('blob:') || ruta.startsWith('data:'))) {
      return Image.network(
        ruta,
        fit: BoxFit.cover,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        errorBuilder: (_, __, ___) => const PlaceholderFoto(),
      );
    }
    return imagenFoto(ruta, fit: BoxFit.cover);
  }

  Future<ImageSource?> _elegirFuente() async {
    if (kIsWeb) return ImageSource.gallery;
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmar({required String titulo, required String mensaje}) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return resultado ?? false;
  }

  Future<XFile?> _recortar(XFile foto) async {
    final bytes = await foto.readAsBytes();
    final recortada = await Navigator.of(context).push<XFile>(
      MaterialPageRoute(
        builder: (_) => RecortarImagenPantalla(
          bytes: bytes,
          nombre: foto.name,
        ),
      ),
    );
    return recortada;
  }

  Future<void> _seleccionarFoto() async {
    if (_fotosGrilla.length >= 4) {
      NotificacionServicio.advertencia(context, 'Solo puedes subir 4 fotos.');
      return;
    }
    final fuente = await _elegirFuente();
    if (fuente == null) return;
    try {
      final foto = await _picker.pickImage(
        source: fuente,
        maxWidth: 1080,
        imageQuality: 85,
      );
      if (foto == null) return;
      final recortada = await _recortar(foto);
      if (recortada == null) return;
      await _agregarFoto(recortada);
    } catch (_) {
      if (!mounted) return;
      NotificacionServicio.alerta(
        context,
        'No se pudo abrir la cámara o la galería.',
      );
    }
  }

  Future<void> _agregarFoto(XFile foto) async {
    final perfil = _perfil;
    if (perfil == null) return;
    // Índice real del próximo slot: el mismo que usa la grilla visible
    // (máximo entre fotosUrls y fotosLocalesRutas), no fotosLocalesRutas
    // en crudo — que puede llegar vacía tras sincronizar el perfil desde
    // Supabase, aunque fotosUrls ya tenga fotos reales.
    final indice = _fotosGrilla.length;
    final nuevas = [...perfil.fotosLocalesRutas];
    while (nuevas.length <= indice) {
      nuevas.add('');
    }
    nuevas[indice] = foto.path;
    await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
      uuid: Value(perfil.uuid),
      fotosLocalesRutas: Value(nuevas),
      pendienteDeSincronizar: const Value(true),
    ));
    if (!mounted) return;
    setState(() =>
        _perfil = perfil.copyWith(fotosLocalesRutas: nuevas, pendienteDeSincronizar: true));
    PerfilFotoServicio.subirFotoPerfil(usuarioId: perfil.uuid, archivo: foto)
        .then((url) async {
      if (url == null || !mounted) return;
      final actual = _perfil;
      if (actual == null) return;
      final nuevasUrls = [...actual.fotosUrls];
      while (nuevasUrls.length <= indice) {
        nuevasUrls.add('');
      }
      nuevasUrls[indice] = url;
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(actual.uuid),
        fotosUrls: Value(nuevasUrls),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      setState(() =>
          _perfil = actual.copyWith(fotosUrls: nuevasUrls, pendienteDeSincronizar: true));
      NotificacionServicio.exito(context, 'Foto subida al servidor.');
    });
  }

  Future<void> _cambiarFoto(int index) async {
    final perfil = _perfil;
    if (perfil == null) return;
    if (index >= _fotosGrilla.length) return;
    final fuente = await _elegirFuente();
    if (fuente == null) return;
    try {
      final foto = await _picker.pickImage(
        source: fuente,
        maxWidth: 1080,
        imageQuality: 85,
      );
      if (foto == null) return;
      final recortada = await _recortar(foto);
      if (recortada == null) return;
      final urlAnterior = index < perfil.fotosUrls.length
          ? perfil.fotosUrls[index]
          : '';
      final nuevas = [...perfil.fotosLocalesRutas];
      while (nuevas.length <= index) {
        nuevas.add('');
      }
      nuevas[index] = recortada.path;
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        fotosLocalesRutas: Value(nuevas),
        pendienteDeSincronizar: const Value(true),
      ));
      if (urlAnterior.startsWith('http')) {
        PerfilFotoServicio.eliminarFotoPerfil(
          usuarioId: perfil.uuid,
          urlOFoto: urlAnterior,
        );
      }
      if (!mounted) return;
      setState(() => _perfil =
          perfil.copyWith(fotosLocalesRutas: nuevas, pendienteDeSincronizar: true));
      PerfilFotoServicio.subirFotoPerfil(usuarioId: perfil.uuid, archivo: foto)
          .then((url) async {
        if (url == null || !mounted) return;
        final actual = _perfil;
        if (actual == null) return;
        final nuevasUrls = [...actual.fotosUrls];
        if (index < nuevasUrls.length) {
          nuevasUrls[index] = url;
        } else {
          while (nuevasUrls.length < index) {
            nuevasUrls.add('');
          }
          nuevasUrls.add(url);
        }
        await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
          uuid: Value(actual.uuid),
          fotosUrls: Value(nuevasUrls),
          pendienteDeSincronizar: const Value(true),
        ));
        if (!mounted) return;
        setState(() =>
            _perfil = actual.copyWith(fotosUrls: nuevasUrls, pendienteDeSincronizar: true));
        NotificacionServicio.exito(context, 'Foto subida al servidor.');
      });
    } catch (_) {
      if (!mounted) return;
      NotificacionServicio.alerta(
        context,
        'No se pudo abrir la cámara o la galería.',
      );
    }
  }

  void _mostrarOpcionesFoto(int index) {
    final fotos = _fotosGrilla;
    if (index >= fotos.length) return;
    final ruta = fotos[index];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('Ver'),
              onTap: () {
                Navigator.pop(ctx);
                _verFoto(ruta);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_back_outlined),
              title: const Text('Cambiar foto'),
              onTap: () async {
                Navigator.pop(ctx);
                final confirmado = await _confirmar(
                  titulo: 'Cambiar foto',
                  mensaje: '¿Quieres reemplazar esta foto por una nueva?',
                );
                if (confirmado && mounted) await _cambiarFoto(index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Eliminar',
                  style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirmado = await _confirmar(
                  titulo: 'Eliminar foto',
                  mensaje: '¿Seguro que quieres eliminar esta foto?',
                );
                if (confirmado && mounted) await _eliminarFoto(index);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _verFoto(String ruta) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(child: _fotoWidget(ruta)),
      ),
    );
  }

  Future<void> _eliminarFoto(int index) async {
    final perfil = _perfil;
    if (perfil == null) return;
    if (index >= _fotosGrilla.length) return;
    final nuevas = [...perfil.fotosLocalesRutas];
    while (nuevas.length <= index) {
      nuevas.add('');
    }
    nuevas.removeAt(index);
    final nuevasUrls = [...perfil.fotosUrls];
    final urlEliminada = index < nuevasUrls.length ? nuevasUrls[index] : '';
    while (nuevasUrls.length <= index) {
      nuevasUrls.add('');
    }
    nuevasUrls.removeAt(index);
    await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
      uuid: Value(perfil.uuid),
      fotosLocalesRutas: Value(nuevas),
      fotosUrls: Value(nuevasUrls),
      pendienteDeSincronizar: const Value(true),
    ));
    if (urlEliminada.startsWith('http')) {
      PerfilFotoServicio.eliminarFotoPerfil(
        usuarioId: perfil.uuid,
        urlOFoto: urlEliminada,
      );
    }
    if (!mounted) return;
    setState(() => _perfil = perfil.copyWith(
        fotosLocalesRutas: nuevas,
        fotosUrls: nuevasUrls,
        pendienteDeSincronizar: true));
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
    final perfil = _perfil;
    final verificado = perfil?.verificadoStatus ?? false;
    final pendiente = !verificado &&
        (perfil?.fotoVerificacion.trim().isNotEmpty ?? false);

    final IconData icono;
    final String texto;
    final Color colorIcono;
    final Color colorFondo;
    final Color colorBorde;

    if (verificado) {
      icono = Icons.verified;
      texto = 'Perfil verificado';
      colorIcono = const Color(0xFF2E7D32);
      colorFondo = const Color(0xFF2E7D32).withValues(alpha: 0.08);
      colorBorde = const Color(0xFF2E7D32).withValues(alpha: 0.3);
    } else if (pendiente) {
      icono = Icons.hourglass_top_outlined;
      texto = 'Verificación en revisión';
      colorIcono = const Color(0xFFC9A227);
      colorFondo = const Color(0xFFC9A227).withValues(alpha: 0.1);
      colorBorde = const Color(0xFFC9A227).withValues(alpha: 0.3);
    } else {
      icono = Icons.verified_outlined;
      texto = 'Verificar perfil';
      colorIcono = primario;
      colorFondo = primario.withValues(alpha: 0.08);
      colorBorde = primario.withValues(alpha: 0.3);
    }

    return InkWell(
      onTap: perfil == null
          ? null
          : () async {
              await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => VerificacionCuentaPantalla(
                    perfil: perfil,
                    repositorio: widget.repositorio,
                  ),
                ),
              );
              if (mounted) _recargar();
            },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: colorFondo,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorBorde),
        ),
        child: Row(
          children: [
            Icon(icono, color: colorIcono, size: 22),
            const SizedBox(width: 10),
            Text(
              texto,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
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