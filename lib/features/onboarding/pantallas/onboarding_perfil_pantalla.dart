import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/base_datos_local/database.dart';
import '../../../core/estilos/tema.dart';
import '../../../core/servicios/notificacion_servicio.dart';
import '../../../widgets_comunes/barra_progreso_rio.dart';
import '../../perfiles/perfil_etiquetas.dart';

class OnboardingPerfilPantalla extends StatefulWidget {
  final AppDatabase db;
  final String usuarioUuid;
  final VoidCallback onCompletado;

  const OnboardingPerfilPantalla({
    super.key,
    required this.db,
    required this.usuarioUuid,
    required this.onCompletado,
  });

  @override
  State<OnboardingPerfilPantalla> createState() => _OnboardingPerfilPantallaState();
}

class _OnboardingPerfilPantallaState extends State<OnboardingPerfilPantalla> {
  final _pageCtrl = PageController();
  int _paso = 0;

  final _nombreCtrl = TextEditingController();
  final TextEditingController _diaCtrl = TextEditingController();
  final TextEditingController _mesCtrl = TextEditingController();
  final TextEditingController _anioCtrl = TextEditingController();
  final _ubicacionCtrl = TextEditingController();
  final _formKeyUbicacion = GlobalKey<FormState>();
  final _focusUbicacion = FocusNode();
  String _genero = '';
  String _queBusca = '';
  final List<String> _fotos = [];
  bool _verificacionIniciada = false;
  String? _errorFecha;
  Map<String, List<String>> _provincias = const {};
  List<String> _opcionesUbicacion = const [];
  bool _cargandoUbicacion = true;
  bool _obteniendoUbicacion = false;
  TextEditingController? _autocompleteCtrl;

  static const _rutaJsonUbicacion = 'assets/data/cuba_provincias_municipios.json';

  int get _totalPasos => 8;

  @override
  void initState() {
    super.initState();
    _cargarDatosActuales();
    _cargarOpcionesUbicacion();
  }

  Future<void> _cargarDatosActuales() async {
    final perfil = await (widget.db.select(widget.db.usuarios)
          ..where((u) => u.uuid.equals(widget.usuarioUuid)))
        .getSingleOrNull();
    if (perfil != null && mounted) {
      _nombreCtrl.text = perfil.nombre;
      _ubicacionCtrl.text = perfil.ciudad;
    }
  }

  Future<void> _cargarOpcionesUbicacion() async {
    String json = '{}';
    try {
      json = await rootBundle.loadString(_rutaJsonUbicacion);
    } catch (_) {}
    final municipiosPorProvincia = <String, List<String>>{};
    final opciones = <String>{};
    final data = jsonDecode(json) as Map<String, dynamic>;
    final paises = data['paises'] as List? ?? const [];
    for (final pais in paises) {
      final provincias = (pais as Map<String, dynamic>)['provincias'];
      if (provincias is! List) continue;
      for (final p in provincias) {
        final provincia = (p as Map<String, dynamic>)['nombre'] as String? ?? '';
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
      _opcionesUbicacion = opciones.toList();
      _cargandoUbicacion = false;
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nombreCtrl.dispose();
    _diaCtrl.dispose();
    _mesCtrl.dispose();
    _anioCtrl.dispose();
    _ubicacionCtrl.dispose();
    _focusUbicacion.dispose();
    super.dispose();
  }

  bool get _pasoValido {
    switch (_paso) {
      case 1:
        return _nombreCtrl.text.trim().length >= 2;
      case 2:
        return _errorFecha == null && _fechaValida;
      case 3:
        return _genero.isNotEmpty;
      case 4:
        return _queBusca.isNotEmpty;
      case 5:
        return _ubicacionCtrl.text.trim().isNotEmpty;
      default:
        return true;
    }
  }

  bool get _fechaValida {
    final d = int.tryParse(_diaCtrl.text);
    final m = int.tryParse(_mesCtrl.text);
    final a = int.tryParse(_anioCtrl.text);
    if (d == null || m == null || a == null) return false;
    if (d < 1 || d > 31 || m < 1 || m > 12) return false;
    return true;
  }

  void _validarFecha() {
    final d = int.tryParse(_diaCtrl.text);
    final m = int.tryParse(_mesCtrl.text);
    final a = int.tryParse(_anioCtrl.text);
    if (d == null || m == null || a == null) {
      setState(() => _errorFecha = null);
      return;
    }
    if (d < 1 || d > 31 || m < 1 || m > 12) {
      setState(() => _errorFecha = 'Fecha inválida');
      return;
    }
    final fecha = DateTime(a, m, d);
    final hoy = DateTime.now();
    final edad = hoy.year - fecha.year -
        ((hoy.month < fecha.month || (hoy.month == fecha.month && hoy.day < fecha.day)) ? 1 : 0);
    if (edad < 18) {
      setState(() => _errorFecha = 'Debes tener al menos 18 años');
    } else {
      setState(() => _errorFecha = null);
    }
  }

  Future<void> _siguiente() async {
    if (_paso == 6) {
      if (_fotos.isEmpty) {
        setState(() => _paso++);
        _pageCtrl.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
        return;
      }
      await _tomarFoto();
    }

    if (_paso >= _totalPasos - 1) {
      if (mounted) widget.onCompletado();
      return;
    }

    _pageCtrl.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
  }

  Future<void> _tomarFoto() async {
    final picker = ImagePicker();
    try {
      final foto = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024);
      if (foto != null) {
        setState(() => _fotos.add(foto.path));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final primario = FlumiTema.colorPrimario;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            if (_paso > 0) _barraProgreso(primario),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _paso = i),
                physics: null,
                children: [
                  _pasoBienvenida(primario),
                  _pasoNombre(primario),
                  _pasoFechaNacimiento(primario),
                  _pasoGenero(primario),
                  _pasoQueBusca(primario),
                  _pasoUbicacion(primario),
                  _pasoFotos(primario),
                  _pasoVerificacion(primario),
                ],
              ),
            ),
            _botonSiguiente(primario),
          ],
        ),
      ),
    );
  }

  Widget _barraProgreso(Color primario) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: BarraProgresoRio(
        progreso: _paso / (_totalPasos - 1),
      ),
    );
  }

  Widget _pasoBienvenida(Color primario) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rocket_launch_outlined, size: 64, color: primario),
            const SizedBox(height: 20),
            Text('Completa tu perfil',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primario)),
            const SizedBox(height: 12),
            Text(
              'Cuéntanos un poco sobre ti para que podamos encontrar las mejores conexiones para ti.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Tus datos están seguros y nunca los compartiremos sin tu permiso.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pasoNombre(Color primario) {
    return _pasoLayout(
      icono: Icons.person_outline,
      titulo: '¿Cómo te llamas?',
      subtitulo: 'Este nombre aparecerá en tu perfil.',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: TextFormField(
          controller: _nombreCtrl,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 18),
          textAlign: TextAlign.center,
          decoration: _inputDeco('Tu nombre', primario),
        ),
      ),
    );
  }

  Widget _pasoFechaNacimiento(Color primario) {
    return _pasoLayout(
      icono: Icons.cake_outlined,
      titulo: '¿Cuándo naciste?',
      subtitulo: 'Debes tener al menos 18 años.',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _diaCtrl,
                    onChanged: (_) {
                      if (_diaCtrl.text.length >= 2) _enfocarMes();
                      _validarFecha();
                    },
                    keyboardType: TextInputType.number,
                    maxLength: 2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18),
                    decoration: _inputDeco('Día', primario).copyWith(counterText: ''),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _mesCtrl,
                    focusNode: _mesFocus,
                    onChanged: (_) {
                      if (_mesCtrl.text.length >= 2) _enfocarAnio();
                      _validarFecha();
                    },
                    keyboardType: TextInputType.number,
                    maxLength: 2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18),
                    decoration: _inputDeco('Mes', primario).copyWith(counterText: ''),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _anioCtrl,
                    focusNode: _anioFocus,
                    onChanged: (_) {
                      if (_anioCtrl.text.length >= 4) _anioFocus.unfocus();
                      _validarFecha();
                    },
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18),
                    decoration: _inputDeco('Año', primario).copyWith(counterText: ''),
                  ),
                ),
              ],
            ),
            if (_errorFecha != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_errorFecha!, style: TextStyle(color: Colors.red[400], fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }

  final _mesFocus = FocusNode();
  final _anioFocus = FocusNode();

  void _enfocarMes() {
    _mesFocus.requestFocus();
  }

  void _enfocarAnio() {
    _anioFocus.requestFocus();
  }

  Widget _pasoGenero(Color primario) {
    return _pasoLayout(
      icono: Icons.wc,
      titulo: '¿Cuál es tu género?',
      subtitulo: 'Puedes cambiarlo después en tu perfil.',
      child: _selector(opcionesGenero, _genero, (v) {
        setState(() => _genero = v);
      }, primario),
    );
  }

  Widget _pasoQueBusca(Color primario) {
    final opciones = [for (final o in opcionesQueBusca) o.$1];
    return _pasoLayout(
      icono: Icons.search_outlined,
      titulo: '¿Qué estás buscando?',
      subtitulo: 'Selecciona lo que mejor describa lo que quieres.',
      child: _selector(opciones, _queBusca, (v) => setState(() => _queBusca = v), primario),
    );
  }

  Widget _pasoFotos(Color primario) {
    return _pasoLayout(
      icono: Icons.add_a_photo_outlined,
      titulo: 'Agrega una foto',
      subtitulo: 'Las fotos ayudan a que te conozcan mejor.',
      child: Column(
        children: [
          if (_fotos.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _fotos.map((path) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(path),
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: -4,
                      right: -4,
                      child: GestureDetector(
                        onTap: () => setState(() => _fotos.remove(path)),
                        child: const Icon(Icons.cancel, color: Colors.red, size: 22),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _tomarFoto,
            icon: Icon(Icons.add_photo_alternate_outlined, color: primario, size: 22),
            label: Text('Seleccionar foto', style: TextStyle(color: primario)),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => _pageCtrl.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut),
            child: Text('Omitir', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _pasoVerificacion(Color primario) {
    return _pasoLayout(
      icono: Icons.verified_outlined,
      titulo: 'Verifica tu perfil',
      subtitulo:
          'Confirma tu identidad para aumentar la confianza y obtener más coincidencias.',
      child: _permisoBoton(
        icono: _verificacionIniciada ? Icons.check_circle : Icons.verified_outlined,
        label: _verificacionIniciada ? 'Perfil en proceso de verificación' : 'Verificar perfil',
        activo: _verificacionIniciada,
        primario: primario,
        onTap: _verificacionIniciada ? null : () => setState(() => _verificacionIniciada = true),
      ),
    );
  }

  Widget _pasoUbicacion(Color primario) {
    return _pasoLayout(
      icono: Icons.location_on_outlined,
      titulo: 'Comparte tu ubicación',
      subtitulo:
          'Comparte tu ubicación para conectar con personas cerca de ti. Solo se mostrará tu ciudad.',
      child: Form(
        key: _formKeyUbicacion,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: _cargandoUbicacion
            ? const SizedBox(
                height: 40,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _campoUbicacion(primario),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _obteniendoUbicacion
                          ? null
                          : _establecerUbicacion,
                      icon: _obteniendoUbicacion
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location, size: 20),
                      label: const Text('Usar mi ubicación actual'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primario,
                        side: BorderSide(color: primario.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _campoUbicacion(Color primario) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue texto) {
        if (texto.text.trim().isEmpty) return const Iterable<String>.empty();
        final consulta = _normalizar(texto.text.trim().toLowerCase());
        return _opcionesUbicacion.where((opcion) =>
            _normalizar(opcion.toLowerCase()).contains(consulta));
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
        return TextFormField(
          controller: controladorTexto,
          focusNode: focusNodeTexto,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Ingresa tu ubicación';
            return null;
          },
          onChanged: (v) {
            _ubicacionCtrl.text = v;
            setState(() {});
          },
          onFieldSubmitted: (_) => onFieldSubmitted(),
          style: const TextStyle(color: Colors.black87, fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[100],
            labelText: 'Ubicación',
            labelStyle: const TextStyle(color: Colors.black45, fontSize: 14),
            prefixIcon:
                Icon(Icons.location_on_outlined, color: primario.withValues(alpha: 0.7), size: 20),
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
                      _focusUbicacion.unfocus();
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
        setState(() {});
      },
    );
  }

  Future<void> _establecerUbicacion() async {
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
      final placemarks = await placemarkFromCoordinates(
        posicion.latitude,
        posicion.longitude,
      );
      if (placemarks.isNotEmpty) {
        final pm = placemarks.first;
        final nombresPosibles = [
          pm.locality,
          pm.subAdministrativeArea,
          pm.administrativeArea,
        ].whereType<String>().where((n) => n.trim().isNotEmpty).toList();
        String? encontrado;
        for (final opcion in _opcionesUbicacion) {
          final normal = _normalizar(opcion.toLowerCase());
          final match = nombresPosibles.any((n) =>
              _normalizar(n.toLowerCase()).contains(normal) ||
              normal.contains(_normalizar(n.toLowerCase())));
          if (match) {
            encontrado = opcion;
            break;
          }
        }
        if (!mounted) return;
        final textoFinal = encontrado ?? nombresPosibles.first;
        _ubicacionCtrl.text = textoFinal;
        _autocompleteCtrl?.text = textoFinal;
        setState(() {});
        if (encontrado != null) {
          NotificacionServicio.exito(
            context,
            'Ubicación establecida: $textoFinal',
          );
        } else {
          NotificacionServicio.advertencia(
            context,
            'Ubicación detectada: $textoFinal. Verifícala y edítala si es necesario.',
          );
        }
      } else {
        if (!mounted) return;
        NotificacionServicio.alerta(
          context,
          'No se pudo obtener la dirección a partir de las coordenadas. Intenta de nuevo o escribe la ubicación manualmente.',
        );
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      String mensaje;
      switch (e.code) {
        case 'location_unavailable':
          mensaje = 'Ubicación no disponible. Verifica la señal GPS e intenta de nuevo.';
          break;
        case 'permission_denied':
          mensaje = 'Permiso de ubicación denegado.';
          break;
        case 'timeout':
          mensaje = 'Tiempo de espera agotado para obtener la ubicación. Intenta de nuevo.';
          break;
        case 'service_not_available':
          mensaje = 'Servicio de ubicación no disponible en este dispositivo.';
          break;
        default:
          mensaje = 'Error del GPS. Intenta de nuevo.';
      }
      NotificacionServicio.alerta(context, mensaje);
    } on SocketException {
      if (!mounted) return;
      NotificacionServicio.alerta(
        context,
        'Sin conexión a internet. El GPS funciona, pero la geocodificación inversa (convertir coordenadas a dirección) requiere internet. Escribe la ubicación manualmente o intenta más tarde.',
      );
    } on TimeoutException {
      if (!mounted) return;
      NotificacionServicio.alerta(
        context,
        'Tiempo de espera agotado al obtener la ubicación. Verifica la señal GPS e intenta de nuevo.',
      );
    } catch (_) {
      if (!mounted) return;
      NotificacionServicio.alerta(
        context,
        'Algo salió mal. Escribe tu ubicación manualmente o intenta más tarde.',
      );
    } finally {
      if (mounted) setState(() => _obteniendoUbicacion = false);
    }
  }

  String _normalizar(String valor) {
    return valor
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
  }

  String _etiqueta(String opcion) {
    if (_provincias.containsKey(opcion)) return opcion;
    final provincia = _provincias.entries
        .where((e) => e.value.contains(opcion))
        .map((e) => e.key)
        .firstOrNull;
    return provincia == null ? opcion : '$opcion, $provincia';
  }

  InputDecoration _inputDeco(String hint, Color primario) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primario.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primario, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
    );
  }

  Widget _permisoBoton({
    required IconData icono,
    required String label,
    required bool activo,
    required Color primario,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: activo ? Colors.green.withValues(alpha: 0.1) : primario.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: activo ? Colors.green : primario.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, color: activo ? Colors.green : primario, size: 24),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: activo ? Colors.green : primario,
                )),
          ],
        ),
      ),
    );
  }

  Widget _pasoLayout({
    required IconData icono,
    required String titulo,
    required String subtitulo,
    required Widget child,
  }) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 56, color: FlumiTema.colorPrimario),
            const SizedBox(height: 16),
            Text(titulo, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(subtitulo,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    );
  }

  Widget _selector(List<String> opciones, String seleccion, ValueChanged<String> onChanged, Color primario) {
    final bgClaro = primario.withValues(alpha: 0.08);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: opciones.map((o) {
          final selected = o == seleccion;
          return GestureDetector(
            onTap: () => onChanged(o),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                color: selected ? primario : bgClaro,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: selected ? primario : Colors.grey[300]!,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Text(
                o,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? Colors.white : Colors.grey[700],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _botonSiguiente(Color primario) {
    final esUltimo = _paso >= _totalPasos - 1;
    String texto = 'Continuar';
    if (_paso == 0) texto = 'Empezar';
    else if (esUltimo) texto = 'Continuar';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: !_pasoValido ? null : _siguiente,
            style: ElevatedButton.styleFrom(
              backgroundColor: primario,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text(texto, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}
