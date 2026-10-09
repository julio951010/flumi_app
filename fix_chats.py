with open('lib/features/chat/pantallas/chats_pantalla.dart', 'r') as f:
    content = f.read()

# Replace the build method
old = """  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ResumenConversacion>>(
      stream: widget.repositorio.observarConversaciones(widget.miId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'No se pudieron cargar las conversaciones',
              style: TextStyle(color: Colors.grey[500], fontSize: 15),
            ),
          );
        }
        final conversaciones = snapshot.data;
        if (conversaciones == null) return _esqueleto();

        return StreamBuilder<List<PerfilChat>>(
          stream: widget.repositorio.observarPerfiles(widget.miId),
          builder: (context, snapPerf) {
            final perfiles = snapPerf.data ?? const <PerfilChat>[];
            // El vacío solo se muestra cuando no hay conversaciones NI
            // perfiles: la sección "Personas" sigue visible con matches,
            // aunque hayas borrado la última conversación.
            if (conversaciones.isEmpty &&
                snapPerf.hasData &&
                perfiles.isEmpty) {
              return _vacio();
            }
            final noLeidos = conversaciones.fold<int>(
                0, (acc, c) => acc + c.noLeidos);
            final totalMatches = perfiles.where((p) => p.esMatch).length;

            return RefreshIndicator(
              onRefresh: () => widget.repositorio.sincronizarAhora(),
              child: ListView(
                controller: _scrollCtrl,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                children: [
                  if (noLeidos > 0 || totalMatches > 0)
                    _banner(
                      noLeidos: noLeidos,
                      totalMatches: totalMatches,
                      onAction: () {
                        if (noLeidos > 0) {
                          final conv = conversaciones.firstWhere(
                            (c) => c.noLeidos > 0,
                            orElse: () => conversaciones.first,
                          );
                          _abrirChat(conv);
                        } else if (perfiles.isNotEmpty) {
                          final match = perfiles.firstWhere(
                            (p) => p.esMatch,
                            orElse: () => perfiles.first,
                          );
                          _abrirChat(_resumenDePerfil(match));
                        }
                      },
                    ),
                    const SizedBox(height: 4),
                    if (perfiles.isNotEmpty) ...[
                      _encabezadoSeccion('Personas'),
                      const SizedBox(height: 4),
                      _filaPerfiles(perfiles),
                      const SizedBox(height: 14),
                    ],
                    if (conversaciones.isNotEmpty) ...[
                      _encabezadoSeccion('Conversaciones'),
                      const SizedBox(height: 8),
                      for (final conv in conversaciones)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _fila(conv),
                        ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }"""

new = """  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ResumenConversacion>>(
      stream: widget.repositorio.observarConversaciones(widget.miId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'No se pudieron cargar las conversaciones',
              style: TextStyle(color: Colors.grey[500], fontSize: 15),
            ),
          );
        }
        final conversaciones = snapshot.data;
        if (conversaciones == null) return _esqueleto();

        return StreamBuilder<List<PerfilChat>>(
          stream: widget.repositorio.observarPerfiles(widget.miId),
          builder: (context, snapPerf) {
            final perfiles = snapPerf.data ?? const <PerfilChat>[];
            if (conversaciones.isEmpty &&
                snapPerf.hasData &&
                perfiles.isEmpty) {
              return _vacio();
            }
            final noLeidos = conversaciones.fold<int>(
                0, (acc, c) => acc + c.noLeidos);
            final totalMatches = perfiles.where((p) => p.esMatch).length;

            return Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 0,
                scrolledUnderElevation: 0,
                title: const Text(
                  'Chats',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                actions: [
                  if (noLeidos > 0)
                    IconButton(
                      icon: const Icon(Icons.done_all, color: Colors.black87, size: 24),
                      tooltip: 'Marcar todas como leídas',
                      onPressed: () async {
                        await widget.repositorio.marcarTodasConversacionesLeidas(widget.miId);
                        if (!mounted) return;
                        NotificacionServicio.exito(context, 'Conversaciones marcadas como leídas');
                      },
                    ),
                ],
              ),
              body: RefreshIndicator(
                onRefresh: () => widget.repositorio.sincronizarAhora(),
                child: ListView(
                  controller: _scrollCtrl,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  children: [
                    if (noLeidos > 0 || totalMatches > 0)
                      _banner(
                        noLeidos: noLeidos,
                        totalMatches: totalMatches,
                        onAction: () {
                          if (noLeidos > 0) {
                            final conv = conversaciones.firstWhere(
                              (c) => c.noLeidos > 0,
                              orElse: () => conversaciones.first,
                            );
                            _abrirChat(conv);
                          } else if (perfiles.isNotEmpty) {
                            final match = perfiles.firstWhere(
                              (p) => p.esMatch,
                              orElse: () => perfiles.first,
                            );
                            _abrirChat(_resumenDePerfil(match));
                          }
                        },
                      ),
                    const SizedBox(height: 4),
                    if (perfiles.isNotEmpty) ...[
                      _encabezadoSeccion('Personas'),
                      const SizedBox(height: 4),
                      _filaPerfiles(perfiles),
                      const SizedBox(height: 14),
                    ],
                    if (conversaciones.isNotEmpty) ...[
                      _encabezadoSeccion('Conversaciones'),
                      const SizedBox(height: 8),
                      for (final conv in conversaciones)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Dismissible(
                            key: ValueKey(conv.otroUsuarioId),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
                            ),
                            confirmDismiss: (direction) async {
                              return await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Borrar conversación'),
                                  content: Text('¿Seguro que quieres borrar la conversación con ${conv.nombre}? Se eliminará también del servidor.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Borrar', style: TextStyle(color: Colors.redAccent)),
                                    ),
                                  ],
                                ),
                              );
                            },
                            onDismissed: (direction) async {
                              await widget.repositorio.borrarConversacion(conv.otroUsuarioId, widget.miId);
                              if (mounted) {
                                NotificacionServicio.exito(context, 'Conversación borrada');
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: _fila(conv),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }"""

if old in content:
    content = content.replace(old, new)
    with open('lib/features/chat/pantallas/chats_pantalla.dart', 'w') as f:
        f.write(content)
    print('Replaced successfully')
else:
    print('NOT FOUND - checking around line 89')
    idx = content.find('Widget build(BuildContext context)')
    if idx >= 0:
        print(repr(content[idx:idx+500]))