import 'package:flutter/material.dart';

import '../../../core/estilos/tema.dart';
import '../../../core/servicios/suscripcion_servicio.dart';

class SuscripcionSheet extends StatelessWidget {
  final String titulo;
  final String descripcion;
  final PlanTipo planRequerido;
  final VoidCallback? onSuscribir;

  const SuscripcionSheet({
    super.key,
    required this.titulo,
    required this.descripcion,
    required this.planRequerido,
    this.onSuscribir,
  });

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: primario.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_outline, size: 28, color: primario),
          ),
          const SizedBox(height: 16),
          Text(
            titulo,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            descripcion,
            style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                  child: const Text('Quizás después',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onSuscribir?.call();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: primario,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    planRequerido == PlanTipo.premium
                        ? 'Ver Flumi Premium'
                        : 'Ver Flumi Plus',
                    style:
                        const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void mostrarBloqueoSuscripcion(
  BuildContext context, {
  required String funcionalidad,
  required PlanTipo planMinimo,
  required String descripcion,
  VoidCallback? onSuscribir,
}) {
  final titulo = 'Necesitas ${planMinimo == PlanTipo.premium ? 'Flumi Premium' : 'Flumi Plus'}';
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SuscripcionSheet(
      titulo: titulo,
      descripcion: descripcion,
      planRequerido: planMinimo,
      onSuscribir: onSuscribir,
    ),
  );
}