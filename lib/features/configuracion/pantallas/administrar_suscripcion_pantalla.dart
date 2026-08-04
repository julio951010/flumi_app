import 'package:flutter/material.dart';

import '../../../core/servicios/notificacion_servicio.dart';

class AdministrarSuscripcionPantalla extends StatefulWidget {
  const AdministrarSuscripcionPantalla({super.key});

  @override
  State<AdministrarSuscripcionPantalla> createState() =>
      _AdministrarSuscripcionPantallaState();
}

class _SuscripcionPlan {
  final String duracion;
  final String precio;
  final String? ahorro;

  const _SuscripcionPlan({
    required this.duracion,
    required this.precio,
    this.ahorro,
  });
}

class _AdministrarSuscripcionPantallaState
    extends State<AdministrarSuscripcionPantalla> {
  static const _planes = [
    _SuscripcionPlan(duracion: '1 mes', precio: '\$9.99'),
    _SuscripcionPlan(duracion: '6 meses', precio: '\$49.99', ahorro: '-17%'),
    _SuscripcionPlan(duracion: '12 meses', precio: '\$89.99', ahorro: '-25%'),
  ];

  static const _beneficios = [
    'Ver quién te gusta y quién te visitó',
    'Boosts semanales para destacar tu perfil',
    'Filtros avanzados de búsqueda',
    'Lee tu recibo de lectura en los mensajes',
  ];

  int _planSeleccionado = 0;

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Administrar suscripción',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _tarjetaPlanActual(primario),
            const SizedBox(height: 24),
            _tituloSeccion('Beneficios de tu plan'),
            const SizedBox(height: 4),
            ..._beneficios.map(
              (b) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.check_circle, color: primario, size: 22),
                title: Text(
                  b,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _tituloSeccion('Cambiar de plan'),
            const SizedBox(height: 4),
            ...List.generate(_planes.length, (i) {
              final plan = _planes[i];
              final seleccionado = i == _planSeleccionado;
              return _opcionPlan(
                primario,
                plan,
                seleccionado,
                esPlanActual: i == 0,
                onTap: () => setState(() => _planSeleccionado = i),
              );
            }),
            const SizedBox(height: 24),
            _tituloSeccion('Método de pago'),
            const SizedBox(height: 4),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Icon(Icons.credit_card_outlined,
                  color: primario.withValues(alpha: 0.7)),
              title: const Text(
                'Visa •••• 4242',
                style: TextStyle(fontSize: 15, color: Colors.black87),
              ),
              trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
              onTap: () => NotificacionServicio.advertencia(
                context,
                'Editar método de pago próximamente.',
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _tituloSeccion('Historial de facturación'),
            const SizedBox(height: 4),
            _cobro(primario, 'Flumi Plus · 1 mes', '04/07/2026', '\$9.99'),
            _cobro(primario, 'Flumi Plus · 1 mes', '04/06/2026', '\$9.99'),
            _cobro(primario, 'Flumi Plus · 1 mes', '04/05/2026', '\$9.99'),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmarCancelar(context),
                icon: const Icon(Icons.cancel_outlined, size: 20),
                label: const Text(
                  'Cancelar suscripción',
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[400],
                  side: BorderSide(color: Colors.red[400]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaPlanActual(Color primario) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primario.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primario.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primario,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Plan actual',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Flumi Plus',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '\$9.99 / mes',
            style: TextStyle(fontSize: 16, color: primario),
          ),
          const SizedBox(height: 12),
          const Text(
            'Renovación el 04/09/2026',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _tituloSeccion(String titulo) {
    return Text(
      titulo,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _opcionPlan(
    Color primario,
    _SuscripcionPlan plan,
    bool seleccionado, {
    required bool esPlanActual,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Row(
          children: [
            Icon(
              seleccionado ? Icons.radio_button_checked : Icons.radio_button_off,
              color: seleccionado ? primario : Colors.grey[400],
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    plan.duracion,
                    style: const TextStyle(
                        fontSize: 15, color: Colors.black87),
                  ),
                  if (esPlanActual)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        'Plan actual',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: primario,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              plan.precio,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 6),
            if (plan.ahorro != null)
              Text(
                plan.ahorro!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[700],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cobro(Color primario, String concepto, String fecha, String monto) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(Icons.receipt_long_outlined,
          color: primario.withValues(alpha: 0.7)),
      title: Text(
        concepto,
        style: const TextStyle(fontSize: 14, color: Colors.black87),
      ),
      subtitle: Text(
        fecha,
        style: const TextStyle(fontSize: 12, color: Colors.black54),
      ),
      trailing: Text(
        monto,
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
      ),
    );
  }

  Future<void> _confirmarCancelar(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar suscripción'),
        content: const Text(
          'Perderás el acceso a los beneficios de Flumi Plus al finalizar el periodo actual. ¿Quieres continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Cancelar suscripción',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmado != true || !context.mounted) return;
    NotificacionServicio.exito(
        context, 'Suscripción cancelada. Se mantiene hasta el 04/09/2026.');
  }
}