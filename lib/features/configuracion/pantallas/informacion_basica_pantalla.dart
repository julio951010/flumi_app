import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:drift/drift.dart' hide Column;

import '../../perfiles/perfil_repositorio.dart';
import '../../../core/base_datos_local/database.dart';
import '../../../core/servicios/notificacion_servicio.dart';

class InformacionBasicaPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;

  const InformacionBasicaPantalla({super.key, required this.repositorio});

  @override
  State<InformacionBasicaPantalla> createState() =>
      _InformacionBasicaPantallaState();
}

class _InformacionBasicaPantallaState extends State<InformacionBasicaPantalla> {
  Usuario? _perfil;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() {
      _perfil = perfil;
      _cargando = false;
    });
  }

  String _fechaTexto(Usuario? p) {
    final f = p?.fechaNacimiento;
    if (f == null) return 'Sin definir';
    return '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
  }

  String _capitalizar(String v) {
    if (v.isEmpty) return 'Sin definir';
    return v[0].toUpperCase() + v.substring(1);
  }

  void _abrir(Widget pagina) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => pagina)).then((_) {
      if (mounted) _cargar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final secundario = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Información Básica',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  _item(
                    context,
                    Icons.person_outline,
                    'Nombre',
                    (_perfil?.nombre ?? 'Sin definir'),
                    secundario,
                    () => _abrir(ActualizarNombrePantalla(
                        repositorio: widget.repositorio)),
                  ),
                  const Divider(height: 1),
                  _item(
                    context,
                    Icons.cake_outlined,
                    'Fecha de nacimiento',
                    _fechaTexto(_perfil),
                    secundario,
                    () => _abrir(ActualizarFechaPantalla(
                        repositorio: widget.repositorio)),
                  ),
                  const Divider(height: 1),
                  _item(
                    context,
                    Icons.wc_outlined,
                    'Género',
                    _capitalizar(_perfil?.genero ?? ''),
                    secundario,
                    () => _abrir(ActualizarGeneroPantalla(
                        repositorio: widget.repositorio)),
                  ),
                  const Divider(height: 1),
                  _item(
                    context,
                    Icons.location_on_outlined,
                    'Ubicación',
                    (_perfil?.ciudad ?? '').isEmpty
                        ? 'Sin definir'
                        : _perfil!.ciudad,
                    secundario,
                    () => _abrir(ActualizarUbicacionPantalla(
                        repositorio: widget.repositorio)),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _item(BuildContext context, IconData icono, String titulo,
      String valor, Color secundario, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icono, color: secundario),
      title: Text(titulo),
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
}

class ActualizarNombrePantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;

  const ActualizarNombrePantalla({super.key, required this.repositorio});

  @override
  State<ActualizarNombrePantalla> createState() =>
      _ActualizarNombrePantallaState();
}

class _ActualizarNombrePantallaState extends State<ActualizarNombrePantalla> {
  static final _regexPermitido = RegExp(r"^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ'\- ]+$");

  final _nombreCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() {
      if (perfil != null) _nombreCtrl.text = perfil.nombre;
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final perfil = await widget.repositorio.obtenerPerfilPropio();
      if (perfil == null) {
        NotificacionServicio.alerta(context, 'No se encontró tu perfil.');
        return;
      }
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        nombre: Value(_nombreCtrl.text.trim()),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(context, 'Nombre actualizado correctamente.');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      NotificacionServicio.alerta(context, e.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  String? _validar(String? v) {
    final valor = v?.trim() ?? '';
    if (valor.isEmpty) return 'Ingresa tu nombre';
    if (valor.length < 2) return 'El nombre debe tener al menos 2 caracteres';
    if (valor.length > 30) return 'El nombre no puede superar los 30 caracteres';
    if (!_regexPermitido.hasMatch(valor)) {
      return 'Solo letras, espacios, guiones y apóstrofes';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Nombre',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '¿Cómo quieres que te llamen en la app?',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              Form(
                                key: _formKey,
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                child: TextFormField(
                                  controller: _nombreCtrl,
                                  maxLength: 30,
                                  textCapitalization:
                                      TextCapitalization.words,
                                  style: const TextStyle(
                                      color: Colors.black87, fontSize: 15),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                    hintText: 'Tu nombre',
                                    hintStyle: const TextStyle(
                                        color: Colors.black45, fontSize: 14),
                                    prefixIcon: Icon(Icons.person_outline,
                                        color: primario.withValues(alpha: 0.7),
                                        size: 20),
                                    border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                          color: primario.withValues(
                                              alpha: 0.3)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                          color: primario.withValues(
                                              alpha: 0.3)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                          color: primario, width: 1.5),
                                    ),
                                    contentPadding: const EdgeInsets
                                        .symmetric(
                                        horizontal: 14, vertical: 14),
                                  ),
                                  validator: _validar,
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: primario,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _guardando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Guardar',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class ActualizarFechaPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;

  const ActualizarFechaPantalla({super.key, required this.repositorio});

  @override
  State<ActualizarFechaPantalla> createState() =>
      _ActualizarFechaPantallaState();
}

class _ActualizarFechaPantallaState extends State<ActualizarFechaPantalla> {
  final _diaCtrl = TextEditingController();
  final _mesCtrl = TextEditingController();
  final _anioCtrl = TextEditingController();
  final _mesFocus = FocusNode();
  final _anioFocus = FocusNode();
  bool _cargando = true;
  bool _guardando = false;
  String? _errorFecha;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _diaCtrl.dispose();
    _mesCtrl.dispose();
    _anioCtrl.dispose();
    _mesFocus.dispose();
    _anioFocus.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() {
      final f = perfil?.fechaNacimiento;
      if (f != null) {
        _diaCtrl.text = f.day.toString().padLeft(2, '0');
        _mesCtrl.text = f.month.toString().padLeft(2, '0');
        _anioCtrl.text = f.year.toString();
      }
      _cargando = false;
    });
  }

  DateTime? get _fechaParseada {
    final d = int.tryParse(_diaCtrl.text);
    final m = int.tryParse(_mesCtrl.text);
    final a = int.tryParse(_anioCtrl.text);
    if (d == null || m == null || a == null) return null;
    if (d < 1 || d > 31 || m < 1 || m > 12 || a < 1900) return null;
    final fecha = DateTime(a, m, d);
    if (fecha.day != d || fecha.month != m || fecha.year != a) return null;
    return fecha;
  }

  int _calcularEdad(DateTime fecha) {
    final ahora = DateTime.now();
    return ahora.year -
        fecha.year -
        ((ahora.month < fecha.month ||
                (ahora.month == fecha.month && ahora.day < fecha.day))
            ? 1
            : 0);
  }

  void _validarFecha() {
    final fecha = _fechaParseada;
    if (fecha == null) {
      setState(() => _errorFecha = null);
      return;
    }
    if (_calcularEdad(fecha) < 18) {
      setState(() => _errorFecha = 'Debes tener al menos 18 años.');
    } else {
      setState(() => _errorFecha = null);
    }
  }

  void _enfocarMes() => _mesFocus.requestFocus();

  void _enfocarAnio() => _anioFocus.requestFocus();

  Future<void> _guardar() async {
    final fecha = _fechaParseada;
    if (fecha == null) {
      NotificacionServicio.alerta(context, 'Ingresa una fecha válida.');
      return;
    }
    if (_calcularEdad(fecha) < 18) {
      NotificacionServicio.alerta(context, 'Debes tener al menos 18 años.');
      return;
    }
    setState(() => _guardando = true);
    try {
      final perfil = await widget.repositorio.obtenerPerfilPropio();
      if (perfil == null) {
        NotificacionServicio.alerta(context, 'No se encontró tu perfil.');
        return;
      }
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        edad: Value(_calcularEdad(fecha)),
        fechaNacimiento: Value(fecha),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(
          context, 'Fecha de nacimiento actualizada correctamente.');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      NotificacionServicio.alerta(context, e.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Fecha de nacimiento',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                  Text(
                    'Tu edad se mostrará en tu perfil.',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 110,
                        child: TextFormField(
                          controller: _diaCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.black87, fontSize: 16),
                          onChanged: (valor) {
                            if (_diaCtrl.text.length >= 2) _enfocarMes();
                            _validarFecha();
                          },
                          decoration: _campoFecha('Día', primario)
                              .copyWith(counterText: ''),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 110,
                        child: TextFormField(
                          controller: _mesCtrl,
                          focusNode: _mesFocus,
                          keyboardType: TextInputType.number,
                          maxLength: 2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.black87, fontSize: 16),
                          onChanged: (valor) {
                            if (_mesCtrl.text.length >= 2) _enfocarAnio();
                            _validarFecha();
                          },
                          decoration: _campoFecha('Mes', primario)
                              .copyWith(counterText: ''),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 120,
                        child: TextFormField(
                          controller: _anioCtrl,
                          focusNode: _anioFocus,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.black87, fontSize: 16),
                          onChanged: (valor) {
                            if (_anioCtrl.text.length >= 4) {
                              _anioFocus.unfocus();
                            }
                            _validarFecha();
                          },
                          decoration: _campoFecha('Año', primario)
                              .copyWith(counterText: ''),
                        ),
                      ),
                    ],
                  ),
                  if (_errorFecha != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _errorFecha!,
                        style: TextStyle(color: Colors.red[400], fontSize: 13),
                      ),
                    ),
                  if (_fechaParseada != null && _errorFecha == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        decoration: BoxDecoration(
                          color: primario.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: primario.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '${_calcularEdad(_fechaParseada!)} a\u00f1os',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: primario,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      );
    },
  ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: primario,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _guardando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Guardar',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class ActualizarGeneroPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;

  const ActualizarGeneroPantalla({super.key, required this.repositorio});

  @override
  State<ActualizarGeneroPantalla> createState() =>
      _ActualizarGeneroPantallaState();
}

class _ActualizarGeneroPantallaState extends State<ActualizarGeneroPantalla> {
  static const _opcionesGenero = [
    'Mujer',
    'Hombre',
    'Mujer trans',
    'Hombre trans',
    'No binario',
    'Género fluido',
    'Prefiero no decirlo',
  ];

  final _personalizadaCtrl = TextEditingController();
  String _seleccion = '';
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _personalizadaCtrl.dispose();
    super.dispose();
  }

  String _capitalizar(String v) {
    if (v.isEmpty) return '';
    return v[0].toUpperCase() + v.substring(1);
  }

  Future<void> _cargar() async {
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() {
      final valor = perfil?.genero ?? '';
      final etiqueta = _capitalizar(valor);
      if (_opcionesGenero.contains(etiqueta)) {
        _seleccion = etiqueta;
      } else if (valor.isNotEmpty) {
        _personalizadaCtrl.text = valor;
      }
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    final texto = _personalizadaCtrl.text.trim();
    if (_seleccion.isEmpty && texto.isEmpty) {
      NotificacionServicio.alerta(
          context, 'Selecciona una opción o escribe la tuya.');
      return;
    }
    final valor = _seleccion.isNotEmpty ? _seleccion.toLowerCase() : texto;
    setState(() => _guardando = true);
    try {
      final perfil = await widget.repositorio.obtenerPerfilPropio();
      if (perfil == null) {
        NotificacionServicio.alerta(context, 'No se encontró tu perfil.');
        return;
      }
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        genero: Value(valor),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(
          context, 'Género actualizado correctamente.');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      NotificacionServicio.alerta(context, e.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Género',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '¿Cómo te identificas?',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 14),
                              ),
                              const SizedBox(height: 20),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final anchoTarjeta =
                                      (constraints.maxWidth - 10) / 2;
                                  return Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      for (final opcion in _opcionesGenero)
                                        if (opcion == 'Prefiero no decirlo')
                                          SizedBox(
                                            width: double.infinity,
                                            child: _tarjetaOpcion(
                                                opcion, primario),
                                          )
                                        else
                                          SizedBox(
                                            width: anchoTarjeta,
                                            child: _tarjetaOpcion(
                                                opcion, primario),
                                          ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 24),
                              TextField(
                                controller: _personalizadaCtrl,
                                enabled: !_guardando,
                                onChanged: (v) {
                                  if (v.trim().isNotEmpty &&
                                      _seleccion.isNotEmpty) {
                                    setState(() => _seleccion = '');
                                  }
                                },
                                style: const TextStyle(
                                    color: Colors.black87, fontSize: 15),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  labelText:
                                      '¿No encuentras el tuyo? Escríbelo aquí',
                                  labelStyle: const TextStyle(
                                      color: Colors.black45, fontSize: 13),
                                  prefixIcon: Icon(Icons.edit_outlined,
                                      color: primario.withValues(alpha: 0.7),
                                      size: 20),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color:
                                            primario.withValues(alpha: 0.3)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color:
                                            primario.withValues(alpha: 0.3)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: primario, width: 1.5),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 14),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: primario,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _guardando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Guardar',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tarjetaOpcion(String opcion, Color primario) {
    final seleccionada = _seleccion == opcion;
    return InkWell(
      onTap: _guardando
          ? null
          : () {
              setState(() {
                if (_seleccion == opcion) {
                  _seleccion = '';
                } else {
                  _seleccion = opcion;
                  _personalizadaCtrl.clear();
                }
              });
            },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: seleccionada
              ? primario.withValues(alpha: 0.10)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: seleccionada
                ? primario
                : primario.withValues(alpha: 0.3),
            width: seleccionada ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                opcion,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight:
                      seleccionada ? FontWeight.w600 : FontWeight.w500,
                  color: seleccionada ? primario : Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              seleccionada ? Icons.check_circle : Icons.circle_outlined,
              size: 22,
              color: seleccionada ? primario : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}

class ActualizarUbicacionPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;

  const ActualizarUbicacionPantalla({super.key, required this.repositorio});

  @override
  State<ActualizarUbicacionPantalla> createState() =>
      _ActualizarUbicacionPantallaState();
}

class _ActualizarUbicacionPantallaState
    extends State<ActualizarUbicacionPantalla> {
  static const _rutaJson =
      'assets/data/cuba_provincias_municipios.json';

  final _ubicacionCtrl = TextEditingController();
  TextEditingController? _autocompleteCtrl;
  final _formKey = GlobalKey<FormState>();
  final _focusNode = FocusNode();
  bool _cargando = true;
  bool _guardando = false;
  bool _obteniendoUbicacion = false;
  Map<String, List<String>> _provincias = const {};
  List<String> _opciones = const [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _ubicacionCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    String json = '{}';
    try {
      json = await rootBundle.loadString(_rutaJson);
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
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() {
      _provincias = municipiosPorProvincia;
      _opciones = opciones.toList();
      if (perfil != null) _ubicacionCtrl.text = perfil.ciudad;
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final perfil = await widget.repositorio.obtenerPerfilPropio();
      if (perfil == null) {
        NotificacionServicio.alerta(context, 'No se encontró tu perfil.');
        return;
      }
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        ciudad: Value(_ubicacionCtrl.text.trim()),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(context, 'Ubicación actualizada correctamente.');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      NotificacionServicio.alerta(context, e.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
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
        for (final opcion in _opciones) {
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
    } catch (e) {
      if (!mounted) return;
      NotificacionServicio.alerta(
        context,
        'Algo salió mal. Escribe tu ubicación manualmente o intenta más tarde.',
      );
    } finally {
      if (mounted) setState(() => _obteniendoUbicacion = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Ubicación',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Comparte tu ubicación para conectar con personas cerca de ti. Solo se mostrará tu ciudad.',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              Form(
                                key: _formKey,
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                child: Column(
                                  children: [
                                    _campoUbicacion(
                                      controlador: _ubicacionCtrl,
                                      label: 'Ubicación',
                                      icono: Icons.location_on_outlined,
                                      primario: primario,
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Ingresa tu ubicación';
                                        }
                                        return null;
                                      },
                                    ),
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
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2),
                                              )
                                            : const Icon(Icons.my_location,
                                                size: 20),
                                        label: const Text(
                                            'Usar mi ubicación actual'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: primario,
                                          side: BorderSide(
                                              color: primario.withValues(
                                                  alpha: 0.5)),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: primario,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _guardando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Guardar',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _campoUbicacion({
    required TextEditingController controlador,
    required String label,
    required IconData icono,
    required Color primario,
    required String? Function(String?) validator,
  }) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue texto) {
        if (texto.text.trim().isEmpty) return const Iterable<String>.empty();
        final consulta = _normalizar(texto.text.trim().toLowerCase());
        return _opciones.where((opcion) =>
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
          validator: validator,
          onChanged: (v) => _ubicacionCtrl.text = v,
          onFieldSubmitted: (_) => onFieldSubmitted(),
          style: const TextStyle(color: Colors.black87, fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[100],
            labelText: label,
            labelStyle: const TextStyle(color: Colors.black45, fontSize: 14),
            prefixIcon:
                Icon(icono, color: primario.withValues(alpha: 0.7), size: 20),
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
                      _focusNode.unfocus();
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
      },
    );
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
    if (_provincias.containsKey(opcion)) {
      return opcion;
    }
    final provincia = _provincias.entries
        .where((e) => e.value.contains(opcion))
        .map((e) => e.key)
        .firstOrNull;
    return provincia == null ? opcion : '$opcion, $provincia';
  }
}
