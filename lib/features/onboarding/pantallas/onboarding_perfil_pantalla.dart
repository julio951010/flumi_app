import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/base_datos_local/database.dart';
import '../../../core/estilos/tema.dart';
import '../../../widgets_comunes/barra_progreso_rio.dart';

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
  String _genero = '';
  String _subGenero = '';
  String _buscaGenero = '';
  String _subBuscaGenero = '';
  String _queBusca = '';
  final List<String> _fotos = [];
  bool _notificacionesConcedido = false;
  bool _ubicacionConcedido = false;
  String? _errorFecha;

  static const _opcionesGenero = ['Hombre', 'Mujer', 'Otro'];
  static const _subGeneros = [
    'No binario', 'Género fluido', 'Agénero', 'Bigénero',
    'Transgénero', 'Transexual', 'Intersexual', 'Queer',
    'Prefiero no decirlo',
  ];
  static const _opcionesBusca = ['Hombres', 'Mujeres', 'Todos', 'Otro'];
  static final _subBusca = ['Ambos', 'No binario', 'Género fluido', 'Agénero', 'Todos los géneros', 'Prefiero no decirlo'];
  static const _opcionesQueBusca = [
    'Relación seria',
    'Algo casual',
    'Amistad',
    'Aún no lo sé',
  ];

  int get _totalPasos => 9;

  @override
  void initState() {
    super.initState();
    _cargarDatosActuales();
  }

  Future<void> _cargarDatosActuales() async {
    final perfil = await (widget.db.select(widget.db.usuarios)
          ..where((u) => u.uuid.equals(widget.usuarioUuid)))
        .getSingleOrNull();
    if (perfil != null && mounted) {
      _nombreCtrl.text = perfil.nombre;
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nombreCtrl.dispose();
    _diaCtrl.dispose();
    _mesCtrl.dispose();
    _anioCtrl.dispose();
    super.dispose();
  }

  bool get _pasoValido {
    switch (_paso) {
      case 1:
        return _nombreCtrl.text.trim().length >= 2;
      case 2:
        return _errorFecha == null && _fechaValida;
      case 3:
        return _genero.isNotEmpty && (_genero != 'Otro' || _subGenero.isNotEmpty);
      case 4:
        return _buscaGenero.isNotEmpty && (_buscaGenero != 'Otro' || _subBuscaGenero.isNotEmpty);
      case 5:
        return _queBusca.isNotEmpty;
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
    if (_paso == 3 && _genero == 'Otro' && _subGenero.isEmpty) return;
    if (_paso == 4 && _buscaGenero == 'Otro' && _subBuscaGenero.isEmpty) return;
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

    if (_paso == 7) _notificacionesConcedido = true;
    if (_paso == 8) _ubicacionConcedido = true;

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
                  _pasoBusca(primario),
                  _pasoQueBusca(primario),
                  _pasoFotos(primario),
                  _pasoNotificaciones(primario),
                  _pasoUbicacion(primario),
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
    final mostrandoSub = _genero == 'Otro';
    return _pasoLayout(
      icono: Icons.wc,
      titulo: '¿Cuál es tu género?',
      subtitulo: 'Puedes cambiarlo después en tu perfil.',
      child: Column(
        children: [
          _selector(_opcionesGenero, _genero, (v) {
            setState(() {
              _genero = v;
              if (v != 'Otro') _subGenero = '';
            });
          }, primario),
          if (mostrandoSub) ...[
            const SizedBox(height: 16),
            _dropdownSub(_subGeneros, _subGenero, (v) => setState(() => _subGenero = v), primario),
          ],
        ],
      ),
    );
  }

  Widget _pasoBusca(Color primario) {
    final mostrandoSub = _buscaGenero == 'Otro';
    return _pasoLayout(
      icono: Icons.favorite_outline,
      titulo: '¿A quién te gustaría conocer?',
      subtitulo: 'Define tus preferencias.',
      child: Column(
        children: [
          _selector(_opcionesBusca, _buscaGenero, (v) {
            setState(() {
              _buscaGenero = v;
              if (v != 'Otro') _subBuscaGenero = '';
            });
          }, primario),
          if (mostrandoSub) ...[
            const SizedBox(height: 16),
            _dropdownSub(_subBusca, _subBuscaGenero, (v) => setState(() => _subBuscaGenero = v), primario),
          ],
        ],
      ),
    );
  }

  Widget _pasoQueBusca(Color primario) {
    return _pasoLayout(
      icono: Icons.search_outlined,
      titulo: '¿Qué estás buscando?',
      subtitulo: 'Selecciona lo que mejor describa lo que quieres.',
      child: _selector(_opcionesQueBusca, _queBusca, (v) => setState(() => _queBusca = v), primario),
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

  Widget _pasoNotificaciones(Color primario) {
    return _pasoLayout(
      icono: Icons.notifications_outlined,
      titulo: 'Activa las notificaciones',
      subtitulo: 'Te avisaremos cuando tengas matches, mensajes y más.',
      child: _permisoBoton(
        icono: _notificacionesConcedido ? Icons.check_circle : Icons.notifications_off_outlined,
        label: _notificacionesConcedido ? 'Notificaciones activadas' : 'Activar notificaciones',
        activo: _notificacionesConcedido,
        primario: primario,
        onTap: _notificacionesConcedido ? null : () => setState(() => _notificacionesConcedido = true),
      ),
    );
  }

  Widget _pasoUbicacion(Color primario) {
    return _pasoLayout(
      icono: Icons.location_on_outlined,
      titulo: 'Comparte tu ubicación',
      subtitulo: 'Te mostraremos personas cerca de ti.',
      child: _permisoBoton(
        icono: _ubicacionConcedido ? Icons.check_circle : Icons.location_off_outlined,
        label: _ubicacionConcedido ? 'Ubicación compartida' : 'Compartir ubicación',
        activo: _ubicacionConcedido,
        primario: primario,
        onTap: _ubicacionConcedido ? null : () => setState(() => _ubicacionConcedido = true),
      ),
    );
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

  Widget _dropdownSub(List<String> opciones, String seleccion, ValueChanged<String> onChanged, Color primario) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        border: Border.all(color: primario.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: seleccion.isNotEmpty ? seleccion : null,
            hint: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text('Selecciona una opción',
                  style: TextStyle(color: Colors.grey[500], fontSize: 15)),
            ),
            isExpanded: true,
            items: opciones.map((o) {
              return DropdownMenuItem(value: o, child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(o, style: const TextStyle(fontSize: 15)),
              ));
            }).toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
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
