import 'package:flutter/material.dart';
import '../../../../core/estilos/tema.dart';

typedef TarjetaOpcionTap = VoidCallback;

class TarjetaOpcionCheck extends StatelessWidget {
  final String etiqueta;
  final bool seleccionada;
  final TarjetaOpcionTap onTap;
  final bool deshabilitada;

  const TarjetaOpcionCheck({
    super.key,
    required this.etiqueta,
    required this.seleccionada,
    required this.onTap,
    this.deshabilitada = false,
  });

  @override
  Widget build(BuildContext context) {
    const primario = FlumiTema.colorPrimario;

    return InkWell(
      onTap: deshabilitada ? null : onTap,
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
            color: seleccionada ? primario : primario.withValues(alpha: 0.3),
            width: seleccionada ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                etiqueta,
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

class RejillaCardsOpciones extends StatelessWidget {
  final List<Widget> tarjetas;

  const RejillaCardsOpciones({super.key, required this.tarjetas});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final anchoTarjeta = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final tarjeta in tarjetas)
              SizedBox(width: anchoTarjeta, child: tarjeta),
          ],
        );
      },
    );
  }
}