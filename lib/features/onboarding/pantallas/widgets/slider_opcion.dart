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
  bool _selecciono = false;

  @override
  void initState() {
    super.initState();
    _valorActual = widget.valor;
    _prefieroNoDecirActual = widget.prefieroNoDecir;
  }

  Widget _tarjetaPrefieroNoDecir(Color primario) {
    final seleccionada = _prefieroNoDecirActual;
    return InkWell(
      onTap: () => setState(() {
        _prefieroNoDecirActual = !_prefieroNoDecirActual;
        if (_prefieroNoDecirActual) {
          _selecciono = false;
        }
        widget.onCambio(_valorActual, _prefieroNoDecirActual);
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
                '\ud83d\ude48 ${widget.etiquetaPrefieroNoDecir}',
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

  @override
  Widget build(BuildContext context) {
    const primario = FlumiTema.colorPrimario;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: primario.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primario.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                if (_prefieroNoDecirActual)
                  Text(
                    '\ud83d\ude48 Prefiero no decirlo',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600]),
                  )
                else if (_selecciono)
                  Text(
                    widget.formatoEtiqueta(_valorActual),
                    style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                        color: primario),
                  )
                else
                  Text(
                    'Elige tu estatura',
                    style: TextStyle(
                        fontSize: 22, color: Colors.grey[500]),
                  ),
                const SizedBox(height: 4),
                Slider(
                  value: _prefieroNoDecirActual ? widget.min : _valorActual,
                  min: widget.min,
                  max: widget.max,
                  divisions: widget.divisions,
                  activeColor: primario,
                  inactiveColor: primario.withValues(alpha: 0.2),
                  label: widget.formatoEtiqueta(_valorActual),
                  onChanged: _prefieroNoDecirActual
                      ? null
                      : (v) => setState(() {
                            _valorActual = v;
                            _selecciono = true;
                            widget.onCambio(v, false);
                          }),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${widget.min.round()} cm',
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 12),
                      ),
                      Text(
                        '${widget.max.round()} cm',
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _tarjetaPrefieroNoDecir(primario),
        ],
      ),
    );
  }
}