import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../config/env.dart';
import '../../../core/base_datos_local/database.dart';
import '../../../core/servicios/notificacion_servicio.dart';
import '../../../widgets_comunes/avatar_usuario.dart';
import '../../perfiles/perfil_repositorio.dart';

class PersonasBloqueadasPantalla extends StatefulWidget {
  final AppDatabase db;
  final PerfilRepositorio repositorio;

  const PersonasBloqueadasPantalla({
    super.key,
    required this.db,
    required this.repositorio,
  });

  @override
  State<PersonasBloqueadasPantalla> createState() =>
      _PersonasBloqueadasPantallaState();
}

class _EntradaBloqueo {
  final Bloqueo bloqueo;
  final Usuario? perfil;

  const _EntradaBloqueo(this.bloqueo, this.perfil);
}

class _PersonasBloqueadasPantallaState
    extends State<PersonasBloqueadasPantalla> {
  bool _cargando = true;
  final List<_EntradaBloqueo> _bloqueados = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final mi = await widget.repositorio.obtenerPerfilPropio();
      final bloqueos = await (widget.db.select(widget.db.bloqueos)
            ..where((b) => b.bloqueadorId.equals(mi?.uuid ?? '')))
          .get();

      final entradas = <_EntradaBloqueo>[];
      for (final bloqueo in bloqueos) {
        final perfil =
            await widget.repositorio.obtenerPerfilPorUuid(bloqueo.bloqueadoId);
        entradas.add(_EntradaBloqueo(bloqueo, perfil));
      }

      if (mounted) {
        setState(() {
          _bloqueados
            ..clear()
            ..addAll(entradas);
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _desbloquear(_EntradaBloqueo entrada) async {
    final nombre = entrada.perfil?.nombre ?? 'a este usuario';
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desbloquear usuario'),
        content: Text('¿Quieres desbloquear a $nombre?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desbloquear'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    try {
      await (widget.db.delete(widget.db.bloqueos)
            ..where((b) => b.uuid.equals(entrada.bloqueo.uuid)))
          .go();
      unawaited(_borrarBloqueoRemoto(entrada.bloqueo));
    } catch (_) {
      if (mounted) {
        NotificacionServicio.alerta(
            context, 'No se pudo desbloquear al usuario.');
      }
      return;
    }

    if (mounted) {
      setState(() =>
          _bloqueados.removeWhere((e) => e.bloqueo.uuid == entrada.bloqueo.uuid));
      NotificacionServicio.exito(context, 'Usuario desbloqueado');
    }
  }

  Future<void> _borrarBloqueoRemoto(Bloqueo bloqueo) async {
    try {
      if (kUsarServidorLocal) {
        final token = await LocalTokenStore.obtenerToken();
        if (token == null) return;
        await http.delete(
          Uri.parse('$kServidorLocalUrl/api/blocks'),
          headers: {
            'content-type': 'application/json',
            'authorization': 'Bearer $token'
          },
          body: jsonEncode({
            'bloqueador_id': bloqueo.bloqueadorId,
            'bloqueado_id': bloqueo.bloqueadoId,
          }),
        );
        return;
      }
      await sb.Supabase.instance.client
          .from('blocks')
          .delete()
          .eq('bloqueador_id', bloqueo.bloqueadorId)
          .eq('bloqueado_id', bloqueo.bloqueadoId);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Personas bloqueadas',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _bloqueados.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.block_outlined,
                          size: 64,
                          color: primario.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No has bloqueado a nadie',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Las personas que bloquees aparecerán aquí',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14, color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: _bloqueados.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, indice) {
                      final entrada = _bloqueados[indice];
                      final perfil = entrada.perfil;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: AvatarUsuario(
                          nombre: perfil?.nombre ?? '?',
                          fotoUrl: (perfil?.fotosUrls.isNotEmpty ?? false)
                              ? perfil!.fotosUrls.first
                              : null,
                          size: 44,
                        ),
                        title: Text(
                          perfil?.nombre ?? 'Usuario bloqueado',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          perfil == null ? 'No disponible offline' : 'Bloqueado',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black54),
                        ),
                        trailing: TextButton(
                          onPressed: () => _desbloquear(entrada),
                          child: Text(
                            'Desbloquear',
                            style: TextStyle(
                                color: primario,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}