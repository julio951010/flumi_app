import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/env.dart';
import '../../../core/estilos/tema.dart';
import '../../../core/servicios/notificacion_servicio.dart';
import '../../../core/servicios/sms_verificacion_servicio.dart';
import '../modelos/pago_datos.dart';
import 'pago_confirmacion_pantalla.dart';

class PagoComprobantePantalla extends StatefulWidget {
  final PagoDatos datos;
  const PagoComprobantePantalla({super.key, required this.datos});

  @override
  State<PagoComprobantePantalla> createState() => _PagoComprobantePantallaState();
}

class _PagoComprobantePantallaState extends State<PagoComprobantePantalla> {
  final _ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _verificando = false;

  @override
  void initState() {
    super.initState();
    // Inicia escucha SMS (Android) sin bloquear UI; no autorrellena.
    SmsVerificacionServicio.instancia.iniciar();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _esTransfermovil => widget.datos.metodo == MetodoPago.transfermovil;
  bool get _valido {
    final s = _ctrl.text.trim().replaceAll(' ', '');
    if (_esTransfermovil) return RegExp(r'^[A-Za-z0-9]{13}$').hasMatch(s);
    return RegExp(r'^[A-Za-z0-9]{12}$').hasMatch(s);
  }

  Future<void> _verificar() async {
    if (!_formKey.currentState!.validate()) return;
    if (kUsarServidorLocal) {
      widget.datos.idTransaccion = _ctrl.text.trim().replaceAll(' ', '').toUpperCase();
      if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => PagoConfirmacionPantalla(datos: widget.datos)));
      return;
    }
    setState(() => _verificando = true);
    try {
      final nro = _ctrl.text.trim().replaceAll(' ', '').toUpperCase();
      // Prueba SMS: si hay un SMS reciente de PAGOxMOVIL/ENZONA, lo enviamos como
      // prueba para auto-aprobación. El usuario sigue escribiendo manualmente;
      // el servidor compara Nro + remitente + monto y auto-aprueba si todo coincide.
      final sms = SmsVerificacionServicio.instancia.ultimo;
      final smsValido = sms != null && DateTime.now().difference(sms.timestamp) < const Duration(minutes: 15);
      final params = {
        'p_metodo': widget.datos.metodo == MetodoPago.transfermovil ? 'transfermovil' : 'enzona',
        'p_plan': widget.datos.nombrePlan,
        'p_dias': widget.datos.dias,
        'p_nro': nro,
        if (smsValido) 'p_sms_nro': sms.nro,
        if (smsValido) 'p_sms_remitente': sms.remitente,
        if (smsValido && sms.monto != null) 'p_sms_monto': sms.monto,
        if (smsValido && sms.fechaSms != null) 'p_sms_fecha': sms.fechaSms!.toIso8601String().substring(0, 10),
        if (smsValido && sms.beneficiario != null) 'p_sms_beneficiario': sms.beneficiario,
      };
      final res = await Supabase.instance.client.rpc('solicitar_pago', params: params).timeout(const Duration(seconds: 10));
      final ok = res is Map && res['ok'] == true;
      if (!mounted) return;
      if (!ok) {
        final err = (res is Map ? res['error'] : null)?.toString() ?? 'Error';
        String msg;
        switch (err) {
          case 'nro_duplicado':
            msg = 'Este Nro. ya fue usado. Verifica el comprobante.';
            break;
          case 'nro_formato_transfermovil':
            msg = 'El Nro. de Transfermóvil debe tener 13 letras/números.';
            break;
          case 'nro_formato_enzona':
            msg = 'El Nro. de EnZona debe tener 12 letras/números.';
            break;
          case 'rate_limit':
            msg = 'Has enviado varios pagos pendientes. Espera a que se verifiquen.';
            break;
          default:
            msg = 'No se pudo registrar el pago. Intenta de nuevo.';
        }
        setState(() => _verificando = false);
        NotificacionServicio.alerta(context, msg);
        return;
      }
      final autoAprobado = res is Map<String, dynamic> && res['auto_aprobado'] == true;
      setState(() => _verificando = false);
      widget.datos.idTransaccion = nro;
      widget.datos.autoAprobado = autoAprobado;
      if (autoAprobado) {
        SmsVerificacionServicio.instancia.limpiar();
        if (mounted) NotificacionServicio.exito(context, 'Pago verificado automáticamente. ¡Plan activado!');
      }
      if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => PagoConfirmacionPantalla(datos: widget.datos)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _verificando = false);
      NotificacionServicio.alerta(context, 'Error de conexión. Intenta de nuevo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Comprobante', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Column(
        children: [
          _progreso(4, 5),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFF1F8E9), borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_outlined, color: Color(0xFF2E7D32)),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Introduce el Nro. Transacción que te dio ${widget.datos.metodo?.nombre ?? 'la app de pago'}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _ctrl,
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')), LengthLimitingTextInputFormatter(_esTransfermovil ? 13 : 12)],
                    decoration: InputDecoration(
                      hintText: 'Nro. Transacción',
                      prefixIcon: const Icon(Icons.receipt_long_outlined),
                      suffixIcon: _ctrl.text.isNotEmpty
                          ? IconButton(onPressed: () => setState(() => _ctrl.clear()), icon: const Icon(Icons.clear, size: 18))
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final s = (v ?? '').trim().replaceAll(' ', '');
                      if (s.isEmpty) return 'Ingresa el Nro.';
                      if (_esTransfermovil) {
                        if (!RegExp(r'^[A-Za-z0-9]{13}$').hasMatch(s)) return 'Debe tener 13 letras/números';
                      } else {
                        if (!RegExp(r'^[A-Za-z0-9]{12}$').hasMatch(s)) return 'Debe tener 12 letras/números';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [Icon(Icons.help_outline, size: 16, color: Colors.grey[600]), const SizedBox(width: 6), Text('¿Dónde está?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey[800]))]),
                      const SizedBox(height: 6),
                      RichText(
                        text: TextSpan(
                          style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4),
                          children: [
                            const TextSpan(text: 'El número de transacción está en el mensaje de confirmación enviado por '),
                            TextSpan(
                              text: _esTransfermovil ? 'PAGOxMOVIL' : 'ENZONA',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800]),
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.lock_outline, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Solo usaremos el Nro. para verificar el pago. Nunca te pediremos PIN.',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]))),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: SizedBox(
                width: double.infinity, height: 52,
                child: FilledButton(
                  onPressed: _valido && !_verificando ? _verificar : null,
                  style: FilledButton.styleFrom(backgroundColor: FlumiTema.colorPrimario, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: _verificando
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Verificar pago', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progreso(int a, int t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Paso $a de $t', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
            Text('${((a / t) * 100).round()}%', style: TextStyle(fontSize: 12, color: FlumiTema.colorPrimario, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: a / t, minHeight: 6, backgroundColor: Colors.grey[200], color: FlumiTema.colorPrimario)),
        ]),
      );
}
