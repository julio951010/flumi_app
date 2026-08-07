import 'package:flutter/material.dart';
import '../../../../core/estilos/tema.dart';

const _codigoPrefieroNoDecir = 'prefiero_no_decirlo';

const _signos = <(String, String, String)>[
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

typedef SignoCallback = void Function(String codigo);

class SignoZodiacalOpcion extends StatefulWidget {
  final DateTime? fechaNacimiento;
  final String valorActual;
  final SignoCallback onCambio;

  const SignoZodiacalOpcion({
    super.key,
    required this.fechaNacimiento,
    required this.valorActual,
    required this.onCambio,
  });

  @override
  State<SignoZodiacalOpcion> createState() => _SignoZodiacalOpcionState();
}

class _SignoZodiacalOpcionState extends State<SignoZodiacalOpcion> {
  late bool _prefieroNoDecir;

  @override
  void initState() {
    super.initState();
    _prefieroNoDecir = widget.valorActual == _codigoPrefieroNoDecir;
  }

  @override
  void didUpdateWidget(covariant SignoZodiacalOpcion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.valorActual != widget.valorActual) {
      _prefieroNoDecir = widget.valorActual == _codigoPrefieroNoDecir;
    }
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
    if (_prefieroNoDecir) return null;
    final guardado = _esValido(widget.valorActual)
        ? widget.valorActual
        : null;
    final codigo = guardado ??
        (widget.fechaNacimiento != null
            ? _signoSugerido(widget.fechaNacimiento!)
            : null);
    if (codigo == null) return null;
    for (final s in _signos) {
      if (s.$3 == codigo) return s;
    }
    return null;
  }

  bool _esValido(String codigo) {
    return _signos.any((s) => s.$3 == codigo);
  }

  void _togglePrefieroNoDecir() {
    setState(() {
      _prefieroNoDecir = !_prefieroNoDecir;
      if (_prefieroNoDecir) {
        widget.onCambio(_codigoPrefieroNoDecir);
      } else {
        final signo = _signoVisible();
        widget.onCambio(signo?.$3 ?? '');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const primario = FlumiTema.colorPrimario;
    final signo = _signoVisible();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (signo != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primario.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primario.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    signo.$1,
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: primario),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    signo.$2,
                    style: TextStyle(
                        fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (widget.fechaNacimiento != null)
              Text(
                'Calculado con tu fecha de nacimiento',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            const SizedBox(height: 16),
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
                style:
                    TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),
          ],
          _tarjetaPrefieroNoDecir(primario),
        ],
      ),
    );
  }

  Widget _tarjetaPrefieroNoDecir(Color primario) {
    final seleccionada = _prefieroNoDecir;
    return InkWell(
      onTap: _togglePrefieroNoDecir,
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
                  fontWeight: seleccionada
                      ? FontWeight.w600
                      : FontWeight.w500,
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