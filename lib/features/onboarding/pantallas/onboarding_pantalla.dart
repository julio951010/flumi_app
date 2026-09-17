import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/estilos/tema.dart';
import '../../../widgets_comunes/animacion_agua.dart';
import '../onboarding_servicio.dart';

class OnboardingPantalla extends StatelessWidget {
  final VoidCallback onCompletado;

  const OnboardingPantalla({super.key, required this.onCompletado});

  Future<void> _completar() async {
    await OnboardingServicio.marcarCompletado();
    onCompletado();
  }

  @override
  Widget build(BuildContext context) {
    final altura = MediaQuery.of(context).size.height;
    // Mismo juego de olas del splash: fondo blanco arriba (logo,
    // fuera del agua) y agua abajo (texto + botón dentro del agua).
    final alturaAgua = altura * 0.75;
    final ladoLogo = (altura * 0.27).clamp(190.0, 250.0);
    return Stack(
      children: [
        Container(color: Colors.white),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: alturaAgua,
          child: const AnimacionAgua(),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: alturaAgua * 0.85,
          child: const AnimacionAgua(color: Color(0xFF1FA0F0)),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: alturaAgua * 0.7,
          child: const AnimacionAgua(color: Color(0xFF30B0FF)),
        ),
        Positioned(
          top: altura * 0.06,
          left: 0,
          right: 0,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SvgPicture.asset(
                'assets/onboarding/flumi_logo.svg',
                width: ladoLogo,
                height: ladoLogo,
                placeholderBuilder: (context) => Icon(
                  Icons.photo_size_select_large,
                  size: 200,
                  color: FlumiTema.colorPrimario.withValues(alpha: 0.15),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 32,
          right: 32,
          bottom: 180,
          child: Column(
            children: [
              Text(
                'Bienvenido a Flumi',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Descubre gente real cerca de ti\ny deja que todo fluya.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ElevatedButton(
              onPressed: _completar,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: FlumiTema.colorPrimario,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Empezar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
