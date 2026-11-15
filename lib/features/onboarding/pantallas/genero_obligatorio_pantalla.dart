import 'package:flutter/material.dart';

import '../../configuracion/pantallas/informacion_basica_pantalla.dart';
import '../../perfiles/perfil_repositorio.dart';

/// Pantalla de bloqueo para perfiles sin género.
///
/// El género es obligatorio porque de él depende la reciprocidad del feed: un
/// perfil sin género no puede aparecerle a nadie que tenga una preferencia
/// concreta (por ejemplo, "Mujeres"), aunque esa persona sí vea a todo el
/// mundo. Antes se podía llegar al feed con el género vacío y el perfil se
/// volvía invisible sin que el usuario lo supiera.
///
/// No implementa el formulario: reutiliza [ActualizarGeneroPantalla], que ya
/// tiene las opciones y la validación. Mientras el género siga vacío, esta
/// pantalla vuelve a aparecer.
class GeneroObligatorioPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;

  /// Se llama cuando el perfil ya tiene género (o el usuario decide seguir;
  /// la condición se revalida al volver a entrar).
  final VoidCallback onListo;

  const GeneroObligatorioPantalla({
    super.key,
    required this.repositorio,
    required this.onListo,
  });

  @override
  State<GeneroObligatorioPantalla> createState() =>
      _GeneroObligatorioPantallaState();
}

class _GeneroObligatorioPantallaState extends State<GeneroObligatorioPantalla> {
  bool _verificando = false;

  Future<void> _elegir() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ActualizarGeneroPantalla(repositorio: widget.repositorio),
      ),
    );
    await _comprobar();
  }

  Future<void> _comprobar() async {
    if (!mounted) return;
    setState(() => _verificando = true);
    final perfil = await widget.repositorio.obtenerPerfilPropio();
    if (!mounted) return;
    setState(() => _verificando = false);
    if ((perfil?.genero ?? '').trim().isNotEmpty) {
      widget.onListo();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: primario.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.wc_rounded, size: 48, color: primario),
              ),
              const SizedBox(height: 24),
              const Text(
                'Falta un dato para empezar',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Necesitamos saber cómo te identificas. Sin ese dato tu perfil '
                'no aparece en el feed de las personas que buscan un género '
                'concreto, y no podrías recibir matches.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _verificando ? null : _elegir,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primario,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _verificando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Elegir mi género',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
