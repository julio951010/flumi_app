import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;

import '../../../core/base_datos_local/database.dart';
import '../../../core/base_datos_local/tables.dart';
import '../../../core/servicios/notificacion_servicio.dart';
import '../perfil_repositorio.dart';

class CampoTextoPerfilPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;
  final String titulo;
  final String etiquetaCaja;
  final String? prefijo;
  final IconData icono;
  final String Function(Usuario) leer;
  final Future<void> Function(Usuario perfil, String valor) guardar;
  final int maxLines;
  final TextInputType teclado;
  final bool requerido;
  final String mensajeExito;

  const CampoTextoPerfilPantalla({
    super.key,
    required this.repositorio,
    required this.titulo,
    required this.etiquetaCaja,
    required this.icono,
    required this.leer,
    required this.guardar,
    this.prefijo,
    this.maxLines = 1,
    this.teclado = TextInputType.text,
    this.requerido = true,
    this.mensajeExito = 'Guardado correctamente.',
  });

  @override
  State<CampoTextoPerfilPantalla> createState() =>
      _CampoTextoPerfilPantallaState();
}

class _CampoTextoPerfilPantallaState extends State<CampoTextoPerfilPantalla> {
  final _controlador = TextEditingController();
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
    _controlador.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() {
      if (perfil != null) _controlador.text = widget.leer(perfil);
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final perfil = await widget.repositorio.obtenerPerfilPropio();
      if (!mounted) return;
      if (perfil == null) {
        NotificacionServicio.alerta(context, 'No se encontró tu perfil.');
        return;
      }
      await widget.guardar(perfil, _controlador.text.trim());
      if (!mounted) return;
      NotificacionServicio.exito(context, widget.mensajeExito);
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
    final label = widget.prefijo == null
        ? widget.etiquetaCaja
        : '${widget.etiquetaCaja} (${widget.prefijo})';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          widget.titulo,
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.black87),
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
                  Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _controlador,
                          maxLines: widget.maxLines,
                          keyboardType: widget.teclado,
                          style: const TextStyle(
                              color: Colors.black87, fontSize: 15),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[100],
                            labelText: label,
                            labelStyle: const TextStyle(
                                color: Colors.black45, fontSize: 14),
                            prefixIcon: Icon(
                              widget.icono,
                              color: primario.withValues(alpha: 0.7),
                              size: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: primario.withValues(alpha: 0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: primario.withValues(alpha: 0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: primario, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                          ),
                          validator: (v) {
                            if (!widget.requerido) return null;
                            if (v == null || v.trim().isEmpty) {
                              return 'Ingresa ${widget.etiquetaCaja.toLowerCase()}';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
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
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16),
                                  ),
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
      );
    },
  ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: _BotonGuardar(guardando: _guardando, onPressed: _guardar),
        ),
      ),
    );
  }
}

class SelectorPerfilPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;
  final String titulo;
  final String? guia;
  final IconData icono;
  final List<(String, String)> opciones;
  final String Function(Usuario) leer;
  final Future<void> Function(Usuario perfil, String valor) guardar;
  final String mensajeExito;

  const SelectorPerfilPantalla({
    super.key,
    required this.repositorio,
    required this.titulo,
    required this.icono,
    required this.opciones,
    required this.leer,
    required this.guardar,
    this.guia,
    this.mensajeExito = 'Guardado correctamente.',
  });

  @override
  State<SelectorPerfilPantalla> createState() => _SelectorPerfilPantallaState();
}

class _SelectorPerfilPantallaState extends State<SelectorPerfilPantalla> {
  String _seleccion = '';
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() {
      _seleccion = perfil == null ? '' : widget.leer(perfil);
      _cargando = false;
    });
  }

  bool get _seleccionNoListada =>
      _seleccion.isNotEmpty &&
      widget.opciones.every((o) => o.$2 != _seleccion);

  Future<void> _guardar() async {
    if (_seleccion.isEmpty) {
      NotificacionServicio.alerta(context, 'Selecciona una opción.');
      return;
    }
    setState(() => _guardando = true);
    try {
      final perfil = await widget.repositorio.obtenerPerfilPropio();
      if (!mounted) return;
      if (perfil == null) {
        NotificacionServicio.alerta(context, 'No se encontró tu perfil.');
        return;
      }
      await widget.guardar(perfil, _seleccion);
      if (!mounted) return;
      NotificacionServicio.exito(context, widget.mensajeExito);
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
        title: Text(
          widget.titulo,
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.black87),
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
                  if (widget.guia != null) ...[
                    Text(
                      widget.guia!,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                  ],
                  DropdownButtonFormField<String>(
                    initialValue: _seleccion.isEmpty ? null : _seleccion,
                    isExpanded: true,
                    items: [
                      for (final opcion in widget.opciones)
                        DropdownMenuItem(
                          value: opcion.$2,
                          child: Text(
                            opcion.$1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14.5, color: Colors.black87),
                          ),
                        ),
                      if (_seleccionNoListada)
                        DropdownMenuItem(
                          value: _seleccion,
                          child: Text(
                            _seleccion,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14.5, color: Colors.black87),
                          ),
                        ),
                    ],
                    onChanged: _guardando
                        ? null
                        : (v) => setState(() => _seleccion = v ?? ''),
                    style: const TextStyle(
                        color: Colors.black87, fontSize: 15),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[100],
                      hintText: 'Selecciona una opción',
                      hintStyle: const TextStyle(
                          color: Colors.black45, fontSize: 15),
                      prefixIcon: Icon(
                        widget.icono,
                        color: primario.withValues(alpha: 0.7),
                        size: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: primario.withValues(alpha: 0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: primario.withValues(alpha: 0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: primario, width: 1.5),
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
          child: _BotonGuardar(guardando: _guardando, onPressed: _guardar),
        ),
      ),
    );
  }
}

class OrientacionSexualPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;

  const OrientacionSexualPantalla({super.key, required this.repositorio});

  @override
  State<OrientacionSexualPantalla> createState() =>
      _OrientacionSexualPantallaState();
}

class _OrientacionSexualPantallaState extends State<OrientacionSexualPantalla> {
  static const _opciones = [
    'Heterosexual',
    'Gay',
    'Lesbiana',
    'Bisexual',
    'Pansexual',
    'Asexual',
    'Queer',
    'Prefiero no decirlo',
  ];
  static const _valoresLegacy = {
    'homosexual': 'Gay',
    'otro': 'Otro',
    'no_comparto': 'Prefiero no decirlo',
  };

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

  Future<void> _cargar() async {
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() {
      final valor = perfil?.orientacionSexual ?? '';
      final etiqueta = _valoresLegacy[valor] ?? _capitalizar(valor);
      if (_opciones.contains(etiqueta)) {
        _seleccion = etiqueta;
      } else if (valor.isNotEmpty) {
        _personalizadaCtrl.text = valor;
      }
      _cargando = false;
    });
  }

  String _capitalizar(String v) {
    if (v.isEmpty) return '';
    return v[0].toUpperCase() + v.substring(1);
  }

  Future<void> _guardar() async {
    final texto = _personalizadaCtrl.text.trim();
    if (_seleccion.isEmpty && texto.isEmpty) {
      NotificacionServicio.alerta(
          context, 'Selecciona una opción o escribe la tuya.');
      return;
    }
    final valor =
        _seleccion.isNotEmpty ? _seleccion.toLowerCase() : texto;
    setState(() => _guardando = true);
    try {
      final perfil = await widget.repositorio.obtenerPerfilPropio();
      if (!mounted) return;
      if (perfil == null) {
        NotificacionServicio.alerta(context, 'No se encontró tu perfil.');
        return;
      }
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        orientacionSexual: Value(valor),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(
          context, 'Orientación sexual actualizada correctamente.');
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
                  const Text(
                    '¿Cuál es tu orientación sexual?',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Elige la que mejor te describa',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final anchoTarjeta = (constraints.maxWidth - 10) / 2;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final opcion in _opciones)
                            SizedBox(
                              width: anchoTarjeta,
                              child: _tarjetaOpcion(opcion, primario),
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
                      if (v.trim().isNotEmpty && _seleccion.isNotEmpty) {
                        setState(() => _seleccion = '');
                      }
                    },
                    style: const TextStyle(
                        color: Colors.black87, fontSize: 15),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[100],
                      labelText: '¿No encuentras la tuya? Escríbela aquí',
                      labelStyle: const TextStyle(
                          color: Colors.black45, fontSize: 13),
                      prefixIcon: Icon(Icons.edit_outlined,
                          color: primario.withValues(alpha: 0.7), size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: primario.withValues(alpha: 0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: primario.withValues(alpha: 0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primario, width: 1.5),
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
          child: _BotonGuardar(guardando: _guardando, onPressed: _guardar),
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

class SituacionSentimentalPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;

  const SituacionSentimentalPantalla({super.key, required this.repositorio});

  @override
  State<SituacionSentimentalPantalla> createState() =>
      _SituacionSentimentalPantallaState();
}

class _SituacionSentimentalPantallaState
    extends State<SituacionSentimentalPantalla> {
  static const _opciones = <(String, String)>[
    ('\ud83d\udc9a Soltero/a', 'soltero'),
    ('\ud83d\udc94 Separado/a', 'separado'),
    ('\ud83d\udd4a\ufe0f En una relaci\u00f3n abierta', 'en_relacion_abierta'),
    ('\ud83c\udf39 Viudo/a', 'viudo'),
    ('\ud83c\udf00 Es complicado', 'complicado'),
    ('\ud83e\udd10 Prefiero no decirlo', 'prefiero_no_decirlo'),
  ];

  String _seleccion = '';
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() {
      final valor = perfil?.situacionSentimental ?? '';
      final coincidencias = _opciones.where((o) => o.$2 == valor);
      _seleccion = coincidencias.isNotEmpty ? coincidencias.single.$1 : '';
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    if (_seleccion.isEmpty) {
      NotificacionServicio.alerta(context, 'Selecciona una opción.');
      return;
    }
    final coincidencias = _opciones.where((o) => o.$1 == _seleccion);
    final valor =
        coincidencias.isNotEmpty ? coincidencias.single.$2 : _seleccion;
    setState(() => _guardando = true);
    try {
      final perfil = await widget.repositorio.obtenerPerfilPropio();
      if (!mounted) return;
      if (perfil == null) {
        NotificacionServicio.alerta(context, 'No se encontró tu perfil.');
        return;
      }
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        situacionSentimental: Value(valor),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(context, 'Relación actualizada correctamente.');
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
                  const Text(
                    'Cu\u00e9ntanos sobre tu vida sentimental ahora mismo',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Esto ayuda a que te conectemos con personas compatibles.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  Column(
                    children: [
                      for (final opcion in _opciones)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _tarjetaOpcion(opcion, primario),
                        ),
                    ],
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
          child: _BotonGuardar(guardando: _guardando, onPressed: _guardar),
        ),
      ),
    );
  }

  Widget _tarjetaOpcion((String, String) opcion, Color primario) {
    final seleccionada = _seleccion == opcion.$1;
    return InkWell(
      onTap: _guardando
          ? null
          : () {
              setState(() {
                _seleccion = seleccionada ? '' : opcion.$1;
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
                opcion.$1,
                style: TextStyle(
                  fontSize: 14,
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

class NivelEducativoPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;

  const NivelEducativoPantalla({super.key, required this.repositorio});

  @override
  State<NivelEducativoPantalla> createState() => _NivelEducativoPantallaState();
}

class _NivelEducativoPantallaState extends State<NivelEducativoPantalla> {
  static const _opciones = <(String, String)>[
    ('Educaci\u00f3n Primaria', 'primaria'),
    ('Educaci\u00f3n Secundaria', 'secundaria'),
    ('Educaci\u00f3n Preuniversitaria', 'preuniversitaria'),
    ('Ense\u00f1anza T\u00e9cnica y Profesional', 'tecnica_profesional'),
    ('Educaci\u00f3n Superior', 'superior'),
    ('Postgrado', 'postgrado'),
    ('\ud83d\ude48 Prefiero no decirlo', 'prefiero_no_decirlo'),
  ];

  String _seleccion = '';
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() {
      final valor = perfil?.educacion ?? '';
      final coincidencias = _opciones.where((o) => o.$2 == valor);
      _seleccion = coincidencias.isNotEmpty ? coincidencias.single.$1 : '';
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    if (_seleccion.isEmpty) {
      NotificacionServicio.alerta(context, 'Selecciona una opci\u00f3n.');
      return;
    }
    final coincidencias = _opciones.where((o) => o.$1 == _seleccion);
    final valor =
        coincidencias.isNotEmpty ? coincidencias.single.$2 : _seleccion;
    setState(() => _guardando = true);
    try {
      final perfil = await widget.repositorio.obtenerPerfilPropio();
      if (!mounted) return;
      if (perfil == null) {
        NotificacionServicio.alerta(context, 'No se encontr\u00f3 tu perfil.');
        return;
      }
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        educacion: Value(valor),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(
          context, 'Nivel educativo actualizado correctamente.');
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
                  const Text(
                    '\u00bfCu\u00e1l es tu nivel de estudios?',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Esto ayuda a conectar con personas con intereses afines.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  Column(
                    children: [
                      for (final opcion in _opciones)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _tarjetaOpcion(opcion, primario),
                        ),
                    ],
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
          child: _BotonGuardar(guardando: _guardando, onPressed: _guardar),
        ),
      ),
    );
  }

  Widget _tarjetaOpcion((String, String) opcion, Color primario) {
    final seleccionada = _seleccion == opcion.$1;
    return InkWell(
      onTap: _guardando
          ? null
          : () {
              setState(() {
                _seleccion = seleccionada ? '' : opcion.$1;
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
                opcion.$1,
                style: TextStyle(
                  fontSize: 14,
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

class TrabajoPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;

  const TrabajoPantalla({super.key, required this.repositorio});

  @override
  State<TrabajoPantalla> createState() => _TrabajoPantallaState();
}

class _TrabajoPantallaState extends State<TrabajoPantalla> {
  static const _opciones = <(String, String)>[
    ('Sector privado', 'sector_privado'),
    ('Sector p\u00fablico', 'sector_publico'),
    ('Trabajo independiente', 'independiente'),
    ('Emprendedor', 'emprendedor'),
    ('Ama de casa', 'ama_de_casa'),
    ('Estudiante', 'estudiante'),
    ('Jubilado', 'jubilado'),
    ('Buscando trabajo', 'buscando_trabajo'),
    ('\ud83d\ude48 Prefiero no decirlo', 'prefiero_no_decirlo'),
  ];

  String _seleccion = '';
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() {
      final valor = perfil?.trabajo ?? '';
      final coincidencias = _opciones.where((o) => o.$2 == valor);
      _seleccion = coincidencias.isNotEmpty ? coincidencias.single.$1 : '';
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    if (_seleccion.isEmpty) {
      NotificacionServicio.alerta(context, 'Selecciona una opci\u00f3n.');
      return;
    }
    final coincidencias = _opciones.where((o) => o.$1 == _seleccion);
    final valor =
        coincidencias.isNotEmpty ? coincidencias.single.$2 : _seleccion;
    setState(() => _guardando = true);
    try {
      final perfil = await widget.repositorio.obtenerPerfilPropio();
      if (!mounted) return;
      if (perfil == null) {
        NotificacionServicio.alerta(context, 'No se encontr\u00f3 tu perfil.');
        return;
      }
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        trabajo: Value(valor),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(
          context, 'Trabajo actualizado correctamente.');
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
                  const Text(
                    '\u00bfEn qu\u00e9 sector trabajas?',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ayuda a conocer un poco m\u00e1s sobre tu d\u00eda a d\u00eda.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  _tarjetaOpcionLarga(_opciones[1], primario),
                  const SizedBox(height: 10),
                  _tarjetaOpcionLarga(_opciones[0], primario),
                  const SizedBox(height: 10),
                  _tarjetaOpcionLarga(_opciones[2], primario),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _tarjetaOpcionLarga(_opciones[3], primario),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _tarjetaOpcionLarga(_opciones[4], primario),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _tarjetaOpcionLarga(_opciones[5], primario),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _tarjetaOpcionLarga(_opciones[6], primario),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _tarjetaOpcionLarga(_opciones[7], primario),
                  const SizedBox(height: 10),
                  _tarjetaOpcionLarga(_opciones[8], primario),
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
          child: _BotonGuardar(guardando: _guardando, onPressed: _guardar),
        ),
      ),
    );
  }

  Widget _tarjetaOpcionLarga((String, String) opcion, Color primario) {
    final seleccionada = _seleccion == opcion.$1;
    return InkWell(
      onTap: _guardando
          ? null
          : () {
              setState(() {
                _seleccion = seleccionada ? '' : opcion.$1;
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
                opcion.$1,
                style: TextStyle(
                  fontSize: 14,
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

class HijosPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;

  const HijosPantalla({super.key, required this.repositorio});

  @override
  State<HijosPantalla> createState() => _HijosPantallaState();
}

class _HijosPantallaState extends State<HijosPantalla> {
  static const _opciones = <(String, String)>[
    ('\u274c No quiero tener hijos', 'no_quiero'),
    ('\ud83e\udd30 Me gustar\u00eda tener hijos', 'quiero'),
    ('\ud83d\udc68\u200d\ud83d\udc66 Ya tengo hijos y no quiero m\u00e1s',
        'tengo_no_mas'),
    ('\ud83d\udc68\u200d\ud83d\udc67\u200d\ud83d\udc66 Ya tengo hijos y me gustar\u00eda tener m\u00e1s',
        'tengo_mas'),
    ('\ud83e\uddd1\u200d\ud83e\uddb3 Ya tengo hijos y son adultos',
        'tengo_adultos'),
    ('\ud83e\udd14 No estoy seguro/a de querer hijos', 'no_se'),
    ('\ud83d\ude48 Prefiero no decirlo', 'prefiero_no_decirlo'),
  ];

  String _seleccion = '';
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() {
      final valor = perfil?.hijos ?? '';
      final coincidencias = _opciones.where((o) => o.$2 == valor);
      _seleccion = coincidencias.isNotEmpty ? coincidencias.single.$1 : '';
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    if (_seleccion.isEmpty) {
      NotificacionServicio.alerta(context, 'Selecciona una opci\u00f3n.');
      return;
    }
    final coincidencias = _opciones.where((o) => o.$1 == _seleccion);
    final valor =
        coincidencias.isNotEmpty ? coincidencias.single.$2 : _seleccion;
    setState(() => _guardando = true);
    try {
      final perfil = await widget.repositorio.obtenerPerfilPropio();
      if (!mounted) return;
      if (perfil == null) {
        NotificacionServicio.alerta(context, 'No se encontr\u00f3 tu perfil.');
        return;
      }
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        hijos: Value(valor),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(
          context, 'Preferencia de hijos actualizada correctamente.');
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
                  const Text(
                    '\u00bfTienes hijos?',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Es importante para conectar con personas compatibles.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  Column(
                    children: [
                      for (final opcion in _opciones)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _tarjetaOpcion(opcion, primario),
                        ),
                    ],
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
          child: _BotonGuardar(guardando: _guardando, onPressed: _guardar),
        ),
      ),
    );
  }

  Widget _tarjetaOpcion((String, String) opcion, Color primario) {
    final seleccionada = _seleccion == opcion.$1;
    return InkWell(
      onTap: _guardando
          ? null
          : () {
              setState(() {
                _seleccion = seleccionada ? '' : opcion.$1;
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
                opcion.$1,
                style: TextStyle(
                  fontSize: 14,
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

class TabacoPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;

  const TabacoPantalla({super.key, required this.repositorio});

  @override
  State<TabacoPantalla> createState() => _TabacoPantallaState();
}

class _TabacoPantallaState extends State<TabacoPantalla> {
  static const _opciones = <(String, String)>[
    ('\ud83d\udead No fumo', 'no_fumo'),
    ('\ud83d\udeac Fumo socialmente', 'fumo_social'),
    ('\ud83d\udeac Fumo a diario', 'fumo_diario'),
    ('\ud83d\udead Dej\u00e9 de fumar', 'deje_de_fumar'),
    ('\ud83d\udead Estoy dejando de fumar', 'dejando_de_fumar'),
    ('\ud83d\ude48 Prefiero no decirlo', 'prefiero_no_decirlo'),
  ];

  String _seleccion = '';
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() {
      final valor = perfil?.fuma ?? '';
      final coincidencias = _opciones.where((o) => o.$2 == valor);
      _seleccion = coincidencias.isNotEmpty ? coincidencias.single.$1 : '';
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    if (_seleccion.isEmpty) {
      NotificacionServicio.alerta(context, 'Selecciona una opci\u00f3n.');
      return;
    }
    final coincidencias = _opciones.where((o) => o.$1 == _seleccion);
    final valor =
        coincidencias.isNotEmpty ? coincidencias.single.$2 : _seleccion;
    setState(() => _guardando = true);
    try {
      final perfil = await widget.repositorio.obtenerPerfilPropio();
      if (!mounted) return;
      if (perfil == null) {
        NotificacionServicio.alerta(context, 'No se encontr\u00f3 tu perfil.');
        return;
      }
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        fuma: Value(valor),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(
          context, 'Preferencia actualizada correctamente.');
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
                  const Text(
                    '\u00bfFumas?',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ayuda a conectar con personas con h\u00e1bitos similares.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  Column(
                    children: [
                      for (final opcion in _opciones)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _tarjetaOpcion(opcion, primario),
                        ),
                    ],
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
          child: _BotonGuardar(guardando: _guardando, onPressed: _guardar),
        ),
      ),
    );
  }

  Widget _tarjetaOpcion((String, String) opcion, Color primario) {
    final seleccionada = _seleccion == opcion.$1;
    return InkWell(
      onTap: _guardando
          ? null
          : () {
              setState(() {
                _seleccion = seleccionada ? '' : opcion.$1;
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
                opcion.$1,
                style: TextStyle(
                  fontSize: 14,
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

class AlcoholPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;

  const AlcoholPantalla({super.key, required this.repositorio});

  @override
  State<AlcoholPantalla> createState() => _AlcoholPantallaState();
}

class _AlcoholPantallaState extends State<AlcoholPantalla> {
  static const _opciones = <(String, String)>[
    ('\ud83d\udeab\ud83c\udf77 No bebo', 'no_bebo'),
    ('\ud83c\udf77 Bebo socialmente', 'bebo_social'),
    ('\ud83c\udf7a Bebo con moderaci\u00f3n', 'bebo_moderacion'),
    ('\ud83d\ude48 Prefiero no decirlo', 'prefiero_no_decirlo'),
  ];

  String _seleccion = '';
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() {
      final valor = perfil?.bebe ?? '';
      final coincidencias = _opciones.where((o) => o.$2 == valor);
      _seleccion = coincidencias.isNotEmpty ? coincidencias.single.$1 : '';
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    if (_seleccion.isEmpty) {
      NotificacionServicio.alerta(context, 'Selecciona una opci\u00f3n.');
      return;
    }
    final coincidencias = _opciones.where((o) => o.$1 == _seleccion);
    final valor =
        coincidencias.isNotEmpty ? coincidencias.single.$2 : _seleccion;
    setState(() => _guardando = true);
    try {
      final perfil = await widget.repositorio.obtenerPerfilPropio();
      if (!mounted) return;
      if (perfil == null) {
        NotificacionServicio.alerta(context, 'No se encontr\u00f3 tu perfil.');
        return;
      }
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        bebe: Value(valor),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(
          context, 'Preferencia actualizada correctamente.');
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
                  const Text(
                    '\u00bfBebes alcohol?',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ayuda a conectar con personas con h\u00e1bitos similares.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  Column(
                    children: [
                      for (final opcion in _opciones)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _tarjetaOpcion(opcion, primario),
                        ),
                    ],
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
          child: _BotonGuardar(guardando: _guardando, onPressed: _guardar),
        ),
      ),
    );
  }

  Widget _tarjetaOpcion((String, String) opcion, Color primario) {
    final seleccionada = _seleccion == opcion.$1;
    return InkWell(
      onTap: _guardando
          ? null
          : () {
              setState(() {
                _seleccion = seleccionada ? '' : opcion.$1;
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
                opcion.$1,
                style: TextStyle(
                  fontSize: 14,
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

class MascotasPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;

  const MascotasPantalla({super.key, required this.repositorio});

  @override
  State<MascotasPantalla> createState() => _MascotasPantallaState();
}

class _MascotasPantallaState extends State<MascotasPantalla> {
  static const _opciones = <(String, String)>[
    ('\ud83d\udc15 Tengo perro(s)', 'perro'),
    ('\ud83d\udc08 Tengo gato(s)', 'gato'),
    ('\ud83d\udc15\ud83d\udc08 Tengo perros y gatos', 'perros_gatos'),
    ('\u2764\ufe0f No tengo mascotas pero me encantan', 'no_tengo_encantan'),
    ('\ud83d\udeab No tengo mascotas y no quiero', 'no_tengo_no_quiero'),
    ('\ud83d\ude48 Prefiero no decirlo', 'prefiero_no_decirlo'),
  ];
  static const _valoresLegacy = {
    'ave': 'Otras mascotas',
    'otro': 'Otras mascotas',
    'ninguna': 'no_tengo_no_quiero',
  };

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

  Future<void> _cargar() async {
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() {
      final valor = perfil?.mascotas ?? '';
      final coincidencias = _opciones.where((o) => o.$2 == valor);
      if (coincidencias.isNotEmpty) {
        _seleccion = coincidencias.single.$1;
      } else if (valor.isNotEmpty) {
        _personalizadaCtrl.text = _valoresLegacy[valor] ?? valor;
      }
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    final texto = _personalizadaCtrl.text.trim();
    if (_seleccion.isEmpty && texto.isEmpty) {
      NotificacionServicio.alerta(
          context, 'Selecciona una opci\u00f3n o escribe la tuya.');
      return;
    }
    final coincidencias = _opciones.where((o) => o.$1 == _seleccion);
    final valor =
        coincidencias.isNotEmpty ? coincidencias.single.$2 : texto;
    setState(() => _guardando = true);
    try {
      final perfil = await widget.repositorio.obtenerPerfilPropio();
      if (!mounted) return;
      if (perfil == null) {
        NotificacionServicio.alerta(context, 'No se encontr\u00f3 tu perfil.');
        return;
      }
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        mascotas: Value(valor),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(
          context, 'Mascotas actualizadas correctamente.');
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
                  const Text(
                    '\u00bfTienes mascotas?',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Compartir el amor por los animales siempre suma.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  Column(
                    children: [
                      for (final opcion in _opciones)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _tarjetaOpcion(opcion, primario),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _personalizadaCtrl,
                    enabled: !_guardando,
                    onChanged: (v) {
                      if (v.trim().isNotEmpty && _seleccion.isNotEmpty) {
                        setState(() => _seleccion = '');
                      }
                    },
                    style: const TextStyle(
                        color: Colors.black87, fontSize: 15),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[100],
                      labelText: '\u00bfNo encuentras la tuya? Escr\u00edbela aqu\u00ed',
                      labelStyle: const TextStyle(
                          color: Colors.black45, fontSize: 13),
                      prefixIcon: Icon(Icons.edit_outlined,
                          color: primario.withValues(alpha: 0.7), size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: primario.withValues(alpha: 0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: primario.withValues(alpha: 0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primario, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
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
          child: _BotonGuardar(guardando: _guardando, onPressed: _guardar),
        ),
      ),
    );
  }

  Widget _tarjetaOpcion((String, String) opcion, Color primario) {
    final seleccionada = _seleccion == opcion.$1;
    return InkWell(
      onTap: _guardando
          ? null
          : () {
              setState(() {
                if (_seleccion == opcion.$1) {
                  _seleccion = '';
                } else {
                  _seleccion = opcion.$1;
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
                opcion.$1,
                style: TextStyle(
                  fontSize: 14,
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

class ReligionPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;

  const ReligionPantalla({super.key, required this.repositorio});

  @override
  State<ReligionPantalla> createState() => _ReligionPantallaState();
}

class _ReligionPantallaState extends State<ReligionPantalla> {
  static const _opciones = <(String, String)>[
    ('\u26ea Cat\u00f3lica', 'catolica'),
    ('\u271d\ufe0f Cristiana', 'cristiana'),
    ('\u2721\ufe0f Jud\u00eda', 'judia'),
    ('\u262a\ufe0f Musulmana', 'musulmana'),
    ('\u2638\ufe0f Budista', 'budista'),
    ('\ud83d\udd49\ufe0f Hind\u00fa', 'hindu'),
    ('\ud83c\udf3f Espiritual pero no religioso/a', 'espiritual'),
    ('\ud83e\udd14 Agn\u00f3stico/a', 'agnostico'),
    ('\ud83d\udeab\u271d\ufe0f Ateo/a', 'ateo'),
    ('\ud83d\ude48 Prefiero no decirlo', 'prefiero_no_decirlo'),
  ];
  static const _valoresLegacy = {
    'otra': 'Otra',
  };

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

  Future<void> _cargar() async {
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() {
      final valor = perfil?.religion ?? '';
      final legado = _valoresLegacy[valor] ?? valor;
      final coincidencias = _opciones.where((o) => o.$2 == legado);
      if (coincidencias.isNotEmpty) {
        _seleccion = coincidencias.single.$1;
      } else if (legado.isNotEmpty) {
        _personalizadaCtrl.text = legado;
      }
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    final texto = _personalizadaCtrl.text.trim();
    if (_seleccion.isEmpty && texto.isEmpty) {
      NotificacionServicio.alerta(
          context, 'Selecciona una opci\u00f3n o escribe la tuya.');
      return;
    }
    final coincidencias = _opciones.where((o) => o.$1 == _seleccion);
    final valor =
        coincidencias.isNotEmpty ? coincidencias.single.$2 : texto;
    setState(() => _guardando = true);
    try {
      final perfil = await widget.repositorio.obtenerPerfilPropio();
      if (!mounted) return;
      if (perfil == null) {
        NotificacionServicio.alerta(context, 'No se encontr\u00f3 tu perfil.');
        return;
      }
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        religion: Value(valor),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(
          context, 'Religi\u00f3n actualizada correctamente.');
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
                  const Text(
                    '\u00bfCu\u00e1l es tu religi\u00f3n o creencia?',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Compartir tus valores ayuda a conectar con personas afines.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  Column(
                    children: [
                      for (final indice in [0, 2, 4, 7])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 5),
                                  child: _tarjetaOpcion(
                                      _opciones[indice], primario),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 5),
                                  child: _tarjetaOpcion(
                                      _opciones[indice + 1], primario),
                                ),
                              ),
                            ],
                          ),
                        ),
                      for (final indice in [6, 9])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _tarjetaOpcion(_opciones[indice], primario),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _personalizadaCtrl,
                    enabled: !_guardando,
                    onChanged: (v) {
                      if (v.trim().isNotEmpty && _seleccion.isNotEmpty) {
                        setState(() => _seleccion = '');
                      }
                    },
                    style: const TextStyle(
                        color: Colors.black87, fontSize: 15),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[100],
                      labelText: '\u00bfNo encuentras la tuya? Escr\u00edbela aqu\u00ed',
                      labelStyle: const TextStyle(
                          color: Colors.black45, fontSize: 13),
                      prefixIcon: Icon(Icons.edit_outlined,
                          color: primario.withValues(alpha: 0.7), size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: primario.withValues(alpha: 0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: primario.withValues(alpha: 0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primario, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
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
          child: _BotonGuardar(guardando: _guardando, onPressed: _guardar),
        ),
      ),
    );
  }

  Widget _tarjetaOpcion((String, String) opcion, Color primario) {
    final seleccionada = _seleccion == opcion.$1;
    return InkWell(
      onTap: _guardando
          ? null
          : () {
              setState(() {
                if (seleccionada) {
                  _seleccion = '';
                } else {
                  _seleccion = opcion.$1;
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
                opcion.$1,
                style: TextStyle(
                  fontSize: 14,
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

class TatuajesPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;

  const TatuajesPantalla({super.key, required this.repositorio});

  @override
  State<TatuajesPantalla> createState() => _TatuajesPantallaState();
}

class _TatuajesPantallaState extends State<TatuajesPantalla> {
  static const _opciones = <(String, String)>[
    ('No tengo tatuajes', 'no_tengo'),
    ('Tengo alg\u00fan tatuaje', 'tengo_alguno'),
    ('Tengo varios tatuajes', 'tengo_varios'),
    ('Me encantar\u00eda hacerme un tatuaje', 'me_gustaria'),
    ('Prefiero no decirlo', 'prefiero_no_decirlo'),
  ];

  String _seleccion = '';
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() {
      final valor = perfil?.tatuajes ?? '';
      final coincidencias = _opciones.where((o) => o.$2 == valor);
      _seleccion = coincidencias.isNotEmpty ? coincidencias.single.$1 : '';
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    if (_seleccion.isEmpty) {
      NotificacionServicio.alerta(context, 'Selecciona una opci\u00f3n.');
      return;
    }
    final coincidencias = _opciones.where((o) => o.$1 == _seleccion);
    final valor =
        coincidencias.isNotEmpty ? coincidencias.single.$2 : _seleccion;
    setState(() => _guardando = true);
    try {
      final perfil = await widget.repositorio.obtenerPerfilPropio();
      if (!mounted) return;
      if (perfil == null) {
        NotificacionServicio.alerta(context, 'No se encontr\u00f3 tu perfil.');
        return;
      }
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        tatuajes: Value(valor),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(
          context, 'Tatuajes actualizados correctamente.');
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
                  const Text(
                    '\u00bfTienes tatuajes?',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'El arte en la piel dice mucho sobre ti.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  Column(
                    children: [
                      for (final opcion in _opciones)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _tarjetaOpcion(opcion, primario),
                        ),
                    ],
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
          child: _BotonGuardar(guardando: _guardando, onPressed: _guardar),
        ),
      ),
    );
  }

  Widget _tarjetaOpcion((String, String) opcion, Color primario) {
    final seleccionada = _seleccion == opcion.$1;
    return InkWell(
      onTap: _guardando
          ? null
          : () {
              setState(() {
                _seleccion = seleccionada ? '' : opcion.$1;
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
                opcion.$1,
                style: TextStyle(
                  fontSize: 14,
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

class EstaturaPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;

  const EstaturaPantalla({super.key, required this.repositorio});

  @override
  State<EstaturaPantalla> createState() => _EstaturaPantallaState();
}

class _EstaturaPantallaState extends State<EstaturaPantalla> {
  double _alturaCm = 175;
  bool _unidadCm = true;
  bool _selecciono = false;
  bool _prefieroNoDecir = false;
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  double? _convertir(String valor) {
    final s = valor.trim();
    if (s.isEmpty) return null;
    final cadenaPies = RegExp(r"(\d+)\s*'\s*(\d+)");
    final m = cadenaPies.firstMatch(s);
    if (m != null) {
      return (int.parse(m.group(1)!) * 12 + int.parse(m.group(2)!)) * 2.54;
    }
    final num = double.tryParse(s.replaceAll(',', '.'));
    if (num == null) return null;
    if (num < 5) return num * 100;
    return num;
  }

  Future<void> _cargar() async {
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() {
      final valor = perfil?.altura ?? '';
      _prefieroNoDecir = valor.trim().toLowerCase() == 'prefiero no decirlo';
      final cm = _convertir(valor);
      if (!_prefieroNoDecir && cm != null) {
        _selecciono = true;
        _alturaCm = cm.clamp(140.0, 220.0);
      }
      _unidadCm = !valor.contains("'") && !valor.toLowerCase().contains('ft');
      _cargando = false;
    });
  }

  String _formatoAltura() {
    if (_unidadCm) return '${_alturaCm.round()} cm';
    final pulgadas = _alturaCm / 2.54;
    final pies = pulgadas ~/ 12;
    var restantes = pulgadas.remainder(12).round();
    var f = pies;
    if (restantes == 12) {
      f += 1;
      restantes = 0;
    }
    return '$f\u2019$restantes\u201d';
  }

  Future<void> _guardar() async {
    if (!_prefieroNoDecir && !_selecciono) {
      NotificacionServicio.alerta(
          context, 'Selecciona tu estatura o elige \u00abPrefiero no decirlo\u00bb.');
      return;
    }
    setState(() => _guardando = true);
    try {
      final perfil = await widget.repositorio.obtenerPerfilPropio();
      if (!mounted) return;
      if (perfil == null) {
        NotificacionServicio.alerta(
            context, 'No se encontr\u00f3 tu perfil.');
        return;
      }
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        altura: Value(
            _prefieroNoDecir ? 'Prefiero no decirlo' : '${_alturaCm.round()}'),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(
          context, 'Estatura actualizada correctamente.');
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
                              const Text(
                                '\u00bfCu\u00e1l es tu estatura?',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Un detalle m\u00e1s para que te conozcan mejor.',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: primario.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border:
                                      Border.all(color: primario
                                          .withValues(alpha: 0.3)),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: primario.withValues(
                                            alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          _botonUnidad(primario, true),
                                          _botonUnidad(primario, false),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    if (_prefieroNoDecir)
                                      Text(
                                        '\ud83d\ude48 Prefiero no decirlo',
                                        style: TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[600]),
                                      )
                                    else if (_selecciono)
                                      Text(
                                        _formatoAltura(),
                                        style: TextStyle(
                                            fontSize: 44,
                                            fontWeight: FontWeight.bold,
                                            color: primario),
                                      )
                                    else
                                      Text(
                                        'Elige tu estatura',
                                        style: TextStyle(
                                            fontSize: 22,
                                            color: Colors.grey[500]),
                                      ),
                                    const SizedBox(height: 4),
                                    Slider(
                                      value: _alturaCm,
                                      min: 140,
                                      max: 220,
                                      divisions: 80,
                                      activeColor: primario,
                                      inactiveColor:
                                          primario.withValues(alpha: 0.2),
                                      label: _formatoAltura(),
                                      onChanged: _guardando || _prefieroNoDecir
                                          ? null
                                          : (v) => setState(() {
                                                _alturaCm = v;
                                                _selecciono = true;
                                              }),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              '140 cm / 4\u00277\u201d',
                                              style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12),
                                            ),
                                          ),
                                          Flexible(
                                            child: Text(
                                              '220 cm / 7\u00273\u201d',
                                              style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12),
                                              textAlign: TextAlign.end,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              _tarjetaPrefieroNoDecir(primario),
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
          child: _BotonGuardar(guardando: _guardando, onPressed: _guardar),
        ),
      ),
    );
  }

  Widget _tarjetaPrefieroNoDecir(Color primario) {
  final seleccionada = _prefieroNoDecir;
  return InkWell(
    onTap: _guardando
        ? null
        : () => setState(() {
              _prefieroNoDecir = !_prefieroNoDecir;
              if (_prefieroNoDecir) {
                _selecciono = false;
              }
            }),
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
              '\ud83d\ude48 Prefiero no decirlo',
              style: TextStyle(
                fontSize: 14,
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

Widget _botonUnidad(Color primario, bool esCm) {
    final seleccionada = _unidadCm == esCm;
    return Expanded(
      child: GestureDetector(
        onTap: _guardando
            ? null
            : () => setState(() => _unidadCm = esCm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: seleccionada ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: seleccionada
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              esCm ? 'cm' : 'ft',
              style: TextStyle(
                fontSize: 15,
                fontWeight:
                    seleccionada ? FontWeight.w700 : FontWeight.w500,
                color: seleccionada ? primario : Colors.grey[600],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SignoZodiacalPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;

  const SignoZodiacalPantalla({super.key, required this.repositorio});

  @override
  State<SignoZodiacalPantalla> createState() => _SignoZodiacalPantallaState();
}

class _SignoZodiacalPantallaState extends State<SignoZodiacalPantalla> {
  static const _signos = <(String, String, String)>[
    ('\u2648 Aries', '21 mar \u2014 19 abr', 'aries'),
    ('\u2649 Tauro', '20 abr \u2014 20 may', 'tauro'),
    ('\u264a G\u00e9minis', '21 may \u2014 20 jun', 'geminis'),
    ('\u264b C\u00e1ncer', '21 jun \u2014 22 jul', 'cancer'),
    ('\u264c Leo', '23 jul \u2014 22 ago', 'leo'),
    ('\u264d Virgo', '23 ago \u2014 22 sep', 'virgo'),
    ('\u264e Libra', '23 sep \u2014 22 oct', 'libra'),
    ('\u264f Escorpio', '23 oct \u2014 21 nov', 'escorpio'),
    ('\u2650 Sagitario', '22 nov \u2014 21 dic', 'sagitario'),
    ('\u2651 Capricornio', '22 dic \u2014 19 ene', 'capricornio'),
    ('\u2652 Acuario', '20 ene \u2014 18 feb', 'acuario'),
    ('\u2653 Piscis', '19 feb \u2014 20 mar', 'piscis'),
  ];

  bool _prefieroNoDecir = false;
  String? _signoGuardado;
  DateTime? _fechaNacimiento;
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  String _signoSugerido(DateTime f) {
    final m = f.month;
    final d = f.day;
    if ((m == 3 && d >= 21) || (m == 4 && d <= 19)) return 'aries';
    if ((m == 4 && d >= 20) || (m == 5 && d <= 20)) return 'tauro';
    if ((m == 5 && d >= 21) || (m == 6 && d <= 20)) return 'geminis';
    if ((m == 6 && d >= 21) || (m == 7 && d <= 22)) return 'cancer';
    if ((m == 7 && d >= 23) || (m == 8 && d <= 22)) return 'leo';
    if ((m == 8 && d >= 23) || (m == 9 && d <= 22)) return 'virgo';
    if ((m == 9 && d >= 23) || (m == 10 && d <= 22)) return 'libra';
    if ((m == 10 && d >= 23) || (m == 11 && d <= 21)) return 'escorpio';
    if ((m == 11 && d >= 22) || (m == 12 && d <= 21)) return 'sagitario';
    if ((m == 12 && d >= 22) || (m == 1 && d <= 19)) return 'capricornio';
    if ((m == 1 && d >= 20) || (m == 2 && d <= 18)) return 'acuario';
    return 'piscis';
  }

  (String, String, String)? _signoVisible() {
    final codigo = _signoGuardado ??
        (_fechaNacimiento != null ? _signoSugerido(_fechaNacimiento!) : null);
    if (codigo == null) return null;
    for (final s in _signos) {
      if (s.$3 == codigo) return s;
    }
    return null;
  }

  Future<void> _cargar() async {
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() {
      final valor = perfil?.signoZodiaco ?? '';
      _prefieroNoDecir = valor == 'prefiero_no_decirlo';
      if (!_prefieroNoDecir) {
        final esValido = _signos.any((s) => s.$3 == valor);
        _signoGuardado = esValido ? valor : null;
      }
      _fechaNacimiento = perfil?.fechaNacimiento;
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    String? valor;
    if (_prefieroNoDecir) {
      valor = 'prefiero_no_decirlo';
    } else {
      final signo = _signoVisible();
      if (signo == null) {
        NotificacionServicio.alerta(
            context,
            'No podemos calcular tu signo. A\u00f1ade tu fecha de nacimiento '
            'o elige \u00abPrefiero no decirlo\u00bb.');
        return;
      }
      valor = signo.$3;
    }
    setState(() => _guardando = true);
    try {
      final perfil = await widget.repositorio.obtenerPerfilPropio();
      if (!mounted) return;
      if (perfil == null) {
        NotificacionServicio.alerta(context, 'No se encontr\u00f3 tu perfil.');
        return;
      }
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        signoZodiaco: Value(valor),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(
          context, 'Signo del zod\u00edaco actualizado correctamente.');
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
    final signo = _signoVisible();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
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
                              const Text(
                                '\u00bfCu\u00e1l es tu signo del zod\u00edaco?',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Un dato divertido para conectar con personas afines.',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              if (signo != null) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: primario.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: primario
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        signo.$1,
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: primario,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        signo.$2,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (_fechaNacimiento != null)
                                  Text(
                                    'Calculado con tu fecha de nacimiento',
                                    style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12),
                                  ),
                                const SizedBox(height: 20),
                              ] else ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Para conocer tu signo necesitamos tu '
                                    'fecha de nacimiento.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14),
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                              _tarjetaPrefieroNoDecirSigno(primario),
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
          child: _BotonGuardar(guardando: _guardando, onPressed: _guardar),
        ),
      ),
    );
  }

  Widget _tarjetaPrefieroNoDecirSigno(Color primario) {
    final seleccionada = _prefieroNoDecir;
    return InkWell(
      onTap: _guardando
          ? null
          : () => setState(() {
                _prefieroNoDecir = !_prefieroNoDecir;
              }),
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
                '\ud83d\ude48 Prefiero no decirlo',
                style: TextStyle(
                  fontSize: 14,
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

class ProfesionPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;

  const ProfesionPantalla({super.key, required this.repositorio});

  @override
  State<ProfesionPantalla> createState() => _ProfesionPantallaState();
}

class _ProfesionPantallaState extends State<ProfesionPantalla> {
  static const _opciones = [
    // Salud
    'Médico/a',
    'Enfermero/a',
    'Psicólogo/a',
    'Fisioterapeuta',
    'Nutricionista',
    'Dentista',
    'Veterinario/a',
    'Farmacéutico/a',
    // Educación
    'Profesor/a',
    'Maestro/a',
    'Educador/a social',
    'Pedagogo/a',
    'Investigador/a',
    // Tecnología
    'Ingeniero/a informático/a',
    'Desarrollador/a',
    'Programador/a',
    'Diseñador/a UX/UI',
    'Analista de datos',
    'Científico/a de datos',
    'Product Manager',
    'Scrum Master',
    // Arte y diseño
    'Arquitecto/a',
    'Diseñador/a gráfico/a',
    'Diseñador/a de interiores',
    'Artista plástico/a',
    'Ilustrador/a',
    'Fotógrafo/a',
    'Músico/a',
    'Actor/Actriz',
    'Escritor/a',
    'Periodista',
    'Creador/a de contenido',
    // Empresa y finanzas
    'Abogado/a',
    'Economista',
    'Contador/a',
    'Asesor/a financiero/a',
    'Consultor/a',
    'Director/a ejecutivo/a',
    'Administrador/a de empresas',
    'Recursos humanos',
    'Comercial',
    'Marketing',
    // Ingeniería
    'Ingeniero/a civil',
    'Ingeniero/a industrial',
    'Ingeniero/a mecánico/a',
    'Ingeniero/a eléctrico/a',
    'Ingeniero/a químico/a',
    // Hostelería
    'Chef',
    'Cocinero/a',
    'Camarero/a',
    'Recepcionista',
    'Gestor/a de hoteles',
    'Guía turístico/a',
    'Azafato/a de vuelo',
    // Otros
    'Estudiante',
    'Ama de casa',
    'Cuidador/a',
    'Militar',
    'Policía',
    'Bombero/a',
    'Conductor/a',
    'Transportista',
  ];

  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() {
      _ctrl.text = perfil?.profesion ?? '';
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    final texto = _ctrl.text.trim();
    if (texto.isEmpty) {
      NotificacionServicio.alerta(context, 'Escribe tu profesi\u00f3n.');
      return;
    }
    setState(() => _guardando = true);
    try {
      final perfil = await widget.repositorio.obtenerPerfilPropio();
      if (!mounted) return;
      if (perfil == null) {
        NotificacionServicio.alerta(context, 'No se encontr\u00f3 tu perfil.');
        return;
      }
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        profesion: Value(texto),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(
          context, 'Profesi\u00f3n actualizada correctamente.');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      NotificacionServicio.alerta(context, e.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
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
                  const Text(
                    '\u00bfCu\u00e1l es tu profesi\u00f3n?',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Compartir tu profesi\u00f3n ayuda a conectar con personas afines.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue texto) {
                      if (texto.text.trim().isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      final consulta =
                          _normalizar(texto.text.trim().toLowerCase());
                      return _opciones.where((opcion) => _normalizar(
                          opcion.toLowerCase()).contains(consulta));
                    },
                    displayStringForOption: (opcion) => opcion,
                    fieldViewBuilder: (context, controladorTexto,
                        focusNodeTexto, onFieldSubmitted) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        if (controladorTexto.text.isEmpty &&
                            _ctrl.text.isNotEmpty) {
                          controladorTexto.text = _ctrl.text;
                        }
                      });
                      return TextField(
                        controller: controladorTexto,
                        focusNode: focusNodeTexto,
                        onChanged: (v) => _ctrl.text = v,
                        onSubmitted: (_) => onFieldSubmitted(),
                        enabled: !_guardando,
                        style: const TextStyle(
                            color: Colors.black87, fontSize: 15),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey[100],
                          labelText: 'Escribe tu profesi\u00f3n',
                          labelStyle: const TextStyle(
                              color: Colors.black45, fontSize: 14),
                          prefixIcon: Icon(Icons.badge_outlined,
                              color: primario.withValues(alpha: 0.7),
                              size: 20),
                          suffixIcon: Icon(Icons.arrow_drop_down,
                              color: Colors.grey[400]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: primario.withValues(alpha: 0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: primario.withValues(alpha: 0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: primario, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
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
                                    Icons.work_outline,
                                    size: 20,
                                    color: primario.withValues(alpha: 0.8),
                                  ),
                                  title: Text(opcion,
                                      style: const TextStyle(fontSize: 14)),
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
                      _ctrl.text = opcion;
                    },
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
          child: _BotonGuardar(guardando: _guardando, onPressed: _guardar),
        ),
      ),
    );
  }
}

class IdiomasPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;

  const IdiomasPantalla({super.key, required this.repositorio});

  @override
  State<IdiomasPantalla> createState() => _IdiomasPantallaState();
}

class _IdiomasPantallaState extends State<IdiomasPantalla> {
  static const _idiomasDisponibles = [
    'Español',
    'Inglés',
    'Francés',
    'Alemán',
    'Italiano',
    'Portugués',
    'Catalán',
    'Gallego',
    'Euskera',
    'Árabe',
    'Chino',
    'Japonés',
    'Coreano',
    'Ruso',
    'Hindi',
    'Neerlandés',
    'Griego',
    'Turco',
    'Sueco',
    'Noruego',
    'Danés',
    'Polaco',
    'Hebreo',
    'Filipino',
    'Vietnamita',
    'Tailandés',
    'Ucraniano',
    'Checo',
    'Rumano',
    'Húngaro',
    'Persa',
    'Suajili',
  ];

  final _textoCtrl = TextEditingController();
  final _focusNode = FocusNode();
  Set<String> _idiomas = {};
  String _consulta = '';
  bool _campoFocused = false;
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) {
        setState(() => _campoFocused = _focusNode.hasFocus);
      }
    });
    _cargar();
  }

  @override
  void dispose() {
    _textoCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() {
      final valor = perfil?.idiomas ?? '';
      _idiomas = valor
          .split(',')
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .toSet();
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final perfil = await widget.repositorio.obtenerPerfilPropio();
      if (!mounted) return;
      if (perfil == null) {
        NotificacionServicio.alerta(context, 'No se encontró tu perfil.');
        return;
      }
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        idiomas: Value(_idiomas.join(', ')),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(
          context, 'Idiomas actualizados correctamente.');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      NotificacionServicio.alerta(context, e.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  List<String> _sugerencias() {
    final consulta = _normalizar(_consulta.trim().toLowerCase());
    if (consulta.isEmpty) return const [];
    return _idiomasDisponibles
        .where((i) =>
            !_idiomas.contains(i) &&
            _normalizar(i.toLowerCase()).contains(consulta))
        .toList();
  }

  void _alCambiarTexto(String v) {
    setState(() {
      if (v.contains(',')) {
        for (final parte in v.split(',')) {
          final p = parte.trim();
          if (p.isNotEmpty) _idiomas.add(p);
        }
        _textoCtrl.clear();
        _consulta = '';
      } else {
        _consulta = v;
      }
    });
  }

  double _anchoCampo() {
    if (_textoCtrl.text.isEmpty) return 150;
    final estimado = _textoCtrl.text.length * 9.0 + 24;
    return estimado.clamp(150.0, 260.0).toDouble();
  }

  Widget _tagIdioma(String idioma, Color primario) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: primario.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            idioma,
            style: TextStyle(
                fontSize: 13, color: primario, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _guardando
                ? null
                : () => setState(() => _idiomas.remove(idioma)),
            child: Icon(Icons.close, size: 16, color: primario),
          ),
        ],
      ),
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
                  const Text(
                    '\u00bfQu\u00e9 idiomas hablas?',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Compartir idiomas ayuda a conectar con personas de todo el mundo.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _campoFocused
                            ? primario
                            : primario.withValues(alpha: 0.3),
                        width: _campoFocused ? 1.5 : 1,
                      ),
                    ),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final idioma in _idiomas)
                          _tagIdioma(idioma, primario),
                        SizedBox(
                          width: _anchoCampo(),
                          child: TextField(
                            controller: _textoCtrl,
                            focusNode: _focusNode,
                            enabled: !_guardando,
                            onChanged: _alCambiarTexto,
                            onSubmitted: (v) {
                              final p = v.trim();
                              if (p.isEmpty) return;
                              setState(() {
                                _idiomas.add(p);
                                _textoCtrl.clear();
                                _consulta = '';
                              });
                            },
                            style: const TextStyle(
                                color: Colors.black87, fontSize: 15),
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: 'Escribe un idioma...',
                              hintStyle: TextStyle(
                                  color: Colors.black38, fontSize: 14),
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_campoFocused && _consulta.trim().isNotEmpty &&
                      _sugerencias().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: _sugerencias().length,
                          itemBuilder: (context, index) {
                            final sugerencia = _sugerencias()[index];
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                Icons.language,
                                size: 20,
                                color: primario.withValues(alpha: 0.8),
                              ),
                              title: Text(sugerencia,
                                  style: const TextStyle(fontSize: 14)),
                              onTap: () {
                                setState(() {
                                  _idiomas.add(sugerencia);
                                  _textoCtrl.clear();
                                  _consulta = '';
                                });
                                _focusNode.requestFocus();
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
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
          child: _BotonGuardar(guardando: _guardando, onPressed: _guardar),
        ),
      ),
    );
  }
}

class QueBuscaPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;

  const QueBuscaPantalla({super.key, required this.repositorio});

  @override
  State<QueBuscaPantalla> createState() => _QueBuscaPantallaState();
}

class _QueBuscaPantallaState extends State<QueBuscaPantalla> {
  static const _opciones = <(String, String)>[
    ('\u2764\ufe0f Busco una relaci\u00f3n estable', 'relacion'),
    ('\ud83d\udd25 Busco algo casual / sin compromiso', 'casual'),
    ('\ud83d\udcac Busco amistad / conocer gente', 'amistad'),
    ('\ud83c\udf31 Abierto a lo que surja', 'abierto_a_lo_que_surja'),
  ];

  String _seleccion = '';
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() {
      final valor = perfil?.queBusca ?? '';
      final coincidencias = _opciones.where((o) => o.$2 == valor);
      _seleccion = coincidencias.isNotEmpty ? coincidencias.single.$1 : '';
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    if (_seleccion.isEmpty) {
      NotificacionServicio.alerta(context, 'Selecciona una opción.');
      return;
    }
    final coincidencias = _opciones.where((o) => o.$1 == _seleccion);
    final valor =
        coincidencias.isNotEmpty ? coincidencias.single.$2 : _seleccion;
    setState(() => _guardando = true);
    try {
      final perfil = await widget.repositorio.obtenerPerfilPropio();
      if (!mounted) return;
      if (perfil == null) {
        NotificacionServicio.alerta(context, 'No se encontró tu perfil.');
        return;
      }
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        queBusca: Value(valor),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(
          context, 'Preferencia actualizada correctamente.');
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
                  const Text(
                    '\u00bfQu\u00e9 est\u00e1s buscando en esta app?',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Elige la opci\u00f3n que mejor te describa ahora. Puedes cambiarla despu\u00e9s.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  Column(
                    children: [
                      for (final opcion in _opciones)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _tarjetaOpcion(opcion, primario),
                        ),
                    ],
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
          child: _BotonGuardar(guardando: _guardando, onPressed: _guardar),
        ),
      ),
    );
  }

  Widget _tarjetaOpcion((String, String) opcion, Color primario) {
    final seleccionada = _seleccion == opcion.$1;
    return InkWell(
      onTap: _guardando
          ? null
          : () {
              setState(() {
                _seleccion = seleccionada ? '' : opcion.$1;
              });
            },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                opcion.$1,
                style: TextStyle(
                  fontSize: 15,
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

class QuieroConocerPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;

  const QuieroConocerPantalla({super.key, required this.repositorio});

  @override
  State<QuieroConocerPantalla> createState() => _QuieroConocerPantallaState();
}

class _QuieroConocerPantallaState extends State<QuieroConocerPantalla> {
  static const _opciones = <(String, String)>[
    ('\ud83d\udc68 Hombres', 'hombres'),
    ('\ud83d\udc69 Mujeres', 'mujeres'),
    ('\u26a7\ufe0f Personas no binarias', 'no_binarias'),
    ('\ud83c\udf08 Todos/as', 'todos'),
    ('\ud83d\ude48 Prefiero no decirlo', 'prefiero_no_decirlo'),
  ];

  static const _valoresLegacy = {
    'hombre': '\ud83d\udc68 Hombres',
    'mujer': '\ud83d\udc69 Mujeres',
    'ambos': '\ud83c\udf08 Todos/as',
    'otro': '\ud83d\ude48 Prefiero no decirlo',
  };
  static const _generos = {
    '\ud83d\udc68 Hombres',
    '\ud83d\udc69 Mujeres',
    '\u26a7\ufe0f Personas no binarias',
  };
  static const _etiquetaTodos = '\ud83c\udf08 Todos/as';
  static const _etiquetaPrefiero = '\ud83d\ude48 Prefiero no decirlo';

  Set<String> _seleccion = {};
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  String? _etiquetaDesdeCodigo(String codigo) {
    for (final o in _opciones) {
      if (o.$2 == codigo) return o.$1;
    }
    return _valoresLegacy[codigo];
  }

  String? _codigoDesdeEtiqueta(String etiqueta) {
    for (final o in _opciones) {
      if (o.$1 == etiqueta) return o.$2;
    }
    return null;
  }

  Future<void> _cargar() async {
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() {
      final valor = perfil?.buscaGenero ?? '';
      _seleccion = {
        for (final codigo in valor.split(','))
          if (codigo.trim().isNotEmpty)
            if (_etiquetaDesdeCodigo(codigo.trim()) case final etiqueta?)
              etiqueta,
      };
      if (_seleccion.contains(_etiquetaTodos)) {
        _seleccion.addAll(_generos);
      }
      _cargando = false;
    });
  }

  void _alternar(String etiqueta) {
    setState(() {
      if (etiqueta == _etiquetaPrefiero) {
        _seleccion = {_etiquetaPrefiero};
        return;
      }

      _seleccion.remove(_etiquetaPrefiero);

      if (etiqueta == _etiquetaTodos) {
        if (_seleccion.contains(_etiquetaTodos)) {
          _seleccion.remove(_etiquetaTodos);
          _seleccion.removeAll(_generos);
        } else {
          _seleccion.add(_etiquetaTodos);
          _seleccion.addAll(_generos);
        }
        return;
      }

      if (_seleccion.contains(etiqueta)) {
        _seleccion.remove(etiqueta);
      } else {
        _seleccion.add(etiqueta);
      }

      final todosGeneros = _generos.every(_seleccion.contains);
      if (todosGeneros) {
        _seleccion.add(_etiquetaTodos);
      } else {
        _seleccion.remove(_etiquetaTodos);
      }
    });
  }

  Future<void> _guardar() async {
    if (_seleccion.isEmpty) {
      NotificacionServicio.alerta(
          context, 'Selecciona al menos una opción.');
      return;
    }
    String valor;
    if (_seleccion.contains(_etiquetaPrefiero)) {
      valor = 'prefiero_no_decirlo';
    } else if (_seleccion.contains(_etiquetaTodos)) {
      valor = 'todos';
    } else {
      valor = _seleccion
          .map((e) => _codigoDesdeEtiqueta(e) ?? e)
          .toList()
          .join(',');
    }
    setState(() => _guardando = true);
    try {
      final perfil = await widget.repositorio.obtenerPerfilPropio();
      if (!mounted) return;
      if (perfil == null) {
        NotificacionServicio.alerta(context, 'No se encontró tu perfil.');
        return;
      }
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        buscaGenero: Value(valor),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(
          context, 'Preferencia actualizada correctamente.');
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
                  const Text(
                    '\u00bfA qui\u00e9n te gustar\u00eda conocer?',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Elige las opciones que te interesen. Puedes seleccionar varias.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  Column(
                    children: [
                      for (final opcion in _opciones)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child:
                              _tarjetaOpcion(opcion.$1, primario),
                        ),
                    ],
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
          child: _BotonGuardar(guardando: _guardando, onPressed: _guardar),
        ),
      ),
    );
  }

  Widget _tarjetaOpcion(String opcion, Color primario) {
    final seleccionada = _seleccion.contains(opcion);
    return InkWell(
      onTap: _guardando ? null : () => _alternar(opcion),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                  fontSize: 15,
                  fontWeight:
                      seleccionada ? FontWeight.w600 : FontWeight.w500,
                  color: seleccionada ? primario : Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              seleccionada
                  ? Icons.check_circle
                  : Icons.circle_outlined,
              size: 22,
              color: seleccionada ? primario : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}

class RangoEdadPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;

  const RangoEdadPantalla({super.key, required this.repositorio});

  @override
  State<RangoEdadPantalla> createState() => _RangoEdadPantallaState();
}

class _RangoEdadPantallaState extends State<RangoEdadPantalla> {
  static const _minimo = 18;
  static const _maximo = 99;

  RangeValues _rango = const RangeValues(18, 99);
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() {
      final min = perfil?.preferenciaEdadMin ?? _minimo;
      final max = perfil?.preferenciaEdadMax ?? _maximo;
      _rango = RangeValues(
        min.clamp(_minimo, _maximo).toDouble(),
        max.clamp(_minimo, _maximo).toDouble(),
      );
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final perfil = await widget.repositorio.obtenerPerfilPropio();
      if (!mounted) return;
      if (perfil == null) {
        NotificacionServicio.alerta(context, 'No se encontr\u00f3 tu perfil.');
        return;
      }
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        preferenciaEdadMin: Value(_rango.start.round()),
        preferenciaEdadMax: Value(_rango.end.round()),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(
          context, 'Rango de edad actualizado correctamente.');
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
                              const Text(
                                'Rango de edad ideal',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '\u00bfEntre qu\u00e9 edades te gustar\u00eda que estuviera tu match?',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 28),
                              Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: primario.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: primario
                                          .withValues(alpha: 0.25)),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        _etiquetaEdad(
                                            _rango.start.round(), primario),
                                        const Text(
                                          'a',
                                          style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 14),
                                        ),
                                        _etiquetaEdad(
                                            _rango.end.round(), primario),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    RangeSlider(
                                      values: _rango,
                                      min: _minimo.toDouble(),
                                      max: _maximo.toDouble(),
                                      divisions: _maximo - _minimo,
                                      activeColor: primario,
                                      inactiveColor:
                                          primario.withValues(alpha: 0.2),
                                      labels: RangeLabels(
                                        '${_rango.start.round()}',
                                        '${_rango.end.round()}',
                                      ),
                                      onChanged: _guardando
                                          ? null
                                          : (v) =>
                                              setState(() => _rango = v),
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '$_minimo',
                                          style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 12),
                                        ),
                                        Text(
                                          '$_maximo',
                                          style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
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
          child: _BotonGuardar(guardando: _guardando, onPressed: _guardar),
        ),
      ),
    );
  }

  Widget _etiquetaEdad(int edad, Color primario) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: primario,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$edad',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

class InteresesPerfilPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;

  const InteresesPerfilPantalla({super.key, required this.repositorio});

  @override
  State<InteresesPerfilPantalla> createState() =>
      _InteresesPerfilPantallaState();
}

class _InteresesPerfilPantallaState extends State<InteresesPerfilPantalla> {
  static const _categorias = <(String, List<String>)>[
    ('🏃 Deportes y actividad física', [
      '⚽ Fútbol',
      '🏀 Baloncesto',
      '🎾 Tenis',
      '🏸 Pádel',
      '⛳ Golf',
      '🏃 Running / Atletismo',
      '🏊 Natación',
      '🚴 Ciclismo',
      '🥾 Senderismo / Montaña',
      '🧗 Escalada',
      '🏄 Surf',
      '🎿 Snowboard / Esquí',
      '🧘 Yoga',
      '🧘‍♀️ Pilates',
      '💪 CrossFit',
      '🏋️ Gimnasio / Fitness',
      '🥋 Artes marciales',
      '🥊 Boxeo',
      '⛸️ Patinaje',
      '🏐 Voleibol',
      '🏉 Rugby',
      '⚾ Béisbol',
    ]),
    ('🎨 Arte y cultura', [
      '🎬 Cine',
      '🎭 Teatro',
      '🏛️ Museos',
      '🎨 Pintura',
      '✏️ Dibujo',
      '🗿 Escultura',
      '📷 Fotografía',
      '📚 Literatura / Lectura',
      '📝 Poesía',
      '✍️ Escritura',
      '💃 Danza',
      '🩰 Ballet',
      '🎻 Música clásica',
      '🎵 Ópera',
    ]),
    ('🎵 Música', [
      '🎸 Rock',
      '🎤 Pop',
      '🎵 Reggaetón',
      '🇰🇷 K-pop',
      '🎷 Jazz',
      '🎛️ Música electrónica',
      '🎶 Indie',
      '💃 Salsa',
      '🎵 Bachata',
      '🤘 Metal',
      '🎤 Hip-hop / Rap',
      '🤠 Country',
      '💃 Flamenco',
      '🎵 Tango',
      '🎤 Cantar / Karaoke',
      '🎹 Tocar un instrumento',
    ]),
    ('🍽️ Gastronomía', [
      '🍳 Cocina / Repostería',
      '🍽️ Gastronomía',
      '🍷 Vino / Enología',
      '🍺 Cerveza artesanal',
      '☕ Café / Cafeterías',
      '🌱 Comida vegana / Vegetariana',
      '🍣 Comida asiática',
      '🍝 Comida italiana',
      '🌮 Comida mexicana',
      '🥩 Parrillas / Barbacoa',
      '🧀 Quesos / Catas',
      '🍜 Restaurantes / Foodie',
    ]),
    ('✈️ Viajes y aventura', [
      '✈️ Viajar',
      '🎒 Mochilero / Backpacker',
      '🏡 Turismo rural',
      '🏙️ Ciudades europeas',
      '🏖️ Playas / Mar',
      '🚢 Cruceros',
      '🚗 Viajes en carretera',
      '📸 Fotografía de viaje',
      '⛺ Acampar / Camping',
      '🏕️ Glamping',
    ]),
    ('🌿 Naturaleza y animales', [
      '🌿 Naturaleza',
      '🐾 Animales',
      '🐕 Perros',
      '🐈 Gatos',
      '🥾 Senderismo',
      '🌻 Jardinería',
      '🌍 Ecología',
      '🦅 Observación de aves',
      '🌱 Plantas / Suculentas',
    ]),
    ('🎮 Ocio y entretenimiento', [
      '🎮 Videojuegos',
      '📺 Series / TV',
      '🎌 Anime / Manga',
      '📖 Cómics',
      '🎬 Cine',
      '🎲 Juegos de mesa',
      '🧩 Puzzles / Rompecabezas',
      '🎩 Magia',
      '🎭 Stand-up / Comedia',
    ]),
    ('🧘 Estilo de vida y bienestar', [
      '🧘 Meditación',
      '🌿 Mindfulness',
      '📈 Desarrollo personal',
      '👗 Moda / Estilo',
      '📱 Tecnología / Gadgets',
      '🚀 Startups / Emprendimiento',
      '🗳️ Política / Actualidad',
      '✊ Activismo',
      '🤝 Voluntariado',
      '♻️ Sostenibilidad',
    ]),
    ('🎨 Creatividad y hobbies', [
      '📷 Fotografía',
      '✍️ Escritura creativa',
      '🎨 Dibujo / Ilustración',
      '🧶 Manualidades / DIY',
      '🏺 Cerámica',
      '🌻 Jardinería',
      '🍳 Cocina',
      '💃 Baile',
    ]),
    ('🔬 Ciencia y conocimiento', [
      '🔬 Ciencia',
      '🌌 Astronomía',
      '📜 Historia',
      '💭 Filosofía',
      '🧠 Psicología',
      '💻 Tecnología',
      '🤖 Inteligencia artificial',
      '⚙️ Robótica',
    ]),
  ];

  Set<String> _intereses = {};
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() {
      _intereses = perfil?.intereses.toSet() ?? {};
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final perfil = await widget.repositorio.obtenerPerfilPropio();
      if (!mounted) return;
      if (perfil == null) {
        NotificacionServicio.alerta(context, 'No se encontró tu perfil.');
        return;
      }
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        intereses: Value(_intereses.toList()),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(context, 'Intereses actualizados correctamente.');
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
          'Intereses',
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
                  const Text(
                    'Tus intereses',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Elige hasta 10 intereses para conectar con personas afines.',
                    style:
                        TextStyle(color: Colors.grey[600], fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  for (final categoria in _categorias) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        categoria.$1,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: primario,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final interes in categoria.$2)
                            FilterChip(
                              label: Text(
                                interes,
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.black87),
                              ),
                              selected: _intereses.contains(interes),
                              onSelected: _guardando ||
                                      (_intereses.length >= 10 &&
                                          !_intereses.contains(interes))
                                  ? null
                                  : (s) {
                                      setState(() {
                                        if (s) {
                                          _intereses.add(interes);
                                        } else {
                                          _intereses.remove(interes);
                                        }
                                      });
                                    },
                              selectedColor:
                                  primario.withValues(alpha: 0.15),
                              checkmarkColor: primario,
                              side: BorderSide(
                                  color:
                                      primario.withValues(alpha: 0.3)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
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
          child: _BotonGuardar(guardando: _guardando, onPressed: _guardar),
        ),
      ),
    );
  }
}

class PersonalidadPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;

  const PersonalidadPantalla({super.key, required this.repositorio});

  @override
  State<PersonalidadPantalla> createState() => _PersonalidadPantallaState();
}

class _PersonalidadPantallaState extends State<PersonalidadPantalla> {
  static const _categorias = <(String, List<String>)>[
    ('Energ\u00eda social (C\u00f3mo te relacionas)', [
      '\ud83d\udde3\ufe0f Extrovertido/a',
      '\ud83e\uddd8 Introvertido/a',
      '\u2696\ufe0f Ambivertido/a',
    ]),
    ('Estilo de pensamiento', [
      '\ud83e\udde0 Racional / L\u00f3gico',
      '\u2764\ufe0f Emocional / Sentimental',
      '\ud83c\udfa8 Creativo / Imaginativo',
      '\ud83d\udd0d Anal\u00edtico / Detallista',
    ]),
    ('Actitud ante la vida', [
      '\ud83d\ude04 Divertido/a / Alegre',
      '\ud83e\udd14 Serio/a / Reflexivo/a',
      '\u26a1 Espont\u00e1neo/a / Impulsivo/a',
      '\ud83d\udccb Planificador/a / Organizado/a',
    ]),
    ('Estilo de relaci\u00f3n', [
      '\ud83e\udd17 Emp\u00e1tico/a / Comprensivo/a',
      '\ud83e\udd85 Independiente / Autosuficiente',
      '\ud83e\udd1d Leal / Fiel',
    ]),
    ('Otros rasgos', [
      '\ud83d\udd2c Curioso/a / Aprendiz',
      '\ud83c\udfc4 Aventurero/a',
      '\ud83c\udf0a Tranquilo/a / Pac\u00edfico/a',
      '\ud83c\udfc6 Competitivo/a',
    ]),
  ];

  static const _legacy = <String, String>{
    'extrovertida': '\ud83d\udde3\ufe0f Extrovertido/a',
    'introvertida': '\ud83e\uddd8 Introvertido/a',
    'ambas': '\u2696\ufe0f Ambivertido/a',
    'creativa': '\ud83c\udfa8 Creativo / Imaginativo',
    'empatica': '\ud83e\udd17 Emp\u00e1tico/a / Comprensivo/a',
    'divertida': '\ud83d\ude04 Divertido/a / Alegre',
  };

  Set<String> _seleccionadas = {};
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  String _aEtiqueta(String parte) {
    final p = parte.trim();
    if (_legacy.containsKey(p)) return _legacy[p]!;
    for (final categoria in _categorias) {
      if (categoria.$2.contains(p)) return p;
    }
    return '';
  }

  Future<void> _cargar() async {
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() {
      final valor = perfil?.personalidad ?? '';
      _seleccionadas = valor
          .split(',')
          .map(_aEtiqueta)
          .where((e) => e.isNotEmpty)
          .toSet();
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final perfil = await widget.repositorio.obtenerPerfilPropio();
      if (!mounted) return;
      if (perfil == null) {
        NotificacionServicio.alerta(context, 'No se encontr\u00f3 tu perfil.');
        return;
      }
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        personalidad: Value(_seleccionadas.join(', ')),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(
          context, 'Personalidad actualizada correctamente.');
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
                              const Text(
                                '\u00bfC\u00f3mo describir\u00edas tu personalidad?',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Elige hasta 3 opciones que mejor te definan.',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              for (final categoria in _categorias) ...[
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    categoria.$1,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: primario,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final opcion in categoria.$2)
                                        FilterChip(
                                          label: Text(
                                            opcion,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.black87),
                                          ),
                                          selected: _seleccionadas
                                              .contains(opcion),
                                          onSelected: _guardando ||
                                                  (_seleccionadas.length >= 3 &&
                                                      !_seleccionadas
                                                          .contains(opcion))
                                              ? null
                                              : (s) {
                                                  setState(() {
                                                    if (s) {
                                                      _seleccionadas.add(
                                                          opcion);
                                                    } else {
                                                      _seleccionadas.remove(
                                                          opcion);
                                                    }
                                                  });
                                                },
                                          selectedColor: primario
                                              .withValues(alpha: 0.15),
                                          checkmarkColor: primario,
                                          side: BorderSide(
                                              color:
                                                  primario.withValues(alpha: 0.3)),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),
                              ],
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
          child: _BotonGuardar(guardando: _guardando, onPressed: _guardar),
        ),
      ),
    );
  }
}

class SobreMiPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;

  const SobreMiPantalla({super.key, required this.repositorio});

  @override
  State<SobreMiPantalla> createState() => _SobreMiPantallaState();
}

class _SobreMiPantallaState extends State<SobreMiPantalla> {
  static const _maxCaracteres = 500;

  final _controlador = TextEditingController();
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() {
      if (perfil != null) _controlador.text = perfil.biografia;
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final perfil = await widget.repositorio.obtenerPerfilPropio();
      if (!mounted) return;
      if (perfil == null) {
        NotificacionServicio.alerta(context, 'No se encontr\u00f3 tu perfil.');
        return;
      }
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        biografia: Value(_controlador.text.trim()),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(
          context, 'Biograf\u00eda actualizada correctamente.');
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
                              const Text(
                                'Sobre m\u00ed',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Cu\u00e9ntanos algo sobre ti. \u00bfQu\u00e9 te hace \u00fanico/a?',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              TextField(
                                controller: _controlador,
                                maxLines: 6,
                                maxLength: _maxCaracteres,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                style: const TextStyle(
                                    color: Colors.black87, fontSize: 15,
                                    height: 1.4),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  hintText:
                                      'Escribe algo que no se vea en tu perfil.',
                                  counterStyle: const TextStyle(
                                      fontSize: 12, color: Colors.black54),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: primario
                                            .withValues(alpha: 0.3)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: primario
                                            .withValues(alpha: 0.3)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Colors.black54, width: 1.5),
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 14),
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
          child: _BotonGuardar(guardando: _guardando, onPressed: _guardar),
        ),
      ),
    );
  }
}

class PreguntasPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;

  const PreguntasPantalla({super.key, required this.repositorio});

  @override
  State<PreguntasPantalla> createState() => _PreguntasPantallaState();
}

class _PreguntasPantallaState extends State<PreguntasPantalla> {
  static const _maxPreguntas = 3;
  static const _maxCaracteres = 300;

  static const _categorias = <(String, List<String>)>[
    ('💘 Citas y romance', [
      '¿Cuál es tu plan de cita ideal?',
      '¿Qué es lo que más valoras en una relación?',
      '¿Cuál es la mejor cita que has tenido?',
      '¿Qué harías en una primera cita para causar buena impresión?',
      '¿Cuál es el gesto más romántico que has recibido?',
      '¿Qué te hace sentir especial en una relación?',
    ]),
    ('😄 Humor y personalidad', [
      '¿Cuál es tu mejor chiste malo?',
      '¿Qué serie o película puedes ver una y otra vez?',
      '¿Cuál es tu mayor manía o rareza?',
      '¿Qué es lo que nunca te esperarías de mí?',
      '¿Qué cosa vergonzosa te ha pasado en una cita?',
      '¿Cuál es tu canción de karaoke infalible?',
    ]),
    ('✈️ Viajes y aventura', [
      '¿Cuál es tu destino de viaje soñado?',
      '¿Cuál ha sido tu mejor viaje?',
      '¿Prefieres playa o montaña? ¿Por qué?',
      '¿Qué país te gustaría visitar y por qué?',
      '¿Cuál es la aventura más loca que has hecho?',
      '¿Viajarías solo/a o siempre acompañado/a?',
    ]),
    ('🍽️ Gastronomía y vida', [
      '¿Qué plato define tu personalidad?',
      '¿Cuál es tu comida favorita para una cita?',
      '¿Eres más de cocinar o de pedir delivery?',
      '¿Qué no puede faltar en tu nevera?',
      '¿Cuál es tu restaurante favorito y por qué?',
      '¿Qué comida no soportas?',
    ]),
    ('💭 Reflexión y valores', [
      '¿Qué es lo que más te apasiona en la vida?',
      '¿Cuál es el mejor consejo que has recibido?',
      '¿Qué harías si te tocara la lotería?',
      '¿Qué es lo que más te asusta de una relación?',
      '¿Cuál es tu mayor logro personal?',
      '¿Qué te hace feliz de verdad?',
    ]),
  ];

  List<PreguntaRespuesta> _respondidas = [];
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() {
      _respondidas = List.of(perfil?.preguntasPerfil ?? const []);
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final perfil = await widget.repositorio.obtenerPerfilPropio();
      if (!mounted) return;
      if (perfil == null) {
        NotificacionServicio.alerta(context, 'No se encontr\u00f3 tu perfil.');
        return;
      }
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        preguntasPerfil: Value(List.of(_respondidas)),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(
          context, 'Preguntas actualizadas correctamente.');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      NotificacionServicio.alerta(context, e.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  String _usadasPorOtros(int indice) {
    final usadas = <String>[];
    for (var i = 0; i < _respondidas.length; i++) {
      if (i != indice) usadas.add(_respondidas[i].pregunta);
    }
    return usadas.join('|');
  }

  Future<void> _elegirPregunta(int indice) async {
    final usadas = _usadasPorOtros(indice).split('|').toSet();
    final elegida = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _SelectorPregunta(
        categorias: _categorias,
        usadas: usadas,
      ),
    );
    if (elegida == null || !mounted) return;
    final respuesta = await _escribirRespuesta(
      pregunta: elegida,
      inicial: indice < _respondidas.length
          ? _respondidas[indice].respuesta
          : '',
    );
    if (respuesta == null || !mounted) return;
    setState(() {
      if (indice < _respondidas.length) {
        _respondidas[indice] =
            PreguntaRespuesta(pregunta: elegida, respuesta: respuesta);
      } else {
        _respondidas.add(
            PreguntaRespuesta(pregunta: elegida, respuesta: respuesta));
      }
    });
  }

  Future<String?> _escribirRespuesta(
      {required String pregunta, required String inicial}) {
    final controller = TextEditingController(text: inicial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Tu respuesta',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pregunta,
              style: const TextStyle(
                  fontSize: 14, color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              maxLength: _maxCaracteres,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Escribe tu respuesta...',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.black54)),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim()),
            child: const Text('Guardar',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
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
                              const Text(
                                'Preguntas para conocerte mejor',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Responde 3 preguntas para que la gente sepa c\u00f3mo eres realmente.',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              for (var i = 0; i < _respondidas.length; i++)
                                _tarjetaPregunta(primario, i),
                              if (_respondidas.length < _maxPreguntas)
                                _tarjetaAnadir(primario,
                                    _respondidas.length),
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
          child: _BotonGuardar(guardando: _guardando, onPressed: _guardar),
        ),
      ),
    );
  }

  Widget _tarjetaPregunta(Color primario, int indice) {
    final item = _respondidas[indice];
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primario.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pregunta ${indice + 1}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: primario),
                ),
              ),
              TextButton.icon(
                onPressed: _guardando
                    ? null
                    : () {
                        setState(() {
                          _respondidas.removeAt(indice);
                        });
                      },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: Colors.redAccent,
                ),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Quitar',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          Text(
            item.pregunta,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                height: 1.35),
          ),
          const SizedBox(height: 8),
          Text(
            item.respuesta.isEmpty
                ? 'Sin responder a\u00fan'
                : item.respuesta,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: item.respuesta.isEmpty
                  ? Colors.grey[400]
                  : Colors.black54,
            ),
          ),
          TextButton.icon(
            onPressed: _guardando
                ? null
                : () async {
                    final respuesta = await _escribirRespuesta(
                      pregunta: item.pregunta,
                      inicial: item.respuesta,
                    );
                    if (respuesta == null || !mounted) return;
                    setState(() {
                      _respondidas[indice] = PreguntaRespuesta(
                          pregunta: item.pregunta, respuesta: respuesta);
                    });
                  },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: primario,
            ),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Editar respuesta',
                style:
                    TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaAnadir(Color primario, int indice) {
    return InkWell(
      onTap: _guardando ? null : () => _elegirPregunta(indice),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: primario.withValues(alpha: 0.5)),
          color: primario.withValues(alpha: 0.05),
        ),
        child: Column(
          children: [
            Icon(Icons.add_circle_outline, color: primario, size: 28),
            const SizedBox(height: 6),
            Text(
              'A\u00f1adir pregunta',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: primario),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectorPregunta extends StatelessWidget {
  final List<(String, List<String>)> categorias;
  final Set<String> usadas;

  const _SelectorPregunta({required this.categorias, required this.usadas});

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                'Elige una pregunta',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Las preguntas ya usadas no se muestran.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  for (final categoria in categorias) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        categoria.$1,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: primario,
                        ),
                      ),
                    ),
                    for (final pregunta in categoria.$2)
                      if (!usadas.contains(pregunta))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            pregunta,
                            style: const TextStyle(
                                fontSize: 14, color: Colors.black87),
                          ),
                          trailing: Icon(Icons.chevron_right,
                              color: Colors.grey[400], size: 20),
                          onTap: () => Navigator.pop(context, pregunta),
                        ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BotonGuardar extends StatelessWidget {
  final bool guardando;
  final VoidCallback? onPressed;

  const _BotonGuardar({required this.guardando, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: guardando ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primario,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: guardando
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
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
      ),
    );
  }
}