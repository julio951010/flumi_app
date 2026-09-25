import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/env.dart';
import '../../../core/servicios/notificacion_servicio.dart';
import '../../../core/servicios/suscripcion_servicio.dart';
import '../../perfiles/pantallas/detalle_plan_pantalla.dart';
import 'historial_pagos_pantalla.dart';

class AdministrarSuscripcionPantalla extends StatefulWidget {
  final SuscripcionServicio suscripcionServicio;

  const AdministrarSuscripcionPantalla({
    super.key,
    required this.suscripcionServicio,
  });

  @override
  State<AdministrarSuscripcionPantalla> createState() =>
      _AdministrarSuscripcionPantallaState();
}

class _AdministrarSuscripcionPantallaState
    extends State<AdministrarSuscripcionPantalla> {
  bool _cancelando = false;
  bool _tienePagoPendiente = false;

  SuscripcionServicio get _sub => widget.suscripcionServicio;

  @override
  void initState() {
    super.initState();
    _cargarEstadoPendiente();
  }

  /// ¿Hay un pago en verificación? Define el badge "Inactivo".
  Future<void> _cargarEstadoPendiente() async {
    try {
      if (kUsarServidorLocal) return;
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final res = await Supabase.instance.client
          .from('pagos')
          .select('id')
          .eq('usuario_id', uid)
          .eq('estado', 'pendiente')
          .limit(1)
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() => _tienePagoPendiente = (res as List).isNotEmpty);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;
    final plan = _sub.planActual;

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
        child: ListenableBuilder(
          listenable: _sub,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _tarjetaPlanActual(primario, plan),
              const SizedBox(height: 24),
              _tituloSeccion('Beneficios de tu plan'),
              const SizedBox(height: 4),
              ..._beneficios(plan).map(
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
              if (plan != PlanTipo.plus)
                _opcionPlan(
                  primario,
                  nombre: 'Flumi Plus',
                  detalle: 'Desde 100 CUP · 7 días',
                  onTap: () => _verPlan(
                    nombre: 'Flumi Plus',
                    periodo: 'mensual',
                    precio: '250 cup',
                    icono: Icons.auto_awesome,
                    detalle: 'Funciones extra',
                    destacado: true,
                  ),
                ),
              if (plan != PlanTipo.premium)
                _opcionPlan(
                  primario,
                  nombre: 'Flumi Premium',
                  detalle: 'Desde 200 CUP · 7 días',
                  onTap: () => _verPlan(
                    nombre: 'Flumi Premium',
                    periodo: 'mensual',
                    precio: '500 cup',
                    icono: Icons.workspace_premium,
                    detalle: 'Acceso total',
                    destacado: false,
                  ),
                ),
              const SizedBox(height: 24),
              _tituloSeccion('Pagos'),
              const SizedBox(height: 4),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Icon(Icons.receipt_long_outlined,
                    color: primario.withValues(alpha: 0.7)),
                title: const Text(
                  'Historial de pagos',
                  style: TextStyle(fontSize: 15, color: Colors.black87),
                ),
                trailing:
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HistorialPagosPantalla(),
                  ),
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 28),
              if (plan == PlanTipo.plus || plan == PlanTipo.premium)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                        _cancelando ? null : () => _confirmarCancelar(context),
                    icon: _cancelando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.cancel_outlined, size: 20),
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
      ),
    );
  }

  void _verPlan({
    required String nombre,
    required String periodo,
    required String precio,
    required IconData icono,
    required String detalle,
    required bool destacado,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetallePlanPantalla(
          nombre: nombre,
          periodo: periodo,
          precio: precio,
          icono: icono,
          detalle: detalle,
          destacado: destacado,
        ),
      ),
    );
  }

  List<String> _beneficios(PlanTipo plan) {
    switch (plan) {
      case PlanTipo.premium:
        return const [
          'Todo lo de Flumi Plus',
          'Perfiles ilimitados en Cerca de ti',
          'Superlikes ilimitados',
          'Chatea sin necesidad de match',
          'Modo invisible y filtros avanzados',
        ];
      case PlanTipo.plus:
        return const [
          'Me Gustas ilimitados',
          'Deshacer ilimitado',
          '10 Superlikes por día',
          '100 perfiles en Cerca de ti',
          'Ver quién te dio Me Gusta y te visitó',
        ];
      case PlanTipo.gratis:
        return const [
          '15 Me Gustas al día',
          '10 perfiles en Cerca de ti',
          '1 Deshacer al día',
          'Chats con tus matches',
        ];
    }
  }

  Widget _tarjetaPlanActual(Color primario, PlanTipo plan) {
    final sub = _sub.suscripcionActual;
    final nombre = switch (plan) {
      PlanTipo.premium => 'Flumi Premium',
      PlanTipo.plus => 'Flumi Plus',
      PlanTipo.gratis => 'Flumi Gratis',
    };
    final esGratis = plan == PlanTipo.gratis;
    final vence = sub?.vence;
    final tieneSubActiva = (sub?.activa ?? false) &&
        (vence == null || vence.isAfter(DateTime.now()));
    // Prioridad: si el plan está activo para el usuario, manda Activo aunque
    // haya otro pago nuevo en verificación. Inactivo solo cuando NO hay plan
    // activo pero sí un pago pendiente. Sin fila (admin/kill-switch con plan
    // efectivo) también es Activo; con fila vencida/inactiva es Vencido.
    final String badgeTexto;
    final Color badgeColor;
    if (esGratis) {
      badgeTexto = 'Gratis';
      badgeColor = Colors.grey;
    } else if (tieneSubActiva) {
      badgeTexto = 'Activo';
      badgeColor = const Color(0xFF2E7D32);
    } else if (_tienePagoPendiente) {
      badgeTexto = 'Inactivo';
      badgeColor = const Color(0xFFEF6C00);
    } else if (sub == null) {
      badgeTexto = 'Activo';
      badgeColor = const Color(0xFF2E7D32);
    } else {
      badgeTexto = 'Vencido';
      badgeColor = Colors.red;
    }
    final tiempoRestante = esGratis
        ? 'Sin suscripción activa'
        : (vence == null
            ? 'Sin fecha de vencimiento'
            : _textoRestante(vence));
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
              Expanded(
                child: Text(
                  nombre,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeTexto,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  tiempoRestante,
                  style:
                      TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ),
            ],
          ),
          if (_sub.tieneReservaVigente) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.layers_outlined,
                    size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _textoReserva(),
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ],
          if (!esGratis) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _extenderPlan(plan),
                icon: const Icon(Icons.add_circle_outline, size: 20),
                label: const Text(
                  'Extender plan',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: primario,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _textoReserva() {
    final nombre = _sub.planReserva == 'premium' ? 'Flumi Premium' : 'Flumi Plus';
    final dias = _sub.diasReservaRestantes;
    if (dias == null) return 'Al vencer, continúa $nombre';
    return 'Al vencer, continúa $nombre ($dias ${dias == 1 ? 'día' : 'días'})';
  }

  String _textoRestante(DateTime vence) {
    final ahora = DateTime.now();
    if (!vence.isAfter(ahora)) {
      final dias = ahora.difference(vence).inDays;
      if (dias <= 0) return 'Vence hoy';
      return dias == 1 ? 'Vencido hace 1 día' : 'Vencido hace $dias días';
    }
    final diff = vence.difference(ahora);
    if (diff.inDays >= 1) {
      return diff.inDays == 1 ? 'Queda 1 día' : 'Quedan ${diff.inDays} días';
    }
    if (diff.inHours >= 1) {
      return diff.inHours == 1 ? 'Queda 1 hora' : 'Quedan ${diff.inHours} horas';
    }
    return 'Vence hoy';
  }

  void _extenderPlan(PlanTipo plan) {
    if (plan == PlanTipo.premium) {
      _verPlan(
        nombre: 'Flumi Premium',
        periodo: 'mensual',
        precio: '500 cup',
        icono: Icons.workspace_premium,
        detalle: 'Acceso total',
        destacado: false,
      );
    } else {
      _verPlan(
        nombre: 'Flumi Plus',
        periodo: 'mensual',
        precio: '250 cup',
        icono: Icons.auto_awesome,
        detalle: 'Funciones extra',
        destacado: true,
      );
    }
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
    Color primario, {
    required String nombre,
    required String detalle,
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
              Icons.circle_outlined,
              color: Colors.grey[400],
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: const TextStyle(
                        fontSize: 15, color: Colors.black87),
                  ),
                  Text(
                    detalle,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarCancelar(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar suscripción'),
        content: const Text(
          'Volverás al plan Gratis. Podrás suscribirte de nuevo cuando quieras. ¿Quieres continuar?',
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
    setState(() => _cancelando = true);
    try {
      if (!kUsarServidorLocal) {
        final res = await Supabase.instance.client
            .rpc('cancelar_suscripcion')
            .timeout(const Duration(seconds: 8));
        if (res is Map && res['ok'] != true) throw res['error'] ?? 'Error';
      }
      await _sub.cargarSuscripcion();
      if (context.mounted) {
        NotificacionServicio.exito(
            context, 'Suscripción cancelada. Ahora usas Flumi Gratis.');
      }
    } catch (_) {
      if (context.mounted) {
        NotificacionServicio.alerta(
            context, 'No se pudo cancelar. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _cancelando = false);
    }
  }
}
