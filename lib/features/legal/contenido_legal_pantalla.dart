import 'package:flutter/material.dart';

import 'contenidos_servicio.dart';

/// Visor genérico de contenidos legales (términos, privacidad, contactos...).
/// El cuerpo se edita desde admin_flumi; los párrafos se separan por líneas
/// en blanco.
class ContenidoLegalPantalla extends StatefulWidget {
  final String clave;
  final String titulo;

  const ContenidoLegalPantalla({
    super.key,
    required this.clave,
    required this.titulo,
  });

  @override
  State<ContenidoLegalPantalla> createState() => _ContenidoLegalPantallaState();
}

class _ContenidoLegalPantallaState extends State<ContenidoLegalPantalla> {
  String? _cuerpo;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cuerpo = null;
      _error = null;
    });
    try {
      final cuerpo =
          await ContenidosServicio.instancia.obtenerCuerpo(widget.clave);
      if (mounted) setState(() => _cuerpo = cuerpo);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo cargar el contenido.');
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
        title: Text(
          widget.titulo,
          style:
              const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        actions: [
          if (_cuerpo != null || _error != null)
            IconButton(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh, size: 22),
              tooltip: 'Recargar',
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _cuerpo == null && _error == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline,
                              size: 56, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _cargar,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _cargar,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      children: [
                        for (final parrafo in _parrafos(_cuerpo!))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: SelectableText(
                              parrafo,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                height: 1.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }

  List<String> _parrafos(String cuerpo) {
    final partes = cuerpo
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    return partes.isEmpty ? [cuerpo.trim()] : partes;
  }
}
