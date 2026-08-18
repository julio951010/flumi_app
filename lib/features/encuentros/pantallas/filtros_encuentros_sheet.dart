import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utilidades/ubicacion_util.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/base_datos_local/database.dart';
import '../../../core/estilos/tema.dart';
import '../../../core/servicios/suscripcion_servicio.dart';
import '../../../core/servicios/notificacion_servicio.dart';
import '../../../features/perfiles/perfil_etiquetas.dart';
import '../../perfiles/pantallas/detalle_plan_pantalla.dart';

class FiltrosEncuentros {
  List<String> generos;
  RangeValues edadRango;
  double distanciaKm;
  bool enLineaAhora;
  String ubicacion;
  Map<String, List<String>> avanzado;
  bool perfilesVerificados;

  FiltrosEncuentros({
    this.generos = const [],
    this.edadRango = const RangeValues(18, 60),
    this.distanciaKm = 0,
    this.enLineaAhora = false,
    this.ubicacion = '',
    this.perfilesVerificados = false,
    Map<String, List<String>>? avanzado,
  }) : avanzado = avanzado ?? const {};

  FiltrosEncuentros copy() => FiltrosEncuentros(
        generos: List.of(generos),
        edadRango: edadRango,
        distanciaKm: distanciaKm,
        enLineaAhora: enLineaAhora,
        ubicacion: ubicacion,
        perfilesVerificados: perfilesVerificados,
        avanzado: Map<String, List<String>>.from(avanzado),
      );
}

Future<FiltrosEncuentros?> mostrarFiltrosEncuentros(
  BuildContext context, {
  required FiltrosEncuentros actuales,
  required bool estaEnCercaDeTi,
  SuscripcionServicio? suscripcionServicio,
}) {
  return Navigator.of(context).push<FiltrosEncuentros>(
    MaterialPageRoute(
      builder: (_) => _FiltrosEncuentrosPantalla(
        actuales: actuales,
        estaEnCercaDeTi: estaEnCercaDeTi,
        suscripcionServicio: suscripcionServicio,
      ),
    ),
  );
}

class _FiltrosEncuentrosPantalla extends StatefulWidget {
  final FiltrosEncuentros actuales;
  final bool estaEnCercaDeTi;
  final SuscripcionServicio? suscripcionServicio;

  const _FiltrosEncuentrosPantalla({
    required this.actuales,
    required this.estaEnCercaDeTi,
    this.suscripcionServicio,
  });

  @override
  State<_FiltrosEncuentrosPantalla> createState() =>
      _FiltrosEncuentrosPantallaState();
}

class _FiltrosEncuentrosPantallaState
    extends State<_FiltrosEncuentrosPantalla> {
  late List<String> _generos;
  late RangeValues _edad;
  late double _distancia;
  late bool _enLinea;
  late String _ubicacion;
  late Map<String, List<String>> _avanzado;
  late bool _perfilesVerificados;
  late final SuscripcionServicio _suscripcion = widget.suscripcionServicio ?? SuscripcionServicioMock();
  bool _edadExpandido = false;
  bool _distanciaExpandido = false;
  bool _generosExpandido = false;
  bool _ubicacionExpandido = false;
  bool _masOpcionesExpandido = false;

  static const _opcionesGeneroExpansion = opcionesGenero;
  static const _rutaJsonUbicaciones =
      'assets/data/cuba_provincias_municipios.json';

  late final TextEditingController _ubicacionCtrl;
  TextEditingController? _autocompleteCtrl;
  final _focusNodeUbicacion = FocusNode();
  Map<String, List<String>> _provincias = const {};
  List<String> _opciones = const [];
  bool _obteniendoUbicacion = false;

  @override
  void initState() {
    super.initState();
    _ubicacionCtrl = TextEditingController(
        text: widget.actuales.ubicacion == 'Sin definir'
            ? ''
            : widget.actuales.ubicacion);
    _cargarOpcionesUbicacion();
    _generos = List.of(widget.actuales.generos);
    _edad = widget.actuales.edadRango;
    _distancia = widget.actuales.distanciaKm;
    _enLinea = widget.actuales.enLineaAhora;
    _ubicacion = widget.actuales.ubicacion;
    _avanzado = Map<String, List<String>>.from(widget.actuales.avanzado);
    _perfilesVerificados = widget.actuales.perfilesVerificados;
  }

  @override
  void dispose() {
    _ubicacionCtrl.dispose();
    _focusNodeUbicacion.dispose();
    super.dispose();
  }

  Future<void> _cargarOpcionesUbicacion() async {
    String json = '{}';
    try {
      json = await rootBundle.loadString(_rutaJsonUbicaciones);
    } catch (_) {}
    final municipiosPorProvincia = <String, List<String>>{};
    final opciones = <String>{};
    final data = jsonDecode(json) as Map<String, dynamic>;
    final paises = data['paises'] as List? ?? const [];
    for (final pais in paises) {
      final provincias = (pais as Map<String, dynamic>)['provincias'];
      if (provincias is! List) continue;
      for (final p in provincias) {
        final provincia =
            (p as Map<String, dynamic>)['nombre'] as String? ?? '';
        final municipios = (p['municipios'] as List? ?? const [])
            .map((m) => m.toString())
            .toList();
        if (provincia.isEmpty) continue;
        municipiosPorProvincia[provincia] = municipios;
        opciones.addAll(municipios);
        opciones.add(provincia);
      }
    }
    if (!mounted) return;
    setState(() {
      _provincias = municipiosPorProvincia;
      _opciones = opciones.toList();
      if (_opciones.isEmpty) _opciones = const ['La Habana', 'Santiago de Cuba'];
    });
  }

  void _aplicar() {
    Navigator.pop(context, FiltrosEncuentros(
      generos: _generos,
      edadRango: _edad,
      distanciaKm: _distancia,
      enLineaAhora: _enLinea,
      ubicacion: _ubicacion,
      perfilesVerificados: _perfilesVerificados,
      avanzado: _avanzado,
    ));
  }

  void _quitarTodos() {
    setState(() {
      _generos = [];
      _edad = const RangeValues(18, 60);
      _distancia = 0;
      _enLinea = false;
      _ubicacion = '';
      _avanzado = <String, List<String>>{};
      _perfilesVerificados = false;
      _generosExpandido = false;
      _edadExpandido = false;
      _distanciaExpandido = false;
      _ubicacionExpandido = false;
      _masOpcionesExpandido = false;
      _ubicacionCtrl.clear();
      _autocompleteCtrl?.clear();
    });
    NotificacionServicio.exito(context, 'Todos los filtros fueron quitados');
  }

  String get _textoGeneros =>
      _generos.isEmpty ? 'Todos' : _generos.join(', ');

  String get _textoEdad => '${_edad.start.toInt()} - ${_edad.end.toInt()} años';

  String get _textoDistancia =>
      _distancia <= 0 ? 'Sin l\u00edmite' : '${_distancia.toInt()} km';

  String get _textoUbicacion =>
      _ubicacion.trim().isEmpty ? 'Sin definir' : _ubicacion;

  String get _textoAvanzado {
    var total = _avanzado.values.fold<int>(0, (acc, v) => acc + v.length);
    if (_perfilesVerificados) total++;
    if (_enLinea) total++;
    return total == 0 ? 'Abrir más parámetros' : '$total filtros activos';
  }

  Widget _panelUbicacion(Color primario) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _campoUbicacion(primario),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
                  _obteniendoUbicacion ? null : _obtenerUbicacionActual,
              style: OutlinedButton.styleFrom(
                foregroundColor: primario,
                side: BorderSide(color: primario.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.my_location, size: 20),
              label: Text(
                _obteniendoUbicacion
                    ? 'Obteniendo ubicación...'
                    : 'Obtener ubicación actual',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campoUbicacion(Color primario) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue texto) {
        if (texto.text.trim().isEmpty) return const Iterable<String>.empty();
        final consulta = _normalizar(texto.text.trim().toLowerCase());
        return _opciones.where(
            (opcion) => _normalizar(opcion.toLowerCase()).contains(consulta));
      },
      displayStringForOption: (opcion) => _etiqueta(opcion),
      fieldViewBuilder:
          (context, controladorTexto, focusNodeTexto, onFieldSubmitted) {
        _autocompleteCtrl = controladorTexto;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (controladorTexto.text.isEmpty &&
              _ubicacionCtrl.text.isNotEmpty) {
            controladorTexto.text = _ubicacionCtrl.text;
          }
        });
        return TextField(
          controller: controladorTexto,
          focusNode: focusNodeTexto,
          onChanged: (v) {
            _ubicacionCtrl.text = v;
            _ubicacion = v;
          },
          onSubmitted: (_) => onFieldSubmitted(),
          style: const TextStyle(color: Colors.black87, fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[100],
            labelText: 'Ciudad o municipio',
            labelStyle: const TextStyle(color: Colors.black45, fontSize: 14),
            prefixIcon: Icon(Icons.location_on_outlined,
                color: primario.withValues(alpha: 0.7), size: 20),
            suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primario.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primario.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primario, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, opciones) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: opciones.length,
                itemBuilder: (context, index) {
                  final opcion = opciones.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      _provincias.containsKey(opcion)
                          ? Icons.map_outlined
                          : Icons.location_city_outlined,
                      size: 20,
                      color: primario.withValues(alpha: 0.8),
                    ),
                    title: Text(
                      _etiqueta(opcion),
                      style: const TextStyle(fontSize: 14),
                    ),
                    onTap: () {
                      onSelected(opcion);
                      _focusNodeUbicacion.unfocus();
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (opcion) {
        _ubicacionCtrl.text = _etiqueta(opcion);
        _ubicacion = _etiqueta(opcion);
      },
    );
  }

  String _normalizar(String valor) {
    return valor
        .replaceAll('\u00e1', 'a')
        .replaceAll('\u00e9', 'e')
        .replaceAll('\u00ed', 'i')
        .replaceAll('\u00f3', 'o')
        .replaceAll('\u00fa', 'u')
        .replaceAll('\u00fc', 'u')
        .replaceAll('\u00f1', 'n');
  }

  String _etiqueta(String opcion) {
    if (_provincias.containsKey(opcion)) {
      return opcion;
    }
    final provincia = _provincias.entries
        .where((e) => e.value.contains(opcion))
        .map((e) => e.key)
        .firstOrNull;
    return provincia == null ? opcion : '$opcion, $provincia';
  }

  Future<void> _obtenerUbicacionActual() async {
    setState(() => _obteniendoUbicacion = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        NotificacionServicio.alerta(
          context,
          'El GPS está desactivado. Actívalo en los ajustes del dispositivo.',
        );
        return;
      }
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied) {
        if (!mounted) return;
        NotificacionServicio.alerta(
          context,
          'Permiso de ubicación denegado. Permítelo para usar esta función.',
        );
        return;
      }
      if (permiso == LocationPermission.deniedForever) {
        if (!mounted) return;
        NotificacionServicio.alerta(
          context,
          'El permiso de ubicación está bloqueado. Actívalo manualmente en Ajustes > Permisos.',
        );
        return;
      }
      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final nombre = await resolverNombreUbicacion(
        latitud: posicion.latitude,
        longitud: posicion.longitude,
        provincias: _provincias,
      );
      if (nombre == null || nombre.isEmpty) {
        if (!mounted) return;
        NotificacionServicio.alerta(
          context,
          'No se pudo obtener la ubicación. Verifica la señal GPS o escríbela manualmente.',
        );
        return;
      }
      if (!mounted) return;
      final textoFinal = _etiqueta(nombre);
      _autocompleteCtrl?.text = textoFinal;
      _ubicacionCtrl.text = textoFinal;
      _ubicacion = textoFinal;
      NotificacionServicio.exito(context, 'Ubicación establecida: $textoFinal');
    } catch (_) {
      if (!mounted) return;
      NotificacionServicio.alerta(
        context,
        'No se pudo obtener la ubicación. Verifica la señal GPS y la conexión, o escribe la ciudad manualmente.',
      );
    } finally {
      if (mounted) setState(() => _obteniendoUbicacion = false);
    }
  }

  List<String> _opcionesSinPrefiero(List<(String, String)> opciones) => [
        for (final o in opciones)
          if (!o.$1.contains('Prefiero no decirlo')) o.$1,
      ];

  List<_ParametroFiltro> get _parametros => [
        _ParametroFiltro(
          id: 'orientacion',
          icono: Icons.favorite_outline,
          titulo: 'Orientación sexual',
          opciones: _opcionesSinPrefiero(opcionesOrientacionSexual),
        ),
        _ParametroFiltro(
          id: 'que_busca',
          icono: Icons.search_outlined,
          titulo: '¿Qué busca?',
          opciones: _opcionesSinPrefiero(opcionesQueBusca),
        ),
        _ParametroFiltro(
          id: 'estado_civil',
          icono: Icons.favorite_border,
          titulo: 'Estado civil',
          opciones: _opcionesSinPrefiero(opcionesSituacion),
        ),
        _ParametroFiltro(
          id: 'hijos',
          icono: Icons.child_care_outlined,
          titulo: '¿Tiene hijos?',
          opciones: _opcionesSinPrefiero(opcionesHijos),
        ),
        _ParametroFiltro(
          id: 'religion',
          icono: Icons.church_outlined,
          titulo: 'Religión',
          opciones: _opcionesSinPrefiero(opcionesReligion),
        ),
        _ParametroFiltro(
          id: 'educacion',
          icono: Icons.school_outlined,
          titulo: 'Estudios',
          opciones: _opcionesSinPrefiero(opcionesEducacion),
        ),
        _ParametroFiltro(
          id: 'trabajo',
          icono: Icons.badge_outlined,
          titulo: 'Sector laboral',
          opciones: _opcionesSinPrefiero(opcionesTrabajo),
        ),
        _ParametroFiltro(
          id: 'fuma',
          icono: Icons.smoke_free_outlined,
          titulo: '¿Fuma?',
          opciones: _opcionesSinPrefiero(opcionesTabaco),
        ),
        _ParametroFiltro(
          id: 'bebe',
          icono: Icons.sports_bar_outlined,
          titulo: '¿Bebe alcohol?',
          opciones: _opcionesSinPrefiero(opcionesAlcohol),
        ),
        _ParametroFiltro(
          id: 'mascotas',
          icono: Icons.pets_outlined,
          titulo: '¿Tiene mascotas?',
          opciones: _opcionesSinPrefiero(opcionesMascotas),
        ),
        _ParametroFiltro(
          id: 'tatuajes',
          icono: Icons.colorize_outlined,
          titulo: '¿Tiene tatuajes?',
          opciones: _opcionesSinPrefiero(opcionesTatuajes),
        ),
        _ParametroFiltro(
          id: 'signo',
          icono: Icons.star_outline,
          titulo: 'Signo del zodíaco',
          opciones: _opcionesSinPrefiero(opcionesSigno),
        ),
        _ParametroFiltro(
          id: 'idiomas',
          icono: Icons.translate,
          titulo: 'Idiomas',
          opciones: idiomasDisponibles,
          multi: true,
        ),
      ];

  String _textoValorParametro(_ParametroFiltro p) {
    final valores = _avanzado[p.id] ?? const [];
    if (valores.isEmpty) return 'Sin definir';
    return valores.join(', ');
  }

Future<void> _editarParametro(_ParametroFiltro p) async {
    final valoresIniciales = _avanzado[p.id] ?? const <String>[];
    final resultado = await showModalBottomSheet<List<String>>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final seleccion = List<String>.from(valoresIniciales);
        return StatefulBuilder(
          builder: (ctx, setEstado) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.7,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    _barraArrastre(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          p.titulo,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final opcion in p.opciones)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _tarjetaOpcion(
                                  texto: opcion,
                                  seleccionada: seleccion.contains(opcion),
                                  onTap: () => setEstado(() {
                                    if (seleccion.contains(opcion)) {
                                      seleccion.remove(opcion);
                                    } else if (p.multi) {
                                      seleccion.add(opcion);
                                    } else {
                                      seleccion
                                        ..clear()
                                        ..add(opcion);
                                    }
                                  }),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, seleccion),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FlumiTema.colorPrimario,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: const Text('Aplicar',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (resultado != null && mounted) {
      setState(() {
        if (resultado.isEmpty) {
          _avanzado.remove(p.id);
        } else {
          _avanzado[p.id] = resultado;
        }
      });
    }
  }

  void _editarAlturaMinima() async {
    final primario = FlumiTema.colorPrimario;
    final actual =
        int.tryParse((_avanzado['altura_min'] ?? const ['140']).first) ?? 140;
    final resultado = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        var altura = actual;
        return StatefulBuilder(
          builder: (ctx, setEstado) {
            return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _barraArrastre(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Estatura mínima',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '$altura cm',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87),
                      ),
                      Slider(
                        value: altura.toDouble(),
                        min: 140,
                        max: 220,
                        divisions: 80,
                        activeColor: primario,
                        inactiveColor: primario.withValues(alpha: 0.2),
                        label: '$altura cm',
                        onChanged: (v) =>
                            setEstado(() => altura = v.round()),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, altura),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primario,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: const Text('Aplicar',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        );
      },
    );
    if (resultado != null && mounted) {
      setState(() {
        if (resultado > 140) {
          _avanzado['altura_min'] = ['$resultado'];
        } else {
          _avanzado.remove('altura_min');
        }
      });
    }
  }

  String _alturaMinimaTexto() {
    final valores = _avanzado['altura_min'] ?? const [];
    if (valores.isEmpty) return 'Sin definir';
    return '${valores.first} cm o más';
  }

  Widget _panelMasOpciones(Color primario) {
    final puedeAvanzados = _suscripcion.tienePremium;
    final puedeBasicosPlus = _suscripcion.tienePlus;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (puedeBasicosPlus)
            _filaSwitch(
              icono: Icons.verified_outlined,
              titulo: 'Perfiles verificados',
              activo: _perfilesVerificados,
              onCambio: (v) => setState(() => _perfilesVerificados = v),
            )
          else
            _filaBloqueada(
              icono: Icons.verified_outlined,
              titulo: 'Perfiles verificados',
              plan: PlanTipo.plus,
            ),
          const Divider(height: 1),
          if (puedeBasicosPlus)
            _filaSwitch(
              icono: Icons.wifi_tethering,
              titulo: 'En línea ahora',
              activo: _enLinea,
              onCambio: (v) => setState(() => _enLinea = v),
            )
          else
            _filaBloqueada(
              icono: Icons.wifi_tethering,
              titulo: 'En línea ahora',
              plan: PlanTipo.plus,
            ),
          const Divider(height: 1),
          if (!puedeAvanzados)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Icon(Icons.lock_outline, size: 32, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'Filtros avanzados disponibles en Flumi Premium',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DetallePlanPantalla(
                          nombre: 'Flumi Premium',
                          periodo: 'mensual',
                          precio: '500 cup',
                          icono: Icons.workspace_premium,
                          detalle: 'Acceso total',
                          destacado: false,
                        ),
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6584),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Ver Premium',
                        style:
                            TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            )
          else
            for (final p in _parametros) ...[
              _fila(
                icono: p.icono,
                titulo: p.titulo,
                valor: _textoValorParametro(p),
                porDefecto: (_avanzado[p.id] ?? const []).isEmpty,
                onAbrir: () => _editarParametro(p),
              ),
              const Divider(height: 1),
            ],
          if (puedeAvanzados)
            _fila(
              icono: Icons.height,
              titulo: 'Estatura mínima',
              valor: _alturaMinimaTexto(),
              porDefecto: _alturaMinimaTexto() == 'Sin definir',
              onAbrir: _editarAlturaMinima,
            ),
        ],
      ),
    );
  }

  Widget _filaSwitch({
    required IconData icono,
    required String titulo,
    required bool activo,
    required ValueChanged<bool> onCambio,
  }) {
    final primario = FlumiTema.colorPrimario;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icono, color: primario),
      title: Text(titulo,
          style: const TextStyle(fontSize: 15, color: Colors.black87)),
      trailing: Switch(
        value: activo,
        onChanged: onCambio,
        activeThumbColor: primario,
      ),
    );
  }

  Widget _filaBloqueada({
    required IconData icono,
    required String titulo,
    required PlanTipo plan,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icono, color: Colors.grey[400]),
      title: Text(titulo,
          style: TextStyle(fontSize: 15, color: Colors.grey[500])),
      trailing: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetallePlanPantalla(
              nombre: plan == PlanTipo.premium ? 'Flumi Premium' : 'Flumi Plus',
              periodo: 'mensual',
              precio: plan == PlanTipo.premium ? '500 cup' : '250 cup',
              icono: plan == PlanTipo.premium
                  ? Icons.workspace_premium
                  : Icons.auto_awesome,
              detalle: plan == PlanTipo.premium ? 'Acceso total' : 'Funciones extra',
              destacado: plan == PlanTipo.plus,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 18, color: Color(0xFF6C63FF)),
            const SizedBox(width: 4),
            Text(
              plan == PlanTipo.premium ? 'Premium' : 'Plus',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6C63FF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaOpcion({
    required String texto,
    required bool seleccionada,
    required VoidCallback onTap,
  }) {
    final primario = FlumiTema.colorPrimario;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: seleccionada
              ? primario.withValues(alpha: 0.10)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: seleccionada ? primario : primario.withValues(alpha: 0.3),
            width: seleccionada ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                texto,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: seleccionada ? FontWeight.w600 : FontWeight.w500,
                  color: seleccionada ? primario : Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              seleccionada ? Icons.check_circle : Icons.circle_outlined,
              color: seleccionada ? primario : Colors.grey[400],
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _barraArrastre() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primario = FlumiTema.colorPrimario;
    final cercaDeTi = widget.estaEnCercaDeTi;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          color: Colors.black87,
          onPressed: () => _aplicar(),
        ),
        title: const Text(
          'Filtros',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            color: Colors.white,
            onSelected: (valor) {
              if (valor == 'quitar_todos') _quitarTodos();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'quitar_todos',
                child: Row(
                  children: [
                    Icon(Icons.filter_alt_off_outlined,
                        color: Colors.black87, size: 20),
                    const SizedBox(width: 10),
                    const Text('Quitar todos los filtros',
                        style: TextStyle(fontSize: 14, color: Colors.black87)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _fila(
                      icono: Icons.people_outline,
                      titulo: 'Mostrar',
                      valor: _textoGeneros,
                      porDefecto: _generos.isEmpty,
                      onAbrir: () => setState(
                          () => _generosExpandido = !_generosExpandido),
                    ),
                    if (_generosExpandido) _panelGeneros(),
                    const Divider(height: 1),
                    _fila(
                      icono: Icons.cake_outlined,
                      titulo: 'Edad',
                      valor: _textoEdad,
                      porDefecto: _edad == const RangeValues(18, 60),
                      onAbrir: () => setState(
                          () => _edadExpandido = !_edadExpandido),
                    ),
                    if (_edadExpandido) _panelEdad(primario),
                    const Divider(height: 1),
                    if (cercaDeTi) ...[
                      _fila(
                        icono: Icons.near_me_outlined,
                        titulo: 'Distancia',
                        valor: _textoDistancia,
                        porDefecto: _distancia == 0,
                        onAbrir: () => setState(() =>
                            _distanciaExpandido = !_distanciaExpandido),
                      ),
                      if (_distanciaExpandido) _panelDistancia(primario),
                      const Divider(height: 1),
                    ] else ...[
                      _fila(
                        icono: Icons.location_on_outlined,
                        titulo: 'Ubicación',
                        valor: _textoUbicacion,
                        porDefecto: _ubicacion.trim().isEmpty,
                        onAbrir: () => setState(() =>
                            _ubicacionExpandido = !_ubicacionExpandido),
                      ),
                      if (_ubicacionExpandido) _panelUbicacion(primario),
                      const Divider(height: 1),
                    ],
                    _fila(
                      icono: Icons.tune,
                      titulo: 'Más opciones',
                      valor: _textoAvanzado,
                      porDefecto: _masOpcionesExpandido
                          ? false
                          : _avanzado.isEmpty &&
                              !_perfilesVerificados &&
                              !_enLinea,
                      onAbrir: () => setState(() =>
                          _masOpcionesExpandido = !_masOpcionesExpandido),
                    ),
                    if (_masOpcionesExpandido) _panelMasOpciones(primario),
                  ],
                ),
              ),
            ),
            _botonAplicar(primario),
          ],
        ),
      ),
    );
  }

  Widget _fila({
    required IconData icono,
    required String titulo,
    required String valor,
    required bool porDefecto,
    required VoidCallback onAbrir,
  }) {
    final primario = FlumiTema.colorPrimario;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onAbrir,
      leading: Icon(icono, color: primario),
      title: Text(titulo,
          style: const TextStyle(fontSize: 15, color: Colors.black87)),
      subtitle: Text(
        valor,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          color: porDefecto ? Colors.grey[400] : Colors.black87,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
    );
  }

  Widget _panelEdad(Color primario) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_edad.start.toInt()} - ${_edad.end.toInt()} años',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87),
          ),
          RangeSlider(
            values: _edad,
            min: 18,
            max: 80,
            divisions: 62,
            activeColor: primario,
            inactiveColor: primario.withValues(alpha: 0.2),
            labels: RangeLabels('${_edad.start.toInt()}', '${_edad.end.toInt()}'),
            onChanged: (v) => setState(() => _edad = v),
          ),
        ],
      ),
    );
  }

  Widget _panelDistancia(Color primario) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _distancia <= 0
                ? 'Sin l\u00edmite'
                : '${_distancia.toInt()} km',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87),
          ),
          Slider(
            value: _distancia,
            min: 0,
            max: 200,
            divisions: 200,
            activeColor: primario,
            inactiveColor: primario.withValues(alpha: 0.2),
            label: _distancia <= 0
                ? 'Sin l\u00edmite'
                : '${_distancia.toInt()} km',
            onChanged: (v) => setState(() => _distancia = v),
          ),
        ],
      ),
    );
  }

  Widget _panelGeneros() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _pill(
            texto: 'Todos',
            seleccionada: _generos.isEmpty,
            onTap: () => setState(() => _generos.clear()),
          ),
          for (final opcion in _opcionesGeneroExpansion)
            _pill(
              texto: opcion,
              seleccionada: _generos.contains(opcion.toLowerCase()),
              onTap: () => setState(() {
                final clave = opcion.toLowerCase();
                if (_generos.contains(clave)) {
                  _generos.remove(clave);
                } else {
                  _generos.add(clave);
                }
              }),
            ),
        ],
      ),
    );
  }

  Widget _pill({
    required String texto,
    required bool seleccionada,
    required VoidCallback onTap,
  }) {
    final primario = FlumiTema.colorPrimario;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: seleccionada ? primario : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: seleccionada ? primario : primario.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              texto,
              style: TextStyle(
                fontSize: 13,
                fontWeight: seleccionada ? FontWeight.w600 : FontWeight.w500,
                color: seleccionada ? Colors.white : Colors.black87,
              ),
            ),
            if (seleccionada) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check, size: 16, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }

  Widget _botonAplicar(Color primario) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _aplicar,
            style: ElevatedButton.styleFrom(
              backgroundColor: primario,
              foregroundColor: Colors.white,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text('Aplicar filtros',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}

List<String> _valoresUsuario(String campo, Usuario usuario) {
  switch (campo) {
    case 'orientacion':
      return [orientacionTexto(usuario.orientacionSexual)];
    case 'que_busca':
      return [opcionTexto(opcionesQueBusca, usuario.queBusca)];
    case 'estado_civil':
      return [situacionTexto(usuario.situacionSentimental)];
    case 'hijos':
      return [hijosTexto(usuario.hijos)];
    case 'religion':
      return [religionTexto(usuario.religion)];
    case 'educacion':
      return [educacionTexto(usuario.educacion)];
    case 'trabajo':
      return [trabajoTexto(usuario.trabajo)];
    case 'fuma':
      return [tabacoTexto(usuario.fuma)];
    case 'bebe':
      return [alcoholTexto(usuario.bebe)];
    case 'mascotas':
      return [mascotasTexto(usuario.mascotas)];
    case 'tatuajes':
      return [tatuajesTexto(usuario.tatuajes)];
    case 'signo':
      return [signoTexto(usuario.signoZodiaco)];
    case 'personalidad':
      return listaPersonalidad(usuario.personalidad);
    case 'idiomas':
      return usuario.idiomas
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    case 'intereses':
      return usuario.intereses;
    default:
      return const [];
  }
}

int _alturaCmUsuario(Usuario usuario) {
  final s = usuario.altura.trim();
  final num = double.tryParse(s);
  if (num == null) return 0;
  if (num < 5) return (num * 100).round();
  return num.round();
}

String normalizarGenero(String valor) {
  return valor
      .toLowerCase()
      .replaceAll(' ', '')
      .replaceAll('_', '')
      .replaceAll('\u00e1', 'a')
      .replaceAll('\u00e9', 'e')
      .replaceAll('\u00ed', 'i')
      .replaceAll('\u00f3', 'o')
      .replaceAll('\u00fa', 'u')
      .replaceAll('\u00fc', 'u')
      .replaceAll('\u00f1', 'n');
}

double distanciaKmEntre(double lat1, double lon1, double lat2, double lon2) {
  const radioTierra = 6371.0;
  final rad = 3.141592653589793 / 180;
  final dLat = (lat2 - lat1) * rad;
  final dLon = (lon2 - lon1) * rad;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * rad) * math.cos(lat2 * rad) * math.sin(dLon / 2) * math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return radioTierra * c;
}

String _textoComparable(String valor) {
  final m = RegExp(r'[\p{L}\p{N}]', unicode: true).firstMatch(valor);
  return (m == null ? valor : valor.substring(m.start)).trim().toLowerCase();
}

bool cumpleFiltrosAvanzados(FiltrosEncuentros filtros, Usuario usuario) {
  final avazado = filtros.avanzado;
  if (avazado.isEmpty) return true;

  final alturaMin = avazado['altura_min'];
  if (alturaMin != null && alturaMin.isNotEmpty) {
    final min = int.tryParse(alturaMin.first);
    if (min != null && min > 140 && _alturaCmUsuario(usuario) < min) {
      return false;
    }
  }

  for (final entrada in avazado.entries) {
    final campo = entrada.key;
    if (campo == 'altura_min') continue;
    final seleccion = entrada.value;
    if (seleccion.isEmpty) continue;
    final seleccionNormalizada =
        {for (final s in seleccion) _textoComparable(s)};
    final valores = _valoresUsuario(campo, usuario);
    if (valores
        .every((v) => !seleccionNormalizada.contains(_textoComparable(v)))) {
      return false;
    }
  }
  return true;
}

/// Criterios base de búsqueda del perfil propio: "interesado en"
/// (busca_genero) y "rango de edad" (preferencia_edad_min/max). Se aplican
/// SIEMPRE, antes de los filtros que el usuario configure en la app.
bool cumpleCriteriosPerfil(Usuario propio, Usuario candidato) {
  final busca = (propio.buscaGenero ?? '').trim().toLowerCase();
  final sinRestriccion = busca.isEmpty ||
      busca == 'todos' ||
      busca == 'ambos' ||
      busca == 'prefiero_no_decirlo' ||
      busca == 'otro';
  if (!sinRestriccion) {
    final opciones = busca.split(',').map((g) => g.trim()).toSet();
    final generoCandidato = normalizarGenero(candidato.genero);
    final coincide = opciones.any((g) {
      switch (normalizarGenero(g)) {
        case 'hombres':
        case 'hombre':
          return generoCandidato == 'hombre' ||
              generoCandidato == 'hombretrans';
        case 'mujeres':
        case 'mujer':
          return generoCandidato == 'mujer' ||
              generoCandidato == 'mujertrans';
        case 'nobinarias':
        case 'nobinario':
          return generoCandidato == 'nobinario' ||
              generoCandidato == 'generofluido';
        default:
          return generoCandidato == normalizarGenero(g);
      }
    });
    if (!coincide) return false;
  }

  final min = propio.preferenciaEdadMin;
  final max = propio.preferenciaEdadMax;
  if (candidato.edad > 0 && (candidato.edad < min || candidato.edad > max)) {
    return false;
  }
  return true;
}

class _ParametroFiltro {
  final String id;
  final IconData icono;
  final String titulo;
  final List<String> opciones;
  final bool multi;

  _ParametroFiltro({
    required this.id,
    required this.icono,
    required this.titulo,
    required this.opciones,
    this.multi = false,
  });
}

// Mock para tests sin base de datos
enum _PlanTipoMock { gratis, plus, premium }

class _LimitesPlanMock {
  const _LimitesPlanMock();
}

class SuscripcionServicioMock with ChangeNotifier implements SuscripcionServicio {
  @override
  PlanTipo get planActual => PlanTipo.premium;
  @override
  LimitesPlan get limites => LimitesPlan.premium();
  @override
  bool get tienePlus => true;
  @override
  bool get tienePremium => true;
  @override
  bool get meGustasDisponiblesHoy => true;
  @override
  bool get superlikesDisponiblesHoy => true;

  @override
  Suscripcione? get suscripcionActual => null;
  @override
  UsosDiario? get usosHoy => null;
  @override
  bool get esGratis => false;
  @override
  bool get esPlus => false;
  @override
  bool get esPremium => true;
  @override
  Future<bool> puedeUsarMeGusta({bool revalidar = false}) async => true;
  @override
  Future<bool> puedeUsarDeshacer() async => true;
  @override
  Future<bool> puedeUsarSuperlike({bool revalidar = false}) async => true;
  @override
  Future<bool> puedeVerCerca() async => true;
  @override
  Future<bool> puedeVerVisitas(int visitasActuales) async => true;
  @override
  Future<bool> puedeVerHistorialLikes(int likesActuales) async => true;
  @override
  Future<void> registrarMeGusta() async {}
  @override
  Future<void> registrarDeshacer() async {}
  @override
  Future<void> registrarSuperlike() async {}
  @override
  Future<void> registrarVistaCerca() async {}
  @override
  Future<void> cargarSuscripcion() async {}
  @override
  Future<void> activarPlan(PlanTipo plan, {Duration? duracion}) async {}
  @override
  Future<void> renovarSiVencio() async {}
}
