import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/env.dart';
import '../../../core/estilos/tema.dart';

class HistorialPagosPantalla extends StatefulWidget {
  const HistorialPagosPantalla({super.key});

  @override
  State<HistorialPagosPantalla> createState() => _HistorialPagosPantallaState();
}

class _PagoHistorial {
  final String plan;
  final int dias;
  final int monto;
  final String metodo;
  final String estado;
  final DateTime creadoEn;
  final String nroTransaccion;
  final String tarjetaDestino;
  final String movilConfirmar;
  final String motivoRechazo;
  final DateTime? verificadoEn;

  const _PagoHistorial({
    required this.plan,
    required this.dias,
    required this.monto,
    required this.metodo,
    required this.estado,
    required this.creadoEn,
    required this.nroTransaccion,
    required this.tarjetaDestino,
    required this.movilConfirmar,
    required this.motivoRechazo,
    required this.verificadoEn,
  });

  factory _PagoHistorial.fromMap(Map<String, dynamic> m) => _PagoHistorial(
        plan: (m['plan'] as String?) ?? '',
        dias: (m['dias'] as int?) ?? 0,
        monto: (m['monto'] as int?) ?? 0,
        metodo: (m['metodo'] as String?) ?? '',
        estado: (m['estado'] as String?) ?? 'pendiente',
        creadoEn:
            DateTime.tryParse((m['creado_en'] as String?) ?? '') ?? DateTime.now(),
        nroTransaccion: (m['nro_transaccion'] as String?) ?? '-',
        tarjetaDestino: (m['tarjeta_destino'] as String?) ?? '-',
        movilConfirmar: (m['movil_confirmar'] as String?) ?? '-',
        motivoRechazo: (m['motivo_rechazo'] as String?) ?? '',
        verificadoEn: m['verificado_en'] != null
            ? DateTime.tryParse(m['verificado_en'] as String)
            : null,
      );
}

class _HistorialPagosPantallaState extends State<HistorialPagosPantalla> {
  List<_PagoHistorial> _pagos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      if (kUsarServidorLocal) {
        if (mounted) setState(() => _cargando = false);
        return;
      }
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) {
        if (mounted) setState(() => _cargando = false);
        return;
      }
      final res = await Supabase.instance.client
          .from('pagos')
          .select('plan,dias,monto,metodo,estado,creado_en,nro_transaccion,tarjeta_destino,movil_confirmar,motivo_rechazo,verificado_en')
          .eq('usuario_id', uid)
          .order('creado_en', ascending: false)
          .limit(50)
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() {
        _pagos =
            (res as List).map((e) => _PagoHistorial.fromMap(e as Map<String, dynamic>)).toList();
        _cargando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Historial de pagos',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        actions: [
          IconButton(
            onPressed: _cargando ? null : _cargar,
            icon: const Icon(Icons.refresh, size: 22),
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _pagos.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 56, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text(
                            'Aún no tienes pagos registrados.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _cargar,
                    color: FlumiTema.colorPrimario,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      itemCount: _pagos.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (_, i) => _fila(_pagos[i]),
                    ),
                  ),
      ),
    );
  }

  Widget _fila(_PagoHistorial p) {
    final estadoTexto = switch (p.estado) {
      'aprobado' => 'Aprobado',
      'rechazado' => 'Rechazado',
      _ => 'En verificación',
    };
    final estadoColor = switch (p.estado) {
      'aprobado' => const Color(0xFF2E7D32),
      'rechazado' => Colors.red,
      _ => const Color(0xFFEF6C00),
    };
    final metodoTexto = switch (p.metodo) {
      'transfermovil' => 'Transfermóvil',
      'enzona' => 'EnZona',
      _ => p.metodo,
    };
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      leading: Icon(Icons.receipt_long_outlined,
          color: FlumiTema.colorPrimario.withValues(alpha: 0.7)),
      title: Text(
        '${p.plan} · ${p.dias} días',
        style: const TextStyle(fontSize: 14, color: Colors.black87),
      ),
      subtitle: Text(
        '${_fmtFecha(p.creadoEn)} · ${p.monto} CUP · $metodoTexto',
        style: const TextStyle(fontSize: 12, color: Colors.black54),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: estadoColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              estadoTexto,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: estadoColor),
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
        ],
      ),
      onTap: () => _verDetalle(p),
    );
  }

  void _verDetalle(_PagoHistorial p) {
    final estadoTexto = switch (p.estado) {
      'aprobado' => 'Aprobado',
      'rechazado' => 'Rechazado',
      _ => 'En verificación',
    };
    final estadoColor = switch (p.estado) {
      'aprobado' => const Color(0xFF2E7D32),
      'rechazado' => Colors.red,
      _ => const Color(0xFFEF6C00),
    };
    final metodoTexto = switch (p.metodo) {
      'transfermovil' => 'Transfermóvil',
      'enzona' => 'EnZona',
      _ => p.metodo,
    };
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${p.plan} · ${p.dias} días',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: estadoColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    estadoTexto,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: estadoColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _detalleFila('Monto', '${p.monto} CUP'),
            _detalleFila('Método', metodoTexto),
            _detalleFila('Nro. Transacción', p.nroTransaccion, mono: true),
            _detalleFila('Tarjeta destino', p.tarjetaDestino),
            _detalleFila('Móvil a confirmar', p.movilConfirmar),
            _detalleFila('Fecha de pago', _fmtFechaHora(p.creadoEn)),
            if (p.verificadoEn != null)
              _detalleFila('Verificado el', _fmtFechaHora(p.verificadoEn!)),
            if (p.motivoRechazo.isNotEmpty)
              _detalleFila('Motivo', p.motivoRechazo),
          ],
        ),
      ),
    );
  }

  Widget _detalleFila(String etiqueta, String valor, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              etiqueta,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtFecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _fmtFechaHora(DateTime d) =>
      '${_fmtFecha(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
