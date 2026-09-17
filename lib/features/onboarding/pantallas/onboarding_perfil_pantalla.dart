import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utilidades/ubicacion_util.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/servicios/perfil_foto_servicio.dart';
import '../../../core/base_datos_local/database.dart';
import '../../../core/estilos/tema.dart';
import '../../../core/servicios/notificacion_servicio.dart';
import '../../../widgets_comunes/barra_progreso_rio.dart';
import '../../../widgets_comunes/foto_perfil.dart';
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
  final TextEditingController _anioCtrl = TextEditingController();
  TextEditingController? _mesAutoCtrl;
  FocusNode? _mesInnerFocus;

  static const _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  /// Mes como número 1-12: acepta dígitos ("05") o el nombre ("Mayo").
  int? _mesNumero() {
    final texto = (_mesAutoCtrl?.text ?? '').trim();
    if (texto.isEmpty) return null;
    final n = int.tryParse(texto);
    if (n != null && n >= 1 && n <= 12) return n;
    final idx = _meses.indexWhere(
        (m) => m.toLowerCase() == texto.toLowerCase());
    if (idx >= 0) return idx + 1;
    return null;
  }
  final _ubicacionCtrl = TextEditingController();
  double? _ubicacionLat;
  double? _ubicacionLon;
  final _formKeyUbicacion = GlobalKey<FormState>();
  final _focusUbicacion = FocusNode();
  String _genero = '';
  String _queBusca = '';
  final List<String> _fotos = [];
  // Bytes en memoria para previsualizar al instante (en web la ruta
  // blob no siempre resuelve como asset).
  final List<Uint8List?> _fotosBytes = [];
  String? _errorFecha;
  Map<String, List<String>> _provincias = const {};
  List<String> _opcionesUbicacion = const [];
  bool _cargandoUbicacion = true;
  bool _obteniendoUbicacion = false;
  TextEditingController? _autocompleteCtrl;

  static const _rutaJsonUbicacion = 'assets/data/cuba_provincias_municipios.json';

  int get _totalPasos => 7;

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
      if (perfil.ubicacionLat != 0 || perfil.ubicacionLon != 0) {
        _ubicacionLat = perfil.ubicacionLat;
        _ubicacionLon = perfil.ubicacionLon;
      }
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
    _anioCtrl.dispose();
    _ubicacionCtrl.dispose();
    _focusUbicacion.dispose();
    super.dispose();
  }

  static final _regexNombre = RegExp(r"^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ'\- ]+$");

  bool get _pasoValido {
    switch (_paso) {
      case 1:
        final nombre = _nombreCtrl.text.trim();
        return nombre.length >= 2 &&
            nombre.length <= 30 &&
            _regexNombre.hasMatch(nombre);
      case 2:
        return _errorFecha == null && _fechaValida;
      case 3:
        return _genero.isNotEmpty;
      case 4:
        return _queBusca.isNotEmpty;
      case 5:
        return _ubicacionCtrl.text.trim().isNotEmpty;
      case 6:
        return _fotos.isNotEmpty;
      default:
        return true;
    }
  }

  bool get _fechaValida {
    final d = int.tryParse(_diaCtrl.text);
    final m = _mesNumero();
    final a = int.tryParse(_anioCtrl.text);
    if (d == null || m == null || a == null) return false;
    if (d < 1 || d > 31 || m < 1 || m > 12 || a < 1900) return false;
    final fecha = DateTime(a, m, d);
    return fecha.day == d && fecha.month == m;
  }

  void _validarFecha() {
    final d = int.tryParse(_diaCtrl.text);
    final m = _mesNumero();
    final a = int.tryParse(_anioCtrl.text);
    if (d == null || m == null || a == null) {
      setState(() => _errorFecha = null);
      return;
    }
    if (d < 1 || d > 31 || m < 1 || m > 12 || a < 1900) {
      setState(() => _errorFecha = 'Fecha inválida');
      return;
    }
    final fecha = DateTime(a, m, d);
    if (fecha.day != d || fecha.month != m) {
      setState(() => _errorFecha = 'Fecha inválida');
      return;
    }
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
    if (!_pasoValido) return;

    if (_paso == 6 && _fotos.isNotEmpty) {
      await _subirFotosOnboarding();
    }

    if (_paso >= _totalPasos - 1) {
      if (mounted) widget.onCompletado();
      return;
    }

    await _guardarPaso();
    if (!mounted) return;
    _pageCtrl.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
  }

  Future<void> _asegurarFilaLocal() async {
    final existe = await (widget.db.select(widget.db.usuarios)
          ..where((u) => u.uuid.equals(widget.usuarioUuid)))
        .getSingleOrNull();
    if (existe == null) {
      await widget.db.into(widget.db.usuarios).insertOnConflictUpdate(
            UsuariosCompanion(
              uuid: Value(widget.usuarioUuid),
              nombre: const Value(''),
              edad: const Value(0),
              genero: const Value(''),
              buscaGenero: const Value(''),
              esPerfilPropio: const Value(true),
            ),
          );
    }
  }

  UsuariosCompanion? _companionDelPaso(int paso) {
    switch (paso) {
      case 1:
        return UsuariosCompanion(
          nombre: Value(_nombreCtrl.text.trim()),
          pendienteDeSincronizar: const Value(true),
        );
      case 2:
        final d = int.tryParse(_diaCtrl.text);
        final m = _mesNumero();
        final a = int.tryParse(_anioCtrl.text);
        if (d == null || m == null || a == null) return null;
        final fecha = DateTime(a, m, d);
        return UsuariosCompanion(
          fechaNacimiento: Value(fecha),
          edad: Value(_calcularEdad(fecha)),
          pendienteDeSincronizar: const Value(true),
        );
      case 3:
        return UsuariosCompanion(
          genero: Value(_genero.toLowerCase()),
          pendienteDeSincronizar: const Value(true),
        );
      case 4:
        String codigo = _queBusca;
        for (final o in opcionesQueBusca) {
          if (o.$1 == _queBusca) {
            codigo = o.$2;
            break;
          }
        }
        return UsuariosCompanion(
          queBusca: Value(codigo),
          pendienteDeSincronizar: const Value(true),
        );
      case 5:
        var companion = UsuariosCompanion(
          ciudad: Value(_ubicacionCtrl.text.trim()),
          pendienteDeSincronizar: const Value(true),
        );
        final coords = (_ubicacionLat != null && _ubicacionLon != null)
            ? (_ubicacionLat!, _ubicacionLon!)
            : _coordsDesdeTexto(_ubicacionCtrl.text);
        if (coords != null) {
          companion = companion.copyWith(
            ubicacionLat: Value(coords.$1),
            ubicacionLon: Value(coords.$2),
          );
        }
        return companion;
      default:
        return null;
    }
  }

  int _calcularEdad(DateTime nacimiento) {
    final hoy = DateTime.now();
    var edad = hoy.year - nacimiento.year;
    if (hoy.month < nacimiento.month ||
        (hoy.month == nacimiento.month && hoy.day < nacimiento.day)) {
      edad--;
    }
    return edad;
  }

  Future<void> _guardarPaso() async {
    final companion = _companionDelPaso(_paso);
    if (companion == null) return;
    await _asegurarFilaLocal();
    await (widget.db.update(widget.db.usuarios)
          ..where((u) => u.uuid.equals(widget.usuarioUuid)))
        .write(companion);
  }

  Future<void> _subirFotosOnboarding() async {
    await _asegurarFilaLocal();
    final perfil = await (widget.db.select(widget.db.usuarios)
          ..where((u) => u.uuid.equals(widget.usuarioUuid)))
        .getSingleOrNull();
    if (perfil == null) return;
    final locales = [...perfil.fotosLocalesRutas];
    final urls = [...perfil.fotosUrls];
    for (final ruta in _fotos) {
      if (locales.contains(ruta)) continue;
      locales.add(ruta);
      final url = await PerfilFotoServicio.subirFotoPerfil(
        usuarioId: widget.usuarioUuid,
        archivo: XFile(ruta),
      );
      if (url != null) {
        urls.add(url);
      }
    }
    await (widget.db.update(widget.db.usuarios)
          ..where((u) => u.uuid.equals(widget.usuarioUuid)))
        .write(
          UsuariosCompanion(
            fotosLocalesRutas: Value(locales),
            fotosUrls: Value(urls),
            pendienteDeSincronizar: const Value(true),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final primario = FlumiTema.colorPrimario;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            if (_paso > 0) _barraSuperior(primario),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _paso = i),
                // Sin swipe: solo se avanza con el botón (validado y guardado).
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _pasoBienvenida(primario),
                  _pasoNombre(primario),
                  _pasoFechaNacimiento(primario),
                  _pasoGenero(primario),
                  _pasoQueBusca(primario),
                  _pasoUbicacion(primario),
                  _pasoFotos(primario),
                ],
              ),
            ),
            _botonSiguiente(primario),
          ],
        ),
      ),
    );
  }

  Widget _barraSuperior(Color primario) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 24, 8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Material(
              color: Colors.grey[100],
              shape: const CircleBorder(),
              child: IconButton(
                onPressed: _atras,
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    color: Colors.grey, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: BarraProgresoRio(
              progreso: _paso / (_totalPasos - 1),
            ),
          ),
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: TextFormField(
          controller: _nombreCtrl,
          onChanged: (_) => setState(() {}),
          maxLength: 30,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: Colors.black87, fontSize: 15),
          textAlign: TextAlign.start,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[100],
            labelText: 'Nombre',
            labelStyle: const TextStyle(color: Colors.black45, fontSize: 14),
            floatingLabelStyle: TextStyle(color: primario, fontSize: 13),
            prefixIcon: Icon(Icons.person_outline, color: primario.withValues(alpha: 0.7), size: 20),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _pasoFechaNacimiento(Color primario) {
    return _pasoLayout(
      icono: Icons.cake_outlined,
      titulo: '¿Cuándo naciste?',
      subtitulo: 'Tu edad se mostrará en tu perfil.',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  flex: 8,
                  child: TextFormField(
                    controller: _diaCtrl,
                    onChanged: (valor) {
                      if (_diaCtrl.text.length >= 2) _enfocarMes();
                      _validarFecha();
                    },
                    keyboardType: TextInputType.number,
                    maxLength: 2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black87, fontSize: 16),
                    decoration: _campoFecha('Día', primario).copyWith(counterText: ''),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 14,
                  child: Autocomplete<String>(
                    optionsBuilder: (valor) {
                      final q = valor.text.trim().toLowerCase();
                      if (q.isEmpty) return _meses;
                      return _meses.where(
                          (m) => m.toLowerCase().contains(q));
                    },
                    displayStringForOption: (o) => o,
                    fieldViewBuilder: (context, ctrlTexto, focusTexto,
                        onFieldSubmitted) {
                      _mesAutoCtrl = ctrlTexto;
                      _mesInnerFocus = focusTexto;
                      return TextFormField(
                        controller: ctrlTexto,
                        focusNode: focusTexto,
                        onChanged: (_) => _validarFecha(),
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.words,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.black87, fontSize: 16),
                        decoration: _campoFecha('Mes', primario),
                      );
                    },
                    onSelected: (_) {
                      _validarFecha();
                      _enfocarAnio();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 10,
                  child: TextFormField(
                    controller: _anioCtrl,
                    focusNode: _anioFocus,
                    onChanged: (valor) {
                      if (_anioCtrl.text.length >= 4) _anioFocus.unfocus();
                      _validarFecha();
                    },
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black87, fontSize: 16),
                    decoration: _campoFecha('Año', primario).copyWith(counterText: ''),
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

  InputDecoration _campoFecha(String label, Color primario) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.grey[100],
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black45, fontSize: 14),
      floatingLabelStyle: TextStyle(color: primario, fontSize: 13),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
    );
  }

  final _anioFocus = FocusNode();

  void _enfocarMes() {
    _mesInnerFocus?.requestFocus();
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
      titulo: 'Agrega tus fotos',
      subtitulo: 'Sube al menos una foto (máx. 4). La primera será tu foto de perfil.',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
              children: List.generate(4, (index) {
                final tieneFoto = index < _fotos.length;
                return _celdaFotoOnboarding(index, tieneFoto ? _fotos[index] : null, primario);
              }),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Toca un recuadro para agregar una foto. Mínimo 1 obligatoria.',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _celdaFotoOnboarding(int index, String? ruta, Color primario) {
    final tieneFoto = ruta != null;
    final bytes =
        index < _fotosBytes.length ? _fotosBytes[index] : null;
    return GestureDetector(
      onTap: () async {
        final picker = ImagePicker();
        try {
          final foto = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024);
          if (foto != null) {
            Uint8List? datos;
            try {
              datos = await foto.readAsBytes();
            } catch (_) {}
            if (!mounted) return;
            setState(() {
              if (index < _fotos.length) {
                _fotos[index] = foto.path;
                if (index < _fotosBytes.length) {
                  _fotosBytes[index] = datos;
                } else {
                  _fotosBytes.add(datos);
                }
              } else {
                _fotos.add(foto.path);
                _fotosBytes.add(datos);
              }
            });
          }
        } catch (_) {}
      },
      child: Container(
        decoration: BoxDecoration(
          color: tieneFoto ? null : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: tieneFoto ? Colors.transparent : primario.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (bytes != null)
                Image.memory(bytes, fit: BoxFit.cover)
              else if (tieneFoto)
                imagenOrigen(ruta, fit: BoxFit.cover)
              else
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, color: primario.withValues(alpha: 0.5), size: 32),
                    const SizedBox(height: 8),
                    Text(
                      index == 0 ? 'Foto de perfil' : 'Foto extra',
                      style: TextStyle(fontSize: 12, color: primario.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              if (tieneFoto)
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _fotos.removeAt(index);
                      if (index < _fotosBytes.length) {
                        _fotosBytes.removeAt(index);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pasoUbicacion(Color primario) {
    return _pasoLayout(
      icono: Icons.location_on_outlined,
      titulo: 'Ubicación',
      subtitulo:
          'Comparte tu ubicación para conectar con personas cerca de ti. Solo se mostrará tu ciudad.',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Form(
          key: _formKeyUbicacion,
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
        final coord = coordenadasParaOpcion(opcion, _provincias);
        if (coord != null) {
          _ubicacionLat = coord.$1;
          _ubicacionLon = coord.$2;
        }
        setState(() {});
      },
    );
  }

  Future<void> _establecerUbicacion() async {
    setState(() => _obteniendoUbicacion = true);
    try {
      // El nombre se resuelve contra las opciones: asegura que estén cargadas.
      if (_provincias.isEmpty) {
        await _cargarOpcionesUbicacion();
      }
      final posicion = await obtenerUbicacionGps();
      final nombre = await resolverNombreUbicacion(
            latitud: posicion.lat,
            longitud: posicion.lon,
            provincias: _provincias,
          ) ??
          // Último recurso: tabla estática, siempre devuelve una provincia.
          provinciaMasCercanaDirecta(posicion.lat, posicion.lon);
      if (nombre.isEmpty) {
        if (!mounted) return;
        NotificacionServicio.alerta(
          context,
          'No se pudo obtener la ubicación. Intenta de nuevo o escríbela manualmente.',
        );
        return;
      }
      if (!mounted) return;
      _ubicacionCtrl.text = nombre;
      _autocompleteCtrl?.text = nombre;
      _ubicacionLat = posicion.lat;
      _ubicacionLon = posicion.lon;
      setState(() {});
      NotificacionServicio.exito(context, 'Ubicación establecida: $nombre');
    } on UbicacionException catch (e) {
      if (!mounted) return;
      NotificacionServicio.alerta(context, e.mensaje);
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

  /// Si el usuario escribió la ubicación a mano sin tocar ninguna sugerencia
  /// de la lista (o el toque no llegó a disparar `onSelected`), no hay
  /// lat/lon capturados. Antes de guardar, intentamos resolverlos igual
  /// comparando el texto final contra las opciones conocidas.
  (double, double)? _coordsDesdeTexto(String texto) {
    final normalizado = _normalizar(texto.trim().toLowerCase());
    if (normalizado.isEmpty) return null;
    for (final opcion in _opcionesUbicacion) {
      final coincideOpcion = _normalizar(opcion.toLowerCase()) == normalizado;
      final coincideEtiqueta =
          _normalizar(_etiqueta(opcion).toLowerCase()) == normalizado;
      if (coincideOpcion || coincideEtiqueta) {
        return coordenadasParaOpcion(opcion, _provincias);
      }
    }
    return null;
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

  void _atras() {
    if (_paso <= 0) return;
    _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
  }

  Widget _botonSiguiente(Color primario) {
    String texto = 'Continuar';
    if (_paso == 0) texto = 'Empezar';

    final siguiente = SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: !_pasoValido ? null : _siguiente,
        style: ElevatedButton.styleFrom(
          backgroundColor: primario,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          disabledBackgroundColor: primario.withValues(alpha: 0.3),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.5),
        ),
        child: Text(texto, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: siguiente,
      ),
    );
  }
}
