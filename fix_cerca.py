with open('lib/features/encuentros/pantallas/cerca_de_ti_pantalla.dart', 'r') as f:
    content = f.read()

old = """onChat: () => _abrirChat(usuario),
          onMeGusta: () => _meGusta(usuario),
          onRechazar: esMatch
        ? () async {
            await _chatRepo.romperMatch(usuario.uuid, widget.miId);
            if (mounted) Navigator.pop(context);
          }
        : () {
            // El "No me gusta" en Cerca de ti no registra rechazo: el perfil
            // se mantiene en el feed (los rechazos solo aplican al mazo).
            Navigator.pop(context);
          },
        onReportar: (codigo) async {"""

new = """onChat: () => _abrirChat(usuario),
          onMeGusta: () => _meGusta(usuario),
          onRechazar: () => Navigator.pop(context),
          onReportar: (codigo) async {"""

if old in content:
    content = content.replace(old, new)
    with open('lib/features/encuentros/pantallas/cerca_de_ti_pantalla.dart', 'w') as f:
        f.write(content)
    print('Replaced successfully')
else:
    print('NOT FOUND')
    lines = content.split('\n')
    for i in range(495, 515):
        if i < len(lines):
            print(f'{i+1}: {repr(lines[i])}')