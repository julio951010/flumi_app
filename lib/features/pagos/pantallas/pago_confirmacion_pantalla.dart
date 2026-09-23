import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/estilos/tema.dart';
import '../modelos/pago_datos.dart';

class PagoConfirmacionPantalla extends StatelessWidget {
  final PagoDatos datos;
  const PagoConfirmacionPantalla({super.key, required this.datos});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _progreso(5, 5),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                children: [
                  Center(
                    child: Container(
                      width: 88, height: 88,
                      decoration: BoxDecoration(color: const Color(0xFFE8F5E9), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFA5D6A7))),
                      child: const Icon(Icons.check_rounded, size: 48, color: Color(0xFF2E7D32)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(datos.autoAprobado ? '¡Pago verificado!' : '¡Pago en verificación!', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                      datos.autoAprobado
                          ? 'Tu Nro. ${datos.idTransaccion ?? ''} coincide con el SMS de ${datos.metodo?.nombre ?? ''}. ¡Tu plan ya está activo!'
                          : 'Recibimos tu Nro. ${datos.idTransaccion ?? ''}.\nVerificaremos la transferencia en menos de 24h.',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4)),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
                    child: Column(
                      children: [
                        _fila('Plan', '${datos.nombrePlan} · ${datos.dias} días'),
                        _fila('Método', datos.metodo?.nombre ?? '-'),
                        _fila('Monto', datos.montoTexto),
                        _fila('Nro. Transacción', datos.idTransaccion ?? '-', mono: true),
                        _fila('Estado', datos.autoAprobado ? 'Aprobado' : 'En verificación', badge: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.schedule, size: 18, color: Color(0xFFEF6C00)),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Te notificaremos cuando se active tu suscripción. Si hay un problema, te contactamos por chat.',
                            style: TextStyle(fontSize: 12, color: Colors.grey[800], height: 1.35))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity, height: 52,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                        style: FilledButton.styleFrom(backgroundColor: FlumiTema.colorPrimario, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        child: const Text('Volver al inicio', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                      child: Text('Entendido', style: TextStyle(color: Colors.grey[600])),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fila(String label, String valor, {bool mono = false, bool copiable = false, bool badge = false, Color? valorColor}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: badge
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: valor == 'Aprobado' ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(valor,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold, color: valor == 'Aprobado' ? const Color(0xFF2E7D32) : const Color(0xFFEF6C00))),
                      )
                    :                     Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              valor,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                              textAlign: TextAlign.right,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valorColor ?? Colors.black87, fontFamily: mono ? 'monospace' : null),
                            ),
                          ),
                          if (copiable) const SizedBox(width: 6),
                          if (copiable)
                            Builder(
                              builder: (ctx) => GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: valor));
                                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Nro. copiado'), behavior: SnackBarBehavior.floating));
                                },
                                child: const Icon(Icons.copy, size: 14, color: Colors.grey),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      );

  Widget _progreso(int a, int t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Paso $a de $t', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
            Text('100%', style: TextStyle(fontSize: 12, color: FlumiTema.colorPrimario, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: a / t, minHeight: 6, backgroundColor: Colors.grey[200], color: FlumiTema.colorPrimario)),
        ]),
      );
}
