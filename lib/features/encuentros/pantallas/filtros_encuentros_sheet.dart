import 'package:flutter/material.dart';
import '../../../core/estilos/tema.dart';

enum _FiltroEnum { genero, edad, distancia, masOpciones }

class FiltrosEncuentros {
  String generoFiltro;
  RangeValues edadRango;
  double distanciaKm;
  bool enLineaAhora;
  bool masOpcionesExpandido;

  FiltrosEncuentros({
    this.generoFiltro = '',
    this.edadRango = const RangeValues(18, 60),
    this.distanciaKm = 50,
    this.enLineaAhora = false,
    this.masOpcionesExpandido = false,
  });

  FiltrosEncuentros copy() => FiltrosEncuentros(
    generoFiltro: generoFiltro,
    edadRango: edadRango,
    distanciaKm: distanciaKm,
    enLineaAhora: enLineaAhora,
  );
}

Future<FiltrosEncuentros?> mostrarFiltrosEncuentros(
  BuildContext context, {
  required FiltrosEncuentros actuales,
}) {
  return showModalBottomSheet<FiltrosEncuentros>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _FiltrosEncuentrosSheet(actuales: actuales),
  );
}

class _FiltrosEncuentrosSheet extends StatefulWidget {
  final FiltrosEncuentros actuales;
  const _FiltrosEncuentrosSheet({required this.actuales});

  @override
  State<_FiltrosEncuentrosSheet> createState() => _FiltrosEncuentrosSheetState();
}

class _FiltrosEncuentrosSheetState extends State<_FiltrosEncuentrosSheet> {
  late String _genero;
  late RangeValues _edad;
  late double _distancia;
  late bool _enLinea;
  _FiltroEnum? _expandido;

  static const _opcionesGenero = ['Mujeres', 'Hombres', 'Todos'];

  @override
  void initState() {
    super.initState();
    _genero = widget.actuales.generoFiltro;
    _edad = widget.actuales.edadRango;
    _distancia = widget.actuales.distanciaKm;
    _enLinea = widget.actuales.enLineaAhora;
  }

  void _aplicar() {
    Navigator.pop(context, FiltrosEncuentros(
      generoFiltro: _genero,
      edadRango: _edad,
      distanciaKm: _distancia,
      enLineaAhora: _enLinea,
    ));
  }

  String get _textoGenero {
    if (_genero.isEmpty) return 'Todos';
    return _genero;
  }

  String get _textoEdad => '${_edad.start.toInt()} - ${_edad.end.toInt()}';

  String get _textoDistancia => '${_distancia.toInt()} km';

  @override
  Widget build(BuildContext context) {
    const primario = FlumiTema.colorPrimario;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _barraArrastre(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filtros', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  _filaFiltro('Mostrar', _textoGenero, _FiltroEnum.genero, primario),
                  _panelGenero(primario),
                  const Divider(height: 1),
                  _filaFiltro('Edad', _textoEdad, _FiltroEnum.edad, primario),
                  _panelEdad(primario),
                  const Divider(height: 1),
                  _filaFiltro('Distancia', _textoDistancia, _FiltroEnum.distancia, primario),
                  _panelDistancia(primario),
                  const Divider(height: 1),
                  _filaEnLinea(primario),
                  const Divider(height: 1),
                  _filaMasOpciones(primario),
                ],
              ),
            ),
          ),
          _botonAplicar(primario),
        ],
      ),
    );
  }

  Widget _barraArrastre() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Center(
        child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
      ),
    );
  }

  Widget _filaFiltro(String label, String valor, _FiltroEnum tipo, Color primario) {
    final abierto = _expandido == tipo;
    return InkWell(
      onTap: () => setState(() => _expandido = abierto ? null : tipo),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 16, color: Colors.black87)),
            const Spacer(),
            Text(valor, style: TextStyle(fontSize: 16, color: Colors.grey[500])),
            const SizedBox(width: 6),
            Icon(abierto ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey[400], size: 22),
          ],
        ),
      ),
    );
  }

  Widget _panelGenero(Color primario) {
    if (_expandido != _FiltroEnum.genero) return const SizedBox.shrink();
    final fondoClaro = primario.withValues(alpha: 0.08);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _opcionesGenero.map((o) {
          final selected = _genero == o || (_genero.isEmpty && o == 'Todos');
          return GestureDetector(
            onTap: () => setState(() => _genero = o == 'Todos' ? '' : o),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? primario : fondoClaro,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? primario : Colors.grey[300]!),
              ),
              child: Text(o, style: TextStyle(fontSize: 14, color: selected ? Colors.white : Colors.grey[700])),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _panelEdad(Color primario) {
    if (_expandido != _FiltroEnum.edad) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: RangeSlider(
        values: _edad, min: 18, max: 80, divisions: 62,
        activeColor: primario,
        inactiveColor: primario.withValues(alpha: 0.2),
        labels: RangeLabels('${_edad.start.toInt()}', '${_edad.end.toInt()}'),
        onChanged: (v) => setState(() => _edad = v),
      ),
    );
  }

  Widget _panelDistancia(Color primario) {
    if (_expandido != _FiltroEnum.distancia) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Slider(
        value: _distancia, min: 1, max: 200, divisions: 199,
        activeColor: primario,
        inactiveColor: primario.withValues(alpha: 0.2),
        label: '${_distancia.toInt()} km',
        onChanged: (v) => setState(() => _distancia = v),
      ),
    );
  }

  Widget _filaEnLinea(Color primario) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Text('En línea ahora', style: TextStyle(fontSize: 16, color: Colors.black87)),
          const Spacer(),
          Switch(
            value: _enLinea,
            activeTrackColor: primario,
            onChanged: (v) => setState(() => _enLinea = v),
          ),
        ],
      ),
    );
  }

  Widget _filaMasOpciones(Color primario) {
    final abierto = _expandido == _FiltroEnum.masOpciones;
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expandido = abierto ? null : _FiltroEnum.masOpciones),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                const Text('Más opciones', style: TextStyle(fontSize: 16, color: Colors.black87)),
                const Spacer(),
                const SizedBox(width: 6),
                Icon(abierto ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey[400], size: 22),
              ],
            ),
          ),
        ),
        if (abierto)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primario.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Más opciones próximamente...', style: TextStyle(color: Colors.grey)),
            ),
          ),
      ],
    );
  }

  Widget _botonAplicar(Color primario) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton(
            onPressed: _aplicar,
            style: ElevatedButton.styleFrom(
              backgroundColor: primario, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text('Aplicar filtros', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}
