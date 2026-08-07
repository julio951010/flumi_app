import 'package:flutter/material.dart';
import '../../../../core/estilos/tema.dart';

typedef SliderCallback = void Function(double valor, bool prefieroNoDecir);

class SliderOpcion extends StatefulWidget {
  final double valor;
  final bool prefieroNoDecir;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) formatoEtiqueta;
  final String etiquetaPrefieroNoDecir;
  final SliderCallback onCambio;

  const SliderOpcion({
    super.key,
    required this.valor,
    required this.prefieroNoDecir,
    required this.min,
    required this.max,
    required this.divisions,
    required this.formatoEtiqueta,
    required this.etiquetaPrefieroNoDecir,
    required this.onCambio,
  });

  @override
  State<SliderOpcion> createState() => _SliderOpcionState();
}

class _SliderOpcionState extends State<SliderOpcion> {
  late double _valorActual;
  late bool _prefieroNoDecirActual;

  @override
  void initState() {
    super.initState();
    _valorActual = widget.valor;
    _prefieroNoDecirActual = widget.prefieroNoDecir;
  }

  @override
  Widget build(BuildContext context) {
    const primario = FlumiTema.colorPrimario;

    return Column(
      children: [
        const Spacer(),
        Text(
          _prefieroNoDecirActual
              ? 'Prefiero no decirlo'
              : widget.formatoEtiqueta(_valorActual),
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: primario),
        ),
        const SizedBox(height: 24),
        Slider(
          value: _prefieroNoDecirActual ? widget.min : _valorActual,
          min: widget.min,
          max: widget.max,
          divisions: widget.divisions,
          activeColor: primario,
          inactiveColor: primario.withValues(alpha: 0.2),
          onChanged: (v) {
            setState(() {
              _valorActual = v;
              _prefieroNoDecirActual = false;
              widget.onCambio(v, false);
            });
          },
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _prefieroNoDecirActual = !_prefieroNoDecirActual;
              widget.onCambio(_valorActual, _prefieroNoDecirActual);
            });
          },
          icon: Icon(
            _prefieroNoDecirActual ? Icons.check_box : Icons.check_box_outline_blank,
            size: 20,
            color: primario,
          ),
          label: Text(
            widget.etiquetaPrefieroNoDecir,
            style: TextStyle(fontSize: 14, color: primario),
          ),
        ),
        const Spacer(),
      ],
    );
  }
}