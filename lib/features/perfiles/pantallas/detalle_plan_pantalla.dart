import 'package:flutter/material.dart';

import '../../../core/servicios/notificacion_servicio.dart';

class DetallePlanPantalla extends StatefulWidget {
  final String nombre;
  final String periodo;
  final String precio;
  final IconData icono;
  final String detalle;
  final bool destacado;
  final bool esGratis;

  const DetallePlanPantalla({
    super.key,
    required this.nombre,
    required this.periodo,
    required this.precio,
    required this.icono,
    required this.detalle,
    this.destacado = false,
    this.esGratis = false,
  });

  @override
  State<DetallePlanPantalla> createState() => _DetallePlanPantallaState();
}

class _DetallePlanPantallaState extends State<DetallePlanPantalla> {
  static const _periodos = [7, 30, 90];

  List<int> get _precios => switch (widget.nombre) {
        'Flumi Premium' => const [200, 500, 1300],
        'Flumi Plus' => const [100, 250, 650],
        _ => const [0, 0, 0],
      };

  int _seleccionado = 1;

  List<String> get _beneficios => switch (widget.nombre) {
        'Flumi Gratis' => const [
            '15 Me Gustas al d\u00eda',
            '10 perfiles en Cerca de ti',
            '1 Deshacer al d\u00eda',
            'Chats con tus matches',
            'Verificaci\u00f3n de cuenta',
          ],
        'Flumi Plus' => const [
            'Me Gustas ilimitados',
            'Deshacer ilimitado',
            '10 Superlikes por d\u00eda',
            '1 Boost al mes',
            '100 perfiles en Cerca de ti',
            'Ver qui\u00e9n te dio Me Gusta',
            'Ver qui\u00e9n visit\u00f3 tu perfil (20 visitas/d\u00eda)',
            'Historial de tus likes (los \u00faltimos 15)',
            'Filtros extra: En l\u00ednea y Perfiles verificados',
            'Ocultar tu edad',
          ],
        'Flumi Premium' => const [
            'Todo lo de Flumi Plus',
            'Perfiles ilimitados en Cerca de ti',
            'Superlikes ilimitados',
            'Visitas ilimitadas a tu perfil',
            'Historial de likes ilimitado',
            'Filtros avanzados (estatura, religi\u00f3n, signo...)',
            'Ocultar tu estado En l\u00ednea',
            'Ocultar tu ubicaci\u00f3n',
            'Visibilidad selectiva y filtro de mensajes',
            'Modo invisible: oculta tu perfil y tus visitas',
            'Chatea con cualquiera sin necesidad de match',
            '4 Boosts al mes',
          ],
        _ => const ['Acceso completo a Flumi'],
      };

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;
    final colorBase = widget.esGratis
        ? Colors.grey[700]!
        : widget.destacado
            ? const Color(0xFF6C63FF)
            : const Color(0xFFC9A227);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.nombre,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.esGratis
                    ? [Colors.grey[700]!, Colors.grey[500]!]
                    : widget.destacado
                        ? [const Color(0xFF6C63FF), const Color(0xFF8E7BFF)]
                        : [const Color(0xFFC9A227), const Color(0xFFE6C35C)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(widget.icono, size: 44, color: Colors.white),
                const SizedBox(height: 10),
                Text(
                  widget.nombre,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.detalle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!widget.esGratis) ...[
            const SizedBox(height: 24),
            const Text(
              'Seleccione un plan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < _periodos.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() => _seleccionado = i),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _seleccionado == i
                              ? colorBase.withValues(alpha: 0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _seleccionado == i
                                ? colorBase
                                : Colors.grey[300]!,
                            width: _seleccionado == i ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.end,
                              children: [
                                Icon(
                                  _seleccionado == i
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  size: 16,
                                  color: _seleccionado == i
                                      ? colorBase
                                      : Colors.grey[400],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_periodos[i]} d\u00edas',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _seleccionado == i
                                    ? colorBase
                                    : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_precios[i]} cup',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _seleccionado == i
                                    ? colorBase
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'Lo que incluye',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          for (final b in _beneficios)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, size: 22, color: colorBase),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(b,
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black87, height: 1.4)),
                  ),
                ],
              ),
            ),
          if (!widget.esGratis) ...[
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: () {
                  NotificacionServicio.exito(
                      context, 'Suscripci\u00f3n pr\u00f3ximamente');
                },
                style: FilledButton.styleFrom(
                  backgroundColor: primario,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Suscribirse por ${_precios[_seleccionado]} cup',
                  style:
                      const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}