import 'package:flutter/material.dart';

import '../../configuracion/pantallas/informacion_basica_pantalla.dart';
import '../../perfiles/perfil_repositorio.dart';

/// Pantalla de bloqueo para perfiles sin ubicación real.
///
/// Sin coordenadas el perfil cae en (0,0) (Golfo de Guinea): a miles de km
/// de cualquier usuario, así que no aparece en el feed de nadie y, peor, el
/// propio usuario tampoco recibe feed (el sincronizado se salta cuando no hay
/// ubicación). Antes se podía completar el onboarding escribiendo solo el
/// nombre de la ciudad, dejando lat/lon en 0.
///
/// No implementa el formulario: reutiliza [ActualizarUbicacionPantalla], que
/// ya tiene GPS, autocompletado y validación. Mientras la ubicación siga en
/// (0,0), esta pantalla vuelve a aparecer.
class UbicacionObligatoriaPantalla extends StatefulWidget {
  final PerfilRepositorio repositorio;

  final VoidCallback onListo;

  const UbicacionObligatoriaPantalla({
    super.key,
    required this.repositorio,
    required this.onListo,
  });

  @override
  State<UbicacionObligatoriaPantalla> createState() =>
      _UbicacionObligatoriaPantallaState();
}

class _UbicacionObligatoriaPantallaState
    extends State<UbicacionObligatoriaPantalla> {
  bool _verificando = false;

  Future<void> _elegir() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ActualizarUbicacionPantalla(repositorio: widget.repositorio),
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
    final lat = perfil?.ubicacionLat ?? 0;
    final lon = perfil?.ubicacionLon ?? 0;
    if (lat != 0 || lon != 0) {
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
                child: Icon(Icons.location_on_rounded, size: 48, color: primario),
              ),
              const SizedBox(height: 24),
              const Text(
                'Falta tu ubicación',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Flumi es una app de citas cercanas: sin ubicación real tu '
                'perfil no aparece en el feed de nadie y tú tampoco recibes '
                'perfiles. Indica tu ciudad o usa el GPS para continuar.',
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
                          'Elegir mi ubicación',
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
