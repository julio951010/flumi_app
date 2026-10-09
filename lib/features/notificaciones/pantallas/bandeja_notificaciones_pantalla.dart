import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/env.dart';
import '../../../core/base_datos_local/database.dart';
import '../../../core/estilos/tema.dart';
import '../../../core/servicios/preferencias_notificaciones_servicio.dart';
import '../../../core/servicios/suscripcion_servicio.dart';
import '../../../core/servicios/visitas_historial_servicio.dart';
import '../../../widgets_comunes/shimmer_caja.dart';
import '../../../widgets_comunes/avatar_usuario.dart';
import '../../../main.dart'; // para syncService global

enum TipoNotificacion { meGusta, visita, match, mensaje, soporte }

class BandejaNotificacionesPantalla extends StatefulWidget {
  final AppDatabase db;
  final String miId;
  final VisitasServicio visitasServicio;
  final HistorialLikesServicio historialLikesServicio;
  final SuscripcionServicio suscripcionServicio;
  final VoidCallback? onAbierto;
  /// Callback al pulsar "Marcar todas como leídas": limpia sociales Y
  /// notificaciones de mensajes (para que la campana llegue a 0).
  final VoidCallback? onMarcarTodas;

  /// Navega a la pestaña principal correspondiente (2 = Me Gusta, 3 = Chats)
  /// cuando la notificación no se puede abrir sin plan.
  final void Function(int tab, int subindice)? onNavegarA;

  /// Abre el hilo de Ayuda y soporte (tickets + respuestas) al tocar una
  /// notificación de tipo soporte.
  final VoidCallback? onAbrirSoporte;

  const BandejaNotificacionesPantalla({
    super.key,
    required this.db,
    required this.miId,
    required this.visitasServicio,
    required this.historialLikesServicio,
    required this.suscripcionServicio,
    this.onAbierto,
    this.onMarcarTodas,
    this.onNavegarA,
    this.onAbrirSoporte,
  });

  @override
  State<BandejaNotificacionesPantalla> createState() =>
      _BandejaNotificacionesPantallaState();
}

class _NotificacionInbox {
  final String id;
  final TipoNotificacion tipo;
  final Usuario? usuario;
  final String nombre;
  final DateTime timestamp;
  final String? preview;
  final int visitasConteo;

  const _NotificacionInbox({
    required this.id,
    required this.tipo,
    required this.usuario,
    required this.nombre,
    required this.timestamp,
    this.preview,
    this.visitasConteo = 1,
  });
}

class _BandejaNotificacionesPantallaState
    extends State<BandejaNotificacionesPantalla> {
  final Set<String> _leidas = {};
  List<_NotificacionInbox> _items = [];
  bool _cargando = true;
  bool _marcadoVisto = false;
  late final VisitasServicio _visitasServicio = widget.visitasServicio;
  late final HistorialLikesServicio _historialLikesServicio =
      widget.historialLikesServicio;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final todos = await widget.db.select(widget.db.usuarios).get();
      final mapa = {for (final u in todos) u.uuid: u};
      final miId = widget.miId;
      final items = <_NotificacionInbox>[];

      final recibidos =
          await _historialLikesServicio.obtenerLikesRecibidosDetalle();
      for (final h in recibidos) {
        final u = mapa[h.usuarioId];
        if (u == null) continue;
        items.add(_NotificacionInbox(
          id: 'meGusta:${u.uuid}:${h.timestamp.millisecondsSinceEpoch}',
          tipo: TipoNotificacion.meGusta,
          usuario: u,
          nombre: u.nombre,
          timestamp: h.timestamp,
        ));
      }

      final visitasList = await _visitasServicio.obtenerVisitas();
      final visitasConteo = await _visitasServicio.contarPorVisitante();
      for (final v in visitasList) {
        final u = mapa[v.visitanteId];
        if (u == null) continue;
        items.add(_NotificacionInbox(
          id: 'visita:${u.uuid}:${v.timestamp.millisecondsSinceEpoch}',
          tipo: TipoNotificacion.visita,
          usuario: u,
          nombre: u.nombre,
          timestamp: v.timestamp,
          visitasConteo: visitasConteo[u.uuid] ?? 1,
        ));
      }

      final matches = await (widget.db.select(widget.db.matches)).get();
      for (final m in matches) {
        if (m.usuarioAId != miId && m.usuarioBId != miId) continue;
        final otroId = m.usuarioAId == miId ? m.usuarioBId : m.usuarioAId;
        final u = mapa[otroId];
        if (u == null) continue;
        items.add(_NotificacionInbox(
          id: 'match:${u.uuid}:${m.timestampMatch.millisecondsSinceEpoch}',
          tipo: TipoNotificacion.match,
          usuario: u,
          nombre: u.nombre,
          timestamp: m.timestampMatch,
        ));
      }

      final cortes =
          await (widget.db.select(widget.db.conversacionesEliminadas)).get();
      final cortesMap = {
        for (final t in cortes) t.otroUsuarioId: t.eliminadoEn
      };

      final mensajes =
          await (widget.db.select(widget.db.mensajes)
                ..where((m) => m.receptorId.equals(miId)))
              .get();
      final ultimosPorEmisor = <String, Mensaje>{};
      for (final ms in mensajes) {
        final corte = cortesMap[ms.emisorId];
        if (corte != null && !ms.timestamp.isAfter(corte)) {
          continue;
        }
        final prev = ultimosPorEmisor[ms.emisorId];
        if (prev == null || prev.timestamp.isBefore(ms.timestamp)) {
          ultimosPorEmisor[ms.emisorId] = ms;
        }
      }
      for (final ms in ultimosPorEmisor.values) {
        final u = mapa[ms.emisorId];
        if (u == null) continue;
        items.add(_NotificacionInbox(
          id: 'mensaje:${u.uuid}:${ms.timestamp.millisecondsSinceEpoch}',
          tipo: TipoNotificacion.mensaje,
          usuario: u,
          nombre: u.nombre,
          timestamp: ms.timestamp,
          preview: ms.contenido,
        ));
      }

      // Respuestas de soporte (transaccionales, siempre visibles): una por
      // ticket respondido. El id sigue el esquema 'soporte:<ticket>:<ms>'
      // para compartir el visto con la campana (main).
      if (!kUsarServidorLocal) {
        try {
          final res = await Supabase.instance.client
              .from('soporte_mensajes')
              .select('id,respuesta,respondido_en,creado_en')
              .eq('usuario_id', miId)
              .eq('respondido', true)
              .order('respondido_en', ascending: false)
              .limit(20)
              .timeout(const Duration(seconds: 8));
          for (final f in (res as List).cast<Map<String, dynamic>>()) {
            final respuesta = (f['respuesta'] as String?) ?? '';
            if (respuesta.trim().isEmpty) continue;
            final ts = DateTime.tryParse(
                    (f['respondido_en'] as String?) ?? '') ??
                DateTime.tryParse((f['creado_en'] as String?) ?? '') ??
                DateTime.now();
            items.add(_NotificacionInbox(
              id: 'soporte:${f['id']}:${ts.millisecondsSinceEpoch}',
              tipo: TipoNotificacion.soporte,
              usuario: null,
              nombre: 'Soporte',
              timestamp: ts,
              preview: respuesta,
            ));
          }
        } catch (_) {}
      }

      // Refresca el espejo local (el await sincroniza; el resultado no se
      // usa aquí: Mis gustas no se listan en la bandeja).
      await _historialLikesServicio.obtenerHistorial();
      final abiertas = await (widget.db.select(widget.db.notificacionesVistas)
            ..where((n) => n.usuarioId.equals(widget.miId)))
          .get()
          .then((fs) => fs.map((f) => f.notificacionId).toSet());

      await PreferenciasNotificacionesServicio.instancia.asegurarCargada();

      if (mounted) {
        setState(() {
          items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          items.removeWhere((n) => abiertas.contains(n.id));
          // Preferencias de notificaciones: se descartan las categorías
          // que el usuario desactivó en Configuración → Notificaciones.
          final prefs = PreferenciasNotificacionesServicio.instancia;
          items.removeWhere((n) => !_categoriaPermitida(prefs, n.tipo));
          _items = items;
          // Solo lo persistido en BD cuenta como leído: lo nuevo conserva
          // su estilo de no leída hasta abrirlo o marcarlo.
          _leidas.clear();
          _leidas.addAll(abiertas);
          if (!_marcadoVisto) {
            _marcadoVisto = true;
            // Al abrir la bandeja: limpia el badge del nav (campana) y
            // persiste todo lo visible como visto EN SEGUNDO PLANO (a la
            // próxima ya no vuelven como nuevas). Sobrevive reinicios,
            // sesiones y recompilas.
            for (final n in items) {
              unawaited(
                  widget.db.into(widget.db.notificacionesVistas).insert(
                        NotificacionesVistasCompanion.insert(
                            usuarioId: widget.miId, notificacionId: n.id),
                        mode: InsertMode.insertOrIgnore,
                      ));
            }
            widget.onAbierto?.call();
          }
        });
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  bool _categoriaPermitida(
      PreferenciasNotificacionesServicio prefs, TipoNotificacion tipo) {
    switch (tipo) {
      case TipoNotificacion.mensaje:
        return prefs.mensajes;
      case TipoNotificacion.meGusta:
        return prefs.lesGusto;
      case TipoNotificacion.visita:
        return prefs.visitas;
      case TipoNotificacion.match:
        return prefs.matches;
      case TipoNotificacion.soporte:
        // Transaccional (respuesta esperada): siempre visible.
        return true;
    }
  }

  String _formatoTiempo(DateTime dt) {
    final localDt = dt.isUtc ? dt.toLocal() : dt;
    final diff = DateTime.now().difference(localDt);
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays < 2) return 'Ayer';
    return 'Hace ${diff.inDays} d\u00edas';
  }

  String _texto(_NotificacionInbox n) {
    switch (n.tipo) {
      case TipoNotificacion.meGusta:
        return 'A ${n.nombre} le gust\u00f3 tu perfil';
      case TipoNotificacion.visita:
        // Primera visita: "visitó tu perfil"; si te ha visitado más de una
        // vez, la notificación escala a "está interesado en ti".
        if (n.visitasConteo > 1) {
          return '${n.nombre} est\u00e1 interesado en ti';
        }
        return '${n.nombre} visit\u00f3 tu perfil';
      case TipoNotificacion.match:
        return '\u00a1Hiciste match con ${n.nombre}!';
      case TipoNotificacion.mensaje:
        return 'Nuevo mensaje de ${n.nombre}';
      case TipoNotificacion.soporte:
        return 'Soporte respondió tu mensaje';
    }
  }

  IconData _icono(TipoNotificacion tipo) {
    switch (tipo) {
      case TipoNotificacion.meGusta:
        return Icons.favorite;
      case TipoNotificacion.visita:
        return Icons.visibility_outlined;
      case TipoNotificacion.match:
        return Icons.whatshot;
      case TipoNotificacion.mensaje:
        return Icons.chat_bubble;
      case TipoNotificacion.soporte:
        return Icons.support_agent;
    }
  }

  Color _colorIcono(TipoNotificacion tipo) {
    switch (tipo) {
      case TipoNotificacion.meGusta:
        return Colors.redAccent;
      case TipoNotificacion.visita:
        return Colors.blueAccent;
      case TipoNotificacion.match:
        return Colors.orangeAccent;
      case TipoNotificacion.mensaje:
        return FlumiTema.colorPrimario;
      case TipoNotificacion.soporte:
        return FlumiTema.colorPrimario;
    }
  }

  int get _noLeidas => _items.where((n) => !_leidas.contains(n.id)).length;

  /// Cuenta notificaciones no leídas considerando BD y estado local.
  Future<int> get noLeidasAsync async {
    int count = 0;
    for (final n in _items) {
      if (!_leidas.contains(n.id)) {
        // Verificar en BD si no está en memoria local
        final query = widget.db.select(widget.db.notificacionesVistas)
          ..where((na) =>
              na.usuarioId.equals(widget.miId) & na.notificacionId.equals(n.id));
        final existe = await query.getSingleOrNull();
        if (existe == null) count++;
      }
    }
    return count;
  }

  /// Marca todas las notificaciones como leídas y las persiste (con await:
  /// sin carrera con un refresh inmediato).
  Future<void> _marcarTodosLeidos() async {
    final ids = _items.map((n) => n.id).toList();
    if (ids.isNotEmpty) {
      await syncService.marcarNotificacionesVistas(ids);
    }
    if (!mounted) return;
    setState(() {
      _leidas.addAll(ids);
    });
    widget.onMarcarTodas?.call();
    widget.onAbierto?.call();
  }

  /// Pide confirmacion y borra todas las notificaciones visibles.
  Future<void> _confirmarLimpiar() async {
    if (_items.isEmpty) return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpiar notificaciones'),
        content: const Text(
            'Se eliminaran todas las notificaciones de esta bandeja.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
    if (confirmado == true) await _limpiarTodo();
  }

  /// Elimina TODAS las notificaciones visibles y persiste el borrado con
  /// await (sin carrera): al reabrir no queda nada de lo borrado. Limpia
  /// también la campana (sociales + mensajes).
  Future<void> _limpiarTodo() async {
    final ids = _items.map((n) => n.id).toList();
    if (ids.isEmpty) return;
    await syncService.marcarNotificacionesVistas(ids);
    if (!mounted) return;
    setState(() {
      _items.clear();
      _leidas.addAll(ids);
    });
    widget.onMarcarTodas?.call();
    widget.onAbierto?.call();
  }

  /// Abre la notificación: navega al perfil, chat o pestaña correspondiente.
  Future<void> _abrir(_NotificacionInbox n) async {
    // Persiste primero (con await): al reabrir la bandeja la notificación
    // ya no aparece, sin carrera con un refresh inmediato.
    await syncService.marcarNotificacionesVistas([n.id]);
    if (!mounted) return;
    setState(() {
      _leidas.add(n.id);
      _items.removeWhere(
          (item) => item.id == n.id && item.timestamp == n.timestamp);
    });
    // Soporte: abre el hilo (no hay perfil/chat destino).
    if (n.tipo == TipoNotificacion.soporte) {
      if (!mounted) return;
      Navigator.pop(context);
      widget.onAbrirSoporte?.call();
      return;
    }
    final usuario = n.usuario;
    if (usuario == null) return;
    // Destinos de tap (igual que push): mensaje→Chats; match→Actividad/
    // Matches; meGusta→Actividad/Le gustas; visita→Actividad/Visitas.
    final int tab;
    final int subindice;
    switch (n.tipo) {
      case TipoNotificacion.mensaje:
        tab = 3;
        subindice = 0;
      case TipoNotificacion.match:
        tab = 2;
        subindice = 3;
      case TipoNotificacion.meGusta:
        tab = 2;
        subindice = 0;
      case TipoNotificacion.visita:
        tab = 2;
        subindice = 1;
      case TipoNotificacion.soporte:
        // Ya manejado arriba (abre el hilo); inalcanzable.
        return;
    }
    if (!mounted) return;
    Navigator.pop(context);
    widget.onNavegarA?.call(tab, subindice);
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
          'Notificaciones',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline, color: primario, size: 22),
              onPressed: _confirmarLimpiar,
              tooltip: 'Limpiar notificaciones',
            ),
          if (_noLeidas > 0)
            IconButton(
              icon: Icon(Icons.done_all, color: primario, size: 22),
              onPressed: _marcarTodosLeidos,
              tooltip: 'Marcar todas como le\u00eddas',
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _cargando
            ? _esqueleto()
            : _items.isEmpty
                ? _vacio()
                : RefreshIndicator(
                    onRefresh: _cargar,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final n = _items[index];
                        final leida = _leidas.contains(n.id);
                        return _fila(n, leida, primario);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _fila(_NotificacionInbox n, bool leida, Color primario) {
    final usuario = n.usuario;
    final nombre = n.nombre;
    final fotoUrl = (usuario != null && usuario.fotosUrls.isNotEmpty)
        ? usuario.fotosUrls.first
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: leida ? Colors.white : primario.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _abrir(n),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AvatarUsuario(
                      nombre: nombre,
                      fotoUrl: fotoUrl,
                      size: 52,
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_icono(n.tipo),
                            color: _colorIcono(n.tipo), size: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (usuario?.verificadoStatus ?? false) ...[
                            const Icon(Icons.verified,
                                color: Colors.blueAccent, size: 15),
                            const SizedBox(width: 3),
                          ],
                          Flexible(
                            child: Text(
                              _texto(n),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                fontWeight:
                                    leida ? FontWeight.normal : FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (n.preview != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          n.preview!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatoTiempo(n.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: leida ? Colors.grey[400] : primario,
                        fontWeight:
                            leida ? FontWeight.normal : FontWeight.w600,
                      ),
                      ),
                    ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _vacio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.notifications_none,
                  size: 44, color: Colors.grey[400]),
            ),
            const SizedBox(height: 20),
            const Text(
              'No tienes notificaciones',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Cuando tengas matches, mensajes, likes, visitas o respuestas de soporte te avisaremos aqu\u00ed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: Colors.grey[500], height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _esqueleto() {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            ShimmerCaja(width: 52, height: 52, radius: 26),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerCaja(width: 160, height: 14),
                  SizedBox(height: 8),
                  ShimmerCaja(width: 100, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}