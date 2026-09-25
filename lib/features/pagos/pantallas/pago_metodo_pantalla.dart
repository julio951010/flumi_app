import 'package:flutter/material.dart';
import '../../../core/estilos/tema.dart';
import '../../../core/servicios/sms_verificacion_servicio.dart';
import '../modelos/pago_datos.dart';
import '../servicios/pagos_config_servicio.dart';
import 'pago_advertencias_pantalla.dart';

class PagoMetodoPantalla extends StatefulWidget {
  final PagoDatos datos;
  const PagoMetodoPantalla({super.key, required this.datos});

  @override
  State<PagoMetodoPantalla> createState() => _PagoMetodoPantallaState();
}

class _PagoMetodoPantallaState extends State<PagoMetodoPantalla> {
  MetodoPago? _seleccion;
  bool _transfermovilActivo = true;
  bool _enzonaActivo = true;
  bool _cargandoMetodos = true;

  @override
  void initState() {
    super.initState();
    // Desde el paso 1 ya escucha SMS de PAGOxMOVIL/ENZONA en 2do plano
    SmsVerificacionServicio.instancia.iniciar();
    _cargarMetodos();
  }

  /// Solo muestra los métodos activos en Supabase (admin_flumi → Pagos).
  /// Sin red se muestran ambos (fallback local).
  Future<void> _cargarMetodos() async {
    final tm = await PagosConfigServicio.estaActivo(MetodoPago.transfermovil);
    final ez = await PagosConfigServicio.estaActivo(MetodoPago.enzona);
    if (!mounted) return;
    setState(() {
      _transfermovilActivo = tm;
      _enzonaActivo = ez;
      _cargandoMetodos = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Método de pago', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Column(
        children: [
          _progreso(1, 5),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: FlumiTema.colorPrimario.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.verified, color: FlumiTema.colorPrimario),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.datos.nombrePlan, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text('${widget.datos.dias} días · ${widget.datos.precio} CUP',
                                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Elige cómo quieres pagar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                if (_cargandoMetodos)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (!_transfermovilActivo && !_enzonaActivo)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.pause_circle_outline,
                            color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Pagos en mantenimiento. Intenta más tarde.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Row(
                    children: [
                      if (_transfermovilActivo)
                        Expanded(
                            child: _opcion(
                                MetodoPago.transfermovil,
                                'assets/images/Transfermovil.png',
                                const Color(0xFF00A859))),
                      if (_transfermovilActivo && _enzonaActivo)
                        const SizedBox(width: 12),
                      if (_enzonaActivo)
                        Expanded(
                            child: _opcion(
                                MetodoPago.enzona,
                                'assets/images/EnZona.png',
                                const Color(0xFF0B4DA2))),
                    ],
                  ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFE082)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: Color(0xFFF57F17)),
                      const SizedBox(width: 8),
                      Expanded(child: Text('No cobramos dentro de la app. Haces la transferencia en tu app de pago y luego confirmas el ID aquí.',
                          style: TextStyle(fontSize: 12, color: Colors.grey[800], height: 1.35))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _barraContinuar(
            habilitado: _seleccion != null,
            onTap: () {
              widget.datos.metodo = _seleccion;
              Navigator.push(context, MaterialPageRoute(builder: (_) => PagoAdvertenciasPantalla(datos: widget.datos)));
            },
          ),
        ],
      ),
    );
  }

  Widget _opcion(MetodoPago m, String asset, Color color) {
    final sel = _seleccion == m;
    return InkWell(
      onTap: () => setState(() => _seleccion = m),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: sel ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? color : Colors.grey[300]!, width: sel ? 2 : 1),
        ),
        child: Column(
          children: [
            Container(
              width: 96, height: 96,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey[200]!)),
              child: Image.asset(asset, fit: BoxFit.contain),
            ),
            const SizedBox(height: 10),
            Text(m.nombre, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _progreso(int actual, int total) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Paso $actual de $total', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                Text('${((actual / total) * 100).round()}%', style: TextStyle(fontSize: 12, color: FlumiTema.colorPrimario, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: actual / total, minHeight: 6, backgroundColor: Colors.grey[200], color: FlumiTema.colorPrimario),
            ),
          ],
        ),
      );

  Widget _barraContinuar({required bool habilitado, required VoidCallback onTap}) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: SizedBox(
            width: double.infinity, height: 52,
            child: FilledButton(
              onPressed: habilitado ? onTap : null,
              style: FilledButton.styleFrom(
                backgroundColor: FlumiTema.colorPrimario,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Continuar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ),
          ),
        ),
      );
}
