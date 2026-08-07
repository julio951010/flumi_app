import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;

import '../../../core/base_datos_local/database.dart';
import '../../../core/base_datos_local/tables.dart';
import '../../../core/servicios/notificacion_servicio.dart';
import '../../onboarding/pantallas/widgets/autocomplete_opcion.dart';
import '../../onboarding/pantallas/widgets/busca_genero_opcion.dart';
import '../../onboarding/pantallas/widgets/campo_personalizado_opcion.dart';
import '../../onboarding/pantallas/widgets/preguntas_perfil_opcion.dart';
import '../../onboarding/pantallas/widgets/rango_edad_opcion.dart';
import '../../onboarding/pantallas/widgets/selector_categorias.dart';
import '../../onboarding/pantallas/widgets/selector_multi_opciones.dart';
import '../../onboarding/pantallas/widgets/selector_opciones.dart';
import '../../onboarding/pantallas/widgets/slider_opcion.dart';
import '../../onboarding/pantallas/widgets/text_area_opcion.dart';
import '../perfil_etiquetas.dart';
import '../perfil_repositorio.dart';

String _codigoSiEnLista(List<OpcionEtiqueta> opciones, String v) {
  return opciones.any((o) => o.$2 == v) ? v : '';
}

class _PlantillaPerfil extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final String? tituloAppBar;
  final Widget hijo;
  final bool cargando;
  final bool guardando;
  final VoidCallback onGuardar;

  const _PlantillaPerfil({
    required this.titulo,
    required this.subtitulo,
    required this.hijo,
    required this.cargando,
    required this.guardando,
    required this.onGuardar,
    this.tituloAppBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: tituloAppBar == null
            ? null
            : Text(
                tituloAppBar!,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
              ),
      ),
      body: SafeArea(
        top: false,
        child: cargando
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                titulo,
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                subtitulo,
                                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                              ),
                              const SizedBox(height: 20),
                              hijo,
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
          child: _BotonGuardar(guardando: guardando, onPressed: onGuardar),
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
  static const _legacy = {
    'homosexual': 'gay',
    'no_comparto': 'prefiero no decirlo',
    'otro': 'otro',
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
      final v = perfil?.orientacionSexual ?? '';
      if (v.isNotEmpty) {
        final m = _legacy[v] ?? v;
        final esValida = opcionesOrientacionSexual.any((o) => o.$2 == m);
        if (esValida) {
          _seleccion = m;
        } else {
          _personalizadaCtrl.text = m;
        }
      }
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    final texto = _personalizadaCtrl.text.trim();
    if (_seleccion.isEmpty && texto.isEmpty) {
      NotificacionServicio.alerta(context, 'Selecciona una opción o escribe la tuya.');
      return;
    }
    final valor = _seleccion.isNotEmpty ? _seleccion : texto;
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
      NotificacionServicio.exito(context, 'Orientación sexual actualizada correctamente.');
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
    return _PlantillaPerfil(
      titulo: '¿Cuál es tu orientación sexual?',
      subtitulo: 'Elige la que mejor te describa',
      cargando: _cargando,
      guardando: _guardando,
      onGuardar: _guardar,
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectorOpciones(
            valorActual: _seleccion,
            opciones: opcionesOrientacionSexual,
            onSeleccion: (v) => setState(() {
              _seleccion = v;
              _personalizadaCtrl.clear();
            }),
          ),
          const SizedBox(height: 24),
          CampoPersonalizadoOpcion(
            controlador: _personalizadaCtrl,
            habilitado: !_guardando,
            onCambio: (v) {
              if (v.trim().isNotEmpty && _seleccion.isNotEmpty) {
                setState(() => _seleccion = '');
              }
            },
          ),
        ],
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
      _seleccion =
          _codigoSiEnLista(opcionesSituacion, perfil?.situacionSentimental ?? '');
      _cargando = false;
    });
  }

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
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        situacionSentimental: Value(_seleccion),
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
    return _PlantillaPerfil(
      titulo: 'Cuéntanos sobre tu vida sentimental ahora mismo',
      subtitulo: 'Esto ayuda a que te conectemos con personas compatibles.',
      cargando: _cargando,
      guardando: _guardando,
      onGuardar: _guardar,
      hijo: SelectorOpciones(
        valorActual: _seleccion,
        opciones: opcionesSituacion,
        onSeleccion: (v) => setState(() => _seleccion = v),
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
  static const _legacy = {
    'bachillerato': 'secundaria',
    'en_curso': 'universidad',
  };

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
      final v = _legacy[perfil?.educacion] ?? perfil?.educacion ?? '';
      _seleccion = _codigoSiEnLista(opcionesEducacion, v);
      _cargando = false;
    });
  }

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
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        educacion: Value(_seleccion),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(context, 'Nivel educativo actualizado correctamente.');
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
    return _PlantillaPerfil(
      titulo: '¿Cuál es tu nivel de estudios?',
      subtitulo: 'Esto ayuda a conectar con personas con intereses afines.',
      cargando: _cargando,
      guardando: _guardando,
      onGuardar: _guardar,
      hijo: SelectorOpciones(
        opciones: opcionesEducacion,
        valorActual: _seleccion,
        onSeleccion: (v) => setState(() => _seleccion = v),
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
      _seleccion = _codigoSiEnLista(opcionesTrabajo, perfil?.trabajo ?? '');
      _cargando = false;
    });
  }

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
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        trabajo: Value(_seleccion),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(context, 'Trabajo actualizado correctamente.');
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
    return _PlantillaPerfil(
      titulo: '¿En qué sector trabajas?',
      subtitulo: 'Ayuda a conocer un poco más sobre tu día a día.',
      cargando: _cargando,
      guardando: _guardando,
      onGuardar: _guardar,
      hijo: SelectorOpciones(
        valorActual: _seleccion,
        opciones: opcionesTrabajo,
        onSeleccion: (v) => setState(() => _seleccion = v),
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
  static const _legacy = {
    'si': 'tengo_no_mas',
    'no': 'no_quiero',
  };

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
      final v = _legacy[perfil?.hijos] ?? perfil?.hijos ?? '';
      _seleccion = _codigoSiEnLista(opcionesHijos, v);
      _cargando = false;
    });
  }

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
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        hijos: Value(_seleccion),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(context, 'Preferencia de hijos actualizada correctamente.');
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
    return _PlantillaPerfil(
      titulo: '¿Tienes hijos?',
      subtitulo: 'Es importante para conectar con personas compatibles.',
      cargando: _cargando,
      guardando: _guardando,
      onGuardar: _guardar,
      hijo: SelectorOpciones(
        valorActual: _seleccion,
        opciones: opcionesHijos,
        onSeleccion: (v) => setState(() => _seleccion = v),
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
  static const _legacy = {
    'no': 'no_fumo',
    'social': 'fumo_social',
    'si': 'fumo_diario',
  };

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
      final v = _legacy[perfil?.fuma] ?? perfil?.fuma ?? '';
      _seleccion = _codigoSiEnLista(opcionesTabaco, v);
      _cargando = false;
    });
  }

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
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        fuma: Value(_seleccion),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(context, 'Preferencia actualizada correctamente.');
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
    return _PlantillaPerfil(
      titulo: '¿Fumas?',
      subtitulo: 'Ayuda a conectar con personas con hábitos similares.',
      cargando: _cargando,
      guardando: _guardando,
      onGuardar: _guardar,
      hijo: SelectorOpciones(
        valorActual: _seleccion,
        opciones: opcionesTabaco,
        onSeleccion: (v) => setState(() => _seleccion = v),
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
  static const _legacy = {
    'no': 'no_bebo',
    'social': 'bebo_social',
    'si': 'bebo_moderacion',
  };

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
      final v = _legacy[perfil?.bebe] ?? perfil?.bebe ?? '';
      _seleccion = _codigoSiEnLista(opcionesAlcohol, v);
      _cargando = false;
    });
  }

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
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        bebe: Value(_seleccion),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(context, 'Preferencia actualizada correctamente.');
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
    return _PlantillaPerfil(
      titulo: '¿Bebes alcohol?',
      subtitulo: 'Ayuda a conectar con personas con hábitos similares.',
      cargando: _cargando,
      guardando: _guardando,
      onGuardar: _guardar,
      hijo: SelectorOpciones(
        valorActual: _seleccion,
        opciones: opcionesAlcohol,
        onSeleccion: (v) => setState(() => _seleccion = v),
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
  static const _legacy = {
    'ave': 'otro',
    'otro': 'otro',
    'otras': 'otro',
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
      final v = _legacy[perfil?.mascotas] ?? perfil?.mascotas ?? '';
      final esValida = opcionesMascotas.any((o) => o.$2 == v);
      if (esValida) {
        _seleccion = v;
      } else if (v.isNotEmpty) {
        _personalizadaCtrl.text = v == 'otro' ? 'Otras mascotas' : v;
      }
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    final texto = _personalizadaCtrl.text.trim();
    if (_seleccion.isEmpty && texto.isEmpty) {
      NotificacionServicio.alerta(context, 'Selecciona una opción o escribe la tuya.');
      return;
    }
    final valor = _seleccion.isNotEmpty ? _seleccion : texto;
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
        mascotas: Value(valor),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(context, 'Mascotas actualizadas correctamente.');
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
    return _PlantillaPerfil(
      titulo: '¿Tienes mascotas?',
      subtitulo: 'Compartir el amor por los animales siempre suma.',
      cargando: _cargando,
      guardando: _guardando,
      onGuardar: _guardar,
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectorOpciones(
            valorActual: _seleccion,
            opciones: opcionesMascotas,
            onSeleccion: (v) => setState(() {
              _seleccion = v;
              _personalizadaCtrl.clear();
            }),
          ),
          const SizedBox(height: 24),
          CampoPersonalizadoOpcion(
            controlador: _personalizadaCtrl,
            habilitado: !_guardando,
            onCambio: (v) {
              if (v.trim().isNotEmpty && _seleccion.isNotEmpty) {
                setState(() => _seleccion = '');
              }
            },
          ),
        ],
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
  static const _legacy = {'otra': 'otra', 'otro': 'otro'};

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
      final v = _legacy[perfil?.religion] ?? perfil?.religion ?? '';
      final esValida = opcionesReligion.any((o) => o.$2 == v);
      if (esValida) {
        _seleccion = v;
      } else if (v.isNotEmpty) {
        _personalizadaCtrl.text = (v == 'otra' || v == 'otro') ? 'Otra' : v;
      }
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    final texto = _personalizadaCtrl.text.trim();
    if (_seleccion.isEmpty && texto.isEmpty) {
      NotificacionServicio.alerta(context, 'Selecciona una opción o escribe la tuya.');
      return;
    }
    final valor = _seleccion.isNotEmpty ? _seleccion : texto;
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
        religion: Value(valor),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(context, 'Religión actualizada correctamente.');
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
    return _PlantillaPerfil(
      titulo: '¿Cuál es tu religión o creencia?',
      subtitulo: 'Compartir tus valores ayuda a conectar con personas afines.',
      cargando: _cargando,
      guardando: _guardando,
      onGuardar: _guardar,
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectorOpciones(
            valorActual: _seleccion,
            opciones: opcionesReligion,
            onSeleccion: (v) => setState(() {
              _seleccion = v;
              _personalizadaCtrl.clear();
            }),
          ),
          const SizedBox(height: 24),
          CampoPersonalizadoOpcion(
            controlador: _personalizadaCtrl,
            habilitado: !_guardando,
            onCambio: (v) {
              if (v.trim().isNotEmpty && _seleccion.isNotEmpty) {
                setState(() => _seleccion = '');
              }
            },
          ),
        ],
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
  static const _legacy = {'si': 'tengo_alguno', 'no': 'no_tengo'};

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
      final v = _legacy[perfil?.tatuajes] ?? perfil?.tatuajes ?? '';
      _seleccion = _codigoSiEnLista(opcionesTatuajes, v);
      _cargando = false;
    });
  }

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
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        tatuajes: Value(_seleccion),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(context, 'Tatuajes actualizados correctamente.');
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
    return _PlantillaPerfil(
      titulo: '¿Tienes tatuajes?',
      subtitulo: 'El arte en la piel dice mucho sobre ti.',
      cargando: _cargando,
      guardando: _guardando,
      onGuardar: _guardar,
      hijo: SelectorOpciones(
        valorActual: _seleccion,
        opciones: opcionesTatuajes,
        onSeleccion: (v) => setState(() => _seleccion = v),
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
      _seleccion = _codigoSiEnLista(opcionesQueBusca, perfil?.queBusca ?? '');
      _cargando = false;
    });
  }

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
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        queBusca: Value(_seleccion),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(context, 'Preferencia actualizada correctamente.');
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
    return _PlantillaPerfil(
      titulo: '¿Qué estás buscando en esta app?',
      subtitulo: 'Elige la opción que mejor te describa ahora. Puedes cambiarla después.',
      cargando: _cargando,
      guardando: _guardando,
      onGuardar: _guardar,
      hijo: SelectorOpciones(
        valorActual: _seleccion,
        opciones: opcionesQueBusca,
        onSeleccion: (v) => setState(() => _seleccion = v),
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
  static const _legacy = {
    'hombre': 'hombres',
    'mujer': 'mujeres',
    'ambos': 'todos',
    'otro': 'prefiero_no_decirlo',
  };

  Set<String> _seleccion = {};
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
      final valor = perfil?.buscaGenero ?? '';
      _seleccion = {
        for (final c in valor.split(','))
          if (c.trim().isNotEmpty) _legacy[c.trim()] ?? c.trim(),
      };
      if (_seleccion.contains('todos')) {
        _seleccion.addAll(BuscaGeneroOpcion.codigosGeneros);
      }
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    if (_seleccion.isEmpty) {
      NotificacionServicio.alerta(context, 'Selecciona al menos una opción.');
      return;
    }
    String valor;
    if (_seleccion.contains('prefiero_no_decirlo')) {
      valor = 'prefiero_no_decirlo';
    } else if (_seleccion.contains('todos')) {
      valor = 'todos';
    } else {
      valor = _seleccion.toList().join(',');
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
      NotificacionServicio.exito(context, 'Preferencia actualizada correctamente.');
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
    return _PlantillaPerfil(
      titulo: '¿A quién te gustaría conocer?',
      subtitulo: 'Elige las opciones que te interesen. Puedes seleccionar varias.',
      cargando: _cargando,
      guardando: _guardando,
      onGuardar: _guardar,
      hijo: BuscaGeneroOpcion(
        seleccionados: _seleccion,
        onCambio: (v) => setState(() => _seleccion = v),
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
  final _ctrl = TextEditingController();
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
      NotificacionServicio.alerta(context, 'Escribe tu profesión.');
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
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        profesion: Value(texto),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(context, 'Profesión actualizada correctamente.');
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
    return _PlantillaPerfil(
      titulo: '¿Cuál es tu profesión?',
      subtitulo: 'Compartir tu profesión ayuda a conectar con personas afines.',
      cargando: _cargando,
      guardando: _guardando,
      onGuardar: _guardar,
      hijo: AutocompleteOpcion(
        controller: _ctrl,
        sugerencias: listaProfesiones,
        hint: 'Escribe tu profesión...',
        onCambio: (_) {},
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
  Set<String> _idiomas = {};
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
      _idiomas = (perfil?.idiomas ?? '')
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
        idiomas: Value(_idiomas.toList().join(', ')),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(context, 'Idiomas actualizados correctamente.');
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
    return _PlantillaPerfil(
      titulo: '¿Qué idiomas hablas?',
      subtitulo: 'Compartir idiomas ayuda a conectar con personas de todo el mundo.',
      cargando: _cargando,
      guardando: _guardando,
      onGuardar: _guardar,
      hijo: SelectorMultiOpciones(
        seleccionados: _idiomas,
        opciones: idiomasDisponibles,
        onCambio: (v) => setState(() => _idiomas = v),
      ),
    );
  }
}

class InteresesPerfilPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;

  const InteresesPerfilPantalla({super.key, required this.repositorio});

  @override
  State<InteresesPerfilPantalla> createState() => _InteresesPerfilPantallaState();
}

class _InteresesPerfilPantallaState extends State<InteresesPerfilPantalla> {
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
    return _PlantillaPerfil(
      tituloAppBar: 'Intereses',
      titulo: 'Tus intereses',
      subtitulo: 'Elige hasta 10 intereses para conectar con personas afines.',
      cargando: _cargando,
      guardando: _guardando,
      onGuardar: _guardar,
      hijo: SelectorCategorias(
        categorias: categoriasIntereses,
        seleccionados: _intereses,
        maxSeleccion: 10,
        onCambio: (v) => setState(() => _intereses = v),
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
  Set<String> _seleccionadas = {};
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
      final valor = perfil?.personalidad ?? '';
      _seleccionadas = listaPersonalidad(valor).toSet();
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
        personalidad: Value(_seleccionadas.join(', ')),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(context, 'Personalidad actualizada correctamente.');
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
    return _PlantillaPerfil(
      titulo: '¿Cómo describirías tu personalidad?',
      subtitulo: 'Elige hasta 3 opciones que mejor te definan.',
      cargando: _cargando,
      guardando: _guardando,
      onGuardar: _guardar,
      hijo: SelectorCategorias(
        categorias: categoriasPersonalidad,
        seleccionados: _seleccionadas,
        maxSeleccion: 3,
        onCambio: (v) => setState(() => _seleccionadas = v),
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
      _controlador.text = perfil?.biografia ?? '';
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
        biografia: Value(_controlador.text.trim()),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(context, 'Biografía actualizada correctamente.');
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
    return _PlantillaPerfil(
      titulo: 'Sobre mí',
      subtitulo: 'Cuéntanos algo sobre ti. ¿Qué te hace único/a?',
      cargando: _cargando,
      guardando: _guardando,
      onGuardar: _guardar,
      hijo: TextAreaOpcion(
        controller: _controlador,
        hint: 'Escribe algo que no se vea en tu perfil.',
        maxLines: 6,
        maxLength: _maxCaracteres,
        onCambio: (_) {},
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
        NotificacionServicio.alerta(context, 'No se encontró tu perfil.');
        return;
      }
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        preguntasPerfil: Value(List.of(_respondidas)),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(context, 'Preguntas actualizadas correctamente.');
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
    return _PlantillaPerfil(
      titulo: 'Preguntas para conocerte mejor',
      subtitulo: 'Responde 3 preguntas para que la gente sepa cómo eres realmente.',
      cargando: _cargando,
      guardando: _guardando,
      onGuardar: _guardar,
      hijo: PreguntasPerfilOpcion(
        preguntas: _respondidas,
        maxPreguntas: _maxPreguntas,
        onCambio: (v) => setState(() => _respondidas = List.of(v)),
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
        NotificacionServicio.alerta(context, 'No se encontró tu perfil.');
        return;
      }
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        preferenciaEdadMin: Value(_rango.start.round()),
        preferenciaEdadMax: Value(_rango.end.round()),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(context, 'Rango de edad actualizado correctamente.');
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
    return _PlantillaPerfil(
      titulo: 'Rango de edad ideal',
      subtitulo: '¿Entre qué edades te gustaría que estuviera tu match?',
      cargando: _cargando,
      guardando: _guardando,
      onGuardar: _guardar,
      hijo: RangoEdadOpcion(
        rango: _rango,
        minimo: _minimo,
        maximo: _maximo,
        deshabilitado: _guardando,
        onCambio: (v) => setState(() => _rango = v),
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
  static const _min = 140.0;
  static const _max = 220.0;

  double _alturaCm = 175;
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
        _alturaCm = cm.clamp(_min, _max);
      }
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    if (!_prefieroNoDecir && !_selecciono) {
      NotificacionServicio.alerta(
          context, 'Selecciona tu estatura o elige «Prefiero no decirlo».');
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
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        altura: Value(
            _prefieroNoDecir ? 'Prefiero no decirlo' : '${_alturaCm.round()}'),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(context, 'Estatura actualizada correctamente.');
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
    return _PlantillaPerfil(
      titulo: '¿Cuál es tu estatura?',
      subtitulo: 'Un detalle más para que te conozcan mejor.',
      cargando: _cargando,
      guardando: _guardando,
      onGuardar: _guardar,
      hijo: SliderOpcion(
        valor: _alturaCm,
        prefieroNoDecir: _prefieroNoDecir,
        min: _min,
        max: _max,
        divisions: 80,
        formatoEtiqueta: (v) => '${v.round()} cm',
        etiquetaPrefieroNoDecir: 'Prefiero no decirlo',
        onCambio: (v, pnd) {
          setState(() {
            _selecciono = true;
            _prefieroNoDecir = pnd;
            _alturaCm = v;
          });
        },
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
  static const _codigoPrefieroNoDecir = 'prefiero_no_decirlo';

  late final List<OpcionEtiqueta> _opciones;

  String _signoGuardado = '';
  DateTime? _fechaNacimiento;
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _opciones = [
      ...opcionesSigno,
      ('\ud83d\ude48 Prefiero no decirlo', _codigoPrefieroNoDecir),
    ];
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

  Future<void> _cargar() async {
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() {
      final valor = perfil?.signoZodiaco ?? '';
      _signoGuardado = _codigoSiEnLista(_opciones, valor);
      _fechaNacimiento = perfil?.fechaNacimiento;
      if (_signoGuardado.isEmpty &&
          _fechaNacimiento != null &&
          valor.isEmpty) {
        _signoGuardado = _signoSugerido(_fechaNacimiento!);
      }
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    if (_signoGuardado.isEmpty) {
      NotificacionServicio.alerta(
          context,
          'No podemos calcular tu signo. Añade tu fecha de nacimiento '
          'o elige «Prefiero no decirlo».');
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
      await widget.repositorio.guardarOCambiarPerfil(UsuariosCompanion(
        uuid: Value(perfil.uuid),
        signoZodiaco: Value(_signoGuardado),
        pendienteDeSincronizar: const Value(true),
      ));
      if (!mounted) return;
      NotificacionServicio.exito(
          context, 'Signo del zodíaco actualizado correctamente.');
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
    return _PlantillaPerfil(
      titulo: '¿Cuál es tu signo del zodíaco?',
      subtitulo: 'Un dato divertido para conectar con personas afines.',
      cargando: _cargando,
      guardando: _guardando,
      onGuardar: _guardar,
      hijo: SelectorOpciones(
        valorActual: _signoGuardado,
        opciones: _opciones,
        onSeleccion: (v) => setState(() => _signoGuardado = v),
      ),
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