import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/estilos/tema.dart';
import '../modelos/pago_datos.dart';
import '../servicios/pagos_config_servicio.dart';
import 'pago_comprobante_pantalla.dart';

class PagoDatosTransferenciaPantalla extends StatefulWidget {
  final PagoDatos datos;
  const PagoDatosTransferenciaPantalla({super.key, required this.datos});

  @override
  State<PagoDatosTransferenciaPantalla> createState() => _PagoDatosTransferenciaPantallaState();
}

class _PagoDatosTransferenciaPantallaState extends State<PagoDatosTransferenciaPantalla> {
  PagosConfig? _cfg;
  bool _cargando = true;

  PagoDatos get datos => widget.datos;
  bool get _esEnZona => datos.metodo == MetodoPago.enzona;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final m = datos.metodo;
    if (m == null) {
      setState(() => _cargando = false);
      return;
    }
    final cfg = await PagosConfigServicio.obtener(m);
    if (mounted) setState(() { _cfg = cfg; _cargando = false; });
  }

  String get _tarjeta => (_cfg?.tarjetaDestino.isNotEmpty ?? false) ? _cfg!.tarjetaDestino : datos.tarjetaDestino;
  String get _movil => (_cfg?.movilConfirmar.isNotEmpty ?? false) ? _cfg!.movilConfirmar : datos.telefonoConfirmar;
  String get _qrUrl => _cfg?.qrUrl ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Datos de transferencia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Column(
        children: [
          _progreso(3, 5),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFF3E5F5), borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      Icon(datos.metodo == MetodoPago.transfermovil ? Icons.phone_android : Icons.qr_code_2, color: const Color(0xFF6A1B9A)),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Paga en ${datos.metodo?.nombre ?? ''} con estos datos exactos',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Datos comunes para ambos métodos (gestionados desde flumi_admin)
                _filaDato('Tarjeta destino', _tarjeta, Icons.credit_card, copiable: true),
                _filaDato('Monto a transferir', datos.montoTexto, Icons.payments_outlined, copiable: true),
                _filaDato('Móvil a confirmar', _movil, Icons.phone_outlined, copiable: true),
                const SizedBox(height: 16),
                if (_qrUrl.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))]),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.qr_code, size: 18, color: Colors.black87),
                            const SizedBox(width: 8),
                            const Text('Código QR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const Spacer(),
                            TextButton(
                              onPressed: () => _copiar(context, '$_tarjeta | ${datos.montoTexto} | $_movil'),
                              child: const Text('Copiar datos', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 200, height: 200,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
                          child: _qrWidget(),
                        ),
                        const SizedBox(height: 8),
                        Text('Escanea con ${datos.metodo?.nombre ?? ''} o copia los datos',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline, size: 18, color: Color(0xFF1565C0)),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Guarda el número de la transacción que recibirás en el SMS de confirmación.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF1565C0), fontWeight: FontWeight.w600, height: 1.35))),
                    ],
                  ),
                ),
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
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PagoComprobantePantalla(datos: datos))),
                      style: FilledButton.styleFrom(backgroundColor: FlumiTema.colorPrimario, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: const Text('Ya pagué, continuar', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: () => Navigator.pop(context), child: Text('Volver', style: TextStyle(color: Colors.grey[600]))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaDato(String label, String valor, IconData icon, {bool destacado = false, bool copiable = false}) {
    return Builder(builder: (context) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: destacado ? FlumiTema.colorPrimario.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: destacado ? FlumiTema.colorPrimario : Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: destacado ? FlumiTema.colorPrimario.withValues(alpha: 0.12) : Colors.grey[100], borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: destacado ? FlumiTema.colorPrimario : Colors.grey[700], size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(valor, style: TextStyle(fontSize: destacado ? 16 : 14, fontWeight: FontWeight.bold, color: destacado ? FlumiTema.colorPrimario : Colors.black87)),
                ],
              ),
            ),
            if (copiable)
              Builder(builder: (ctx) => IconButton(
                    onPressed: () => _copiar(ctx, valor),
                    icon: Icon(Icons.copy, size: 18, color: Colors.grey[600]),
                    tooltip: 'Copiar',
                  )),
          ],
        ),
      );
    });
  }

  void _copiar(BuildContext context, String v) {
    final esMonto = v.contains('CUP');
    final paraPegar = esMonto ? v.replaceAll(RegExp(r'[^0-9]'), '') : v.replaceAll(' ', '');
    Clipboard.setData(ClipboardData(text: paraPegar));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copiado: $v'), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)));
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

  Widget _qrWidget() {
    // QR gestionado desde flumi_admin → Supabase Storage (bucket pagos_qr).
    // Si hay URL, se muestra para ambos métodos. Si no, fallback:
    // - EnZona: qr_enzona.png de prueba
    // - Transfermóvil: placeholder
    if (_qrUrl.isNotEmpty && _qrUrl.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(_qrUrl, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _esEnZona
                ? Image.asset('assets/images/qr_enzona.png', fit: BoxFit.contain)
                : _qrPlaceholder()),
      );
    }
    if (_esEnZona) return Image.asset('assets/images/qr_enzona.png', fit: BoxFit.contain);
    return _qrPlaceholder();
  }

  Widget _qrPlaceholder() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 3, crossAxisSpacing: 3),
      itemCount: 49,
      itemBuilder: (_, i) {
        final isCorner = (i < 7 && i % 7 < 3) || (i % 7 < 3 && i ~/ 7 < 3) || (i % 7 >= 4 && i ~/ 7 < 3 && i % 7 < 7);
        final fill = isCorner ? true : (i * 7 + i % 3) % 5 < 2;
        return Container(
          decoration: BoxDecoration(
            color: fill ? Colors.black87 : Colors.white,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: Colors.grey[300]!),
          ),
        );
      },
    );
  }
}
