import 'package:flutter/material.dart';
import '../../../core/estilos/tema.dart';
import '../modelos/pago_datos.dart';
import 'pago_datos_transferencia_pantalla.dart';

class PagoAdvertenciasPantalla extends StatefulWidget {
  final PagoDatos datos;
  const PagoAdvertenciasPantalla({super.key, required this.datos});

  @override
  State<PagoAdvertenciasPantalla> createState() => _PagoAdvertenciasPantallaState();
}

class _PagoAdvertenciasPantallaState extends State<PagoAdvertenciasPantalla> {
  bool _check1 = false;
  bool _check2 = false;
  bool _check3 = false;

  bool get _puedeContinuar => _check1 && _check2 && _check3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Antes de pagar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Column(
        children: [
          _progreso(2, 5),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [FlumiTema.colorPrimario, FlumiTema.colorPrimario.withValues(alpha: 0.85)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Lee con atención para evitar que tu pago se pierda',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13, height: 1.35)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _advertencia(
                  icon: Icons.signal_cellular_alt,
                  color: const Color(0xFF43A047),
                  titulo: 'Verifica tu conexión',
                  detalle: 'Asegúrate de tener buena señal y datos. Si la transferencia se corta, el ID puede no generarse y perderás el comprobante.',
                ),
                _advertencia(
                  icon: Icons.fact_check_outlined,
                  color: const Color(0xFF1E88E5),
                  titulo: 'Revisa los datos',
                  detalle: 'Tarjeta destino, teléfono a confirmar y monto deben coincidir exactamente. Un error invalida la verificación.',
                ),
                _advertencia(
                  icon: Icons.receipt_long_outlined,
                  color: const Color(0xFFF4511E),
                  titulo: 'Guarda el comprobante',
                  detalle: widget.datos.metodo == MetodoPago.transfermovil
                      ? 'Después de pagar en Transfermóvil, copia el Nro. Transacción (13 caracteres, letras y números). Lo necesitarás en el siguiente paso.'
                      : 'Después de pagar en EnZona, copia el Nro. Transacción (12 caracteres, letras y números). Lo necesitarás en el siguiente paso.',
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Flumi nunca te pedirá tu PIN ni el código de tu tarjeta. Solo el Nro. público del comprobante.',
                          style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.35))),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _checkTile('Tengo buena señal y datos', _check1, (v) => setState(() => _check1 = v)),
                _checkTile('Revisaré los datos antes de transferir', _check2, (v) => setState(() => _check2 = v)),
                _checkTile('Guardaré el Nro. Transacción', _check3, (v) => setState(() => _check3 = v)),
              ],
            ),
          ),
          _barraContinuar(
            habilitado: _puedeContinuar,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PagoDatosTransferenciaPantalla(datos: widget.datos))),
          ),
        ],
      ),
    );
  }

  Widget _advertencia({required IconData icon, required Color color, required String titulo, required String detalle}) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(detalle, style: TextStyle(color: Colors.grey[600], fontSize: 12.5, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _checkTile(String texto, bool valor, ValueChanged<bool> onChanged) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: () => onChanged(!valor),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: valor ? FlumiTema.colorPrimario.withValues(alpha: 0.08) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: valor ? FlumiTema.colorPrimario : Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(valor ? Icons.check_box : Icons.check_box_outline_blank, color: valor ? FlumiTema.colorPrimario : Colors.grey[400], size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text(texto, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
              ],
            ),
          ),
        ),
      );

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

  Widget _barraContinuar({required bool habilitado, required VoidCallback onTap}) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: SizedBox(
            width: double.infinity, height: 52,
            child: FilledButton(
              onPressed: habilitado ? onTap : null,
              style: FilledButton.styleFrom(backgroundColor: FlumiTema.colorPrimario, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Text('Entendido, continuar', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      );
}
