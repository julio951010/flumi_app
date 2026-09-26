import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/env.dart';
import '../../../core/estilos/tema.dart';
import '../../../core/servicios/notificacion_servicio.dart';

class ContactarSoportePantalla extends StatefulWidget {
  const ContactarSoportePantalla({super.key});

  @override
  State<ContactarSoportePantalla> createState() =>
      _ContactarSoportePantallaState();
}

class _TicketSoporte {
  final String id;
  final String mensaje;
  final String respuesta;
  final bool respondido;
  final DateTime creadoEn;

  const _TicketSoporte({
    required this.id,
    required this.mensaje,
    required this.respuesta,
    required this.respondido,
    required this.creadoEn,
  });

  factory _TicketSoporte.fromMap(Map<String, dynamic> m) => _TicketSoporte(
        id: (m['id'] as String?) ?? '',
        mensaje: (m['mensaje'] as String?) ?? '',
        respuesta: (m['respuesta'] as String?) ?? '',
        respondido: (m['respondido'] as bool?) ?? false,
        creadoEn:
            DateTime.tryParse((m['creado_en'] as String?) ?? '') ?? DateTime.now(),
      );
}

class _ContactarSoportePantallaState extends State<ContactarSoportePantalla> {
  final _ctrl = TextEditingController();
  List<_TicketSoporte> _tickets = [];
  bool _cargando = true;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
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
          .from('soporte_mensajes')
          .select('id,mensaje,respuesta,respondido,creado_en')
          .eq('usuario_id', uid)
          .order('creado_en', ascending: false)
          .limit(50)
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() {
        _tickets =
            (res as List).map((e) => _TicketSoporte.fromMap(e as Map<String, dynamic>)).toList();
        _cargando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _enviar() async {
    final texto = _ctrl.text.trim();
    if (texto.isEmpty || _enviando) return;
    if (kUsarServidorLocal) {
      NotificacionServicio.advertencia(
          context, 'No disponible en modo local.');
      return;
    }
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    setState(() => _enviando = true);
    try {
      await Supabase.instance.client.from('soporte_mensajes').insert({
        'usuario_id': uid,
        'mensaje': texto,
      }).timeout(const Duration(seconds: 10));
      _ctrl.clear();
      if (mounted) {
        NotificacionServicio.exito(
            context, 'Mensaje enviado. Te responderemos pronto.');
      }
      await _cargar();
    } catch (_) {
      if (mounted) {
        NotificacionServicio.alerta(
            context, 'No se pudo enviar. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
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
          'Contactar con soporte',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : _tickets.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.support_agent,
                                    size: 56, color: Colors.grey[300]),
                                const SizedBox(height: 12),
                                Text(
                                  'Cuéntanos tu problema y te ayudaremos.\nTus mensajes y respuestas aparecen aquí.',
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
                            padding:
                                const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            itemCount: _tickets.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) => _tarjeta(_tickets[i]),
                          ),
                        ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Escribe tu mensaje...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _enviando ? null : _enviar,
                    style: FilledButton.styleFrom(
                      backgroundColor: FlumiTema.colorPrimario,
                      foregroundColor: Colors.white,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(14),
                    ),
                    child: _enviando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send, size: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjeta(_TicketSoporte t) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _fmtFecha(t.creadoEn),
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: t.respondido
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  t.respondido ? 'Respondido' : 'Pendiente',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: t.respondido
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFEF6C00),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(t.mensaje, style: const TextStyle(fontSize: 14)),
          if (t.respondido && t.respuesta.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FlumiTema.colorPrimario.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.support_agent,
                          size: 16, color: FlumiTema.colorPrimario),
                      const SizedBox(width: 6),
                      Text(
                        'Soporte',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: FlumiTema.colorPrimario,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.respuesta,
                    style: const TextStyle(fontSize: 13, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _fmtFecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
