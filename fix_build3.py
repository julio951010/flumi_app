with open('lib/features/chat/pantallas/chats_pantalla.dart', 'r') as f:
    content = f.read()

old = """            return RefreshIndicator(
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

new = """            final noLeidos = conversaciones.fold<int>(
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

with open('lib/features/chat/pantallas/chats_pantalla.dart', 'r') as f:
    content = f.read()

old = """            return RefreshIndicator(
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

new = """            final noLeidos = conversaciones.fold<int>(
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

with open('lib/features/chat/pantallas/chats_pantalla.dart', 'r') as f:
    content = f.read()

if old in content:
    content = content.replace(old, new)
    with open('lib/features/chat/pantallas/chats_pantalla.dart', 'w') as f:
        f.write(content)
    print('Build method replaced successfully')
else:
    print('NOT FOUND - searching for the pattern...')
    idx = content.find('return RefreshIndicator(')
    if idx >= 0:
        print('Found RefreshIndicator at:', idx)
        print(repr(content[idx:idx+500]))
    else:
        print('RefreshIndicator not found')