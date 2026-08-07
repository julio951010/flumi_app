import 'package:flutter/material.dart';
import '../../../../core/base_datos_local/tables.dart';
import '../../../../core/estilos/tema.dart';
import '../../../perfiles/perfil_etiquetas.dart';

typedef PreguntasCallback = void Function(List<PreguntaRespuesta> preguntas);

class PreguntasPerfilOpcion extends StatefulWidget {
  final List<PreguntaRespuesta> preguntas;
  final PreguntasCallback onCambio;
  final int maxPreguntas;
  final int maxCaracteres;

  const PreguntasPerfilOpcion({
    super.key,
    required this.preguntas,
    required this.onCambio,
    this.maxPreguntas = 3,
    this.maxCaracteres = 300,
  });

  @override
  State<PreguntasPerfilOpcion> createState() => _PreguntasPerfilOpcionState();
}

class _PreguntasPerfilOpcionState extends State<PreguntasPerfilOpcion> {
  late List<PreguntaRespuesta> _preguntas;

  static const _categorias = categoriasPreguntas;

  @override
  void initState() {
    super.initState();
    _preguntas = List.of(widget.preguntas);
  }

  String _usadasPorOtros(int indice) {
    final usadas = <String>[];
    for (var i = 0; i < _preguntas.length; i++) {
      if (i != indice) usadas.add(_preguntas[i].pregunta);
    }
    return usadas.join('|');
  }

  Future<void> _elegirPregunta(int indice) async {
    final usadas = _usadasPorOtros(indice).split('|').toSet();
    final elegida = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _SelectorPregunta(
        categorias: _categorias,
        usadas: usadas,
      ),
    );
    if (elegida == null || !mounted) return;
    final respuesta = await _escribirRespuesta(
      pregunta: elegida,
      inicial: indice < _preguntas.length ? _preguntas[indice].respuesta : '',
    );
    if (respuesta == null || !mounted) return;
    setState(() {
      if (indice < _preguntas.length) {
        _preguntas[indice] = PreguntaRespuesta(pregunta: elegida, respuesta: respuesta);
      } else {
        _preguntas.add(PreguntaRespuesta(pregunta: elegida, respuesta: respuesta));
      }
      widget.onCambio(_preguntas);
    });
  }

  Future<String?> _escribirRespuesta({required String pregunta, required String inicial}) {
    final controller = TextEditingController(text: inicial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tu respuesta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pregunta, style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.4)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              maxLength: widget.maxCaracteres,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Escribe tu respuesta...',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.black54))),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primario = FlumiTema.colorPrimario;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _preguntas.length; i++) _tarjetaPregunta(primario, i),
          if (_preguntas.length < widget.maxPreguntas) _tarjetaAnadir(primario, _preguntas.length),
        ],
      ),
    );
  }

  Widget _tarjetaPregunta(Color primario, int indice) {
    final item = _preguntas[indice];
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primario.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Pregunta ${indice + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primario))),
              TextButton.icon(
                onPressed: () => setState(() => _preguntas.removeAt(indice)),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32), tapTargetSize: MaterialTapTargetSize.shrinkWrap, foregroundColor: Colors.redAccent),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Quitar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          Text(item.pregunta, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87, height: 1.35)),
          const SizedBox(height: 8),
          Text(item.respuesta.isEmpty ? 'Sin responder aún' : item.respuesta, style: TextStyle(fontSize: 14, height: 1.4, color: item.respuesta.isEmpty ? Colors.grey[400] : Colors.black54)),
          TextButton.icon(
            onPressed: () async {
              final respuesta = await _escribirRespuesta(pregunta: item.pregunta, inicial: item.respuesta);
              if (respuesta == null || !mounted) return;
              setState(() => _preguntas[indice] = PreguntaRespuesta(pregunta: item.pregunta, respuesta: respuesta));
              widget.onCambio(_preguntas);
            },
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32), tapTargetSize: MaterialTapTargetSize.shrinkWrap, foregroundColor: primario),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Editar respuesta', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaAnadir(Color primario, int indice) {
    return InkWell(
      onTap: () => _elegirPregunta(indice),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: primario.withValues(alpha: 0.5)), color: primario.withValues(alpha: 0.05)),
        child: Column(children: [Icon(Icons.add_circle_outline, color: primario, size: 28), const SizedBox(height: 6), Text('Añadir pregunta', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primario))]),
      ),
    );
  }
}

class _SelectorPregunta extends StatelessWidget {
  final List<(String, List<String>)> categorias;
  final Set<String> usadas;

  const _SelectorPregunta({required this.categorias, required this.usadas});

  @override
  Widget build(BuildContext context) {
    const primario = FlumiTema.colorPrimario;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          const Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 4), child: Text('Elige una pregunta', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87))),
          const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text('Las preguntas ya usadas no se muestran.', style: TextStyle(fontSize: 13, color: Colors.grey))),
          Expanded(child: ListView(controller: scrollController, padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
            for (final categoria in categorias) ...[
              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(categoria.$1, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: primario))),
              for (final pregunta in categoria.$2) if (!usadas.contains(pregunta)) ListTile(contentPadding: EdgeInsets.zero, title: Text(pregunta, style: const TextStyle(fontSize: 14, color: Colors.black87)), trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 20), onTap: () => Navigator.pop(context, pregunta)),
            ],
          ])),
        ],
      ),
    );
  }
}