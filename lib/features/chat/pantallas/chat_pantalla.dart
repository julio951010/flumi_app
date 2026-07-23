import 'package:flutter/material.dart';
import '../../../core/base_datos_local/database.dart';
import '../chat_repositorio.dart';

class ChatPantalla extends StatefulWidget {
  final ChatRepositorio repositorio;
  final String otroUsuarioId;
  final String miId;

  const ChatPantalla({
    super.key,
    required this.repositorio,
    required this.otroUsuarioId,
    required this.miId,
  });

  @override
  State<ChatPantalla> createState() => _ChatPantallaState();
}

class _ChatPantallaState extends State<ChatPantalla> {
  final _mensajeCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.repositorio.suscribirseARealtime(widget.miId);
  }

  @override
  void dispose() {
    widget.repositorio.cancelarRealtime();
    _mensajeCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final texto = _mensajeCtrl.text.trim();
    if (texto.isEmpty) return;
    _mensajeCtrl.clear();
    await widget.repositorio.enviarMensaje(
      emisorId: widget.miId,
      receptorId: widget.otroUsuarioId,
      contenido: texto,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<Mensaje>>(
            stream: widget.repositorio.observarConversacion(
              widget.otroUsuarioId, widget.miId,
            ),
              builder: (context, snapshot) {
                final mensajes = snapshot.data ?? [];
                if (mensajes.isEmpty) {
                  return const Center(child: Text('No hay mensajes'));
                }
                return ListView.builder(
                  controller: _scrollCtrl,
                  itemCount: mensajes.length,
                  itemBuilder: (context, index) {
                    final msg = mensajes[index];
                    final esMio = msg.emisorId == widget.miId;
                    return ListTile(
                      title: Align(
                        alignment: esMio
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: esMio ? Colors.blue[100] : Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(msg.contenido),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mensajeCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un mensaje...',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _enviar,
                ),
              ],
            ),
          ),
        ],
      );
  }
}
