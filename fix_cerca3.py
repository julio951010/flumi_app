with open('lib/features/encuentros/pantallas/cerca_de_ti_pantalla.dart', 'r') as f:
    content = f.read()

old = '''onRechazar: esMatch
        ? () async {
            await _chatRepo.romperMatch(usuario.uuid, widget.miId);
            if (mounted) Navigator.pop(context);
          }
        : () {
            // El "No me gusta" en Cerca de ti no registra rechazo: el perfil
            // se mantiene en el feed (los rechazos solo aplican al mazo).
            Navigator.pop(context);
          },
        ),
      ),
    );
  }'''

new = '''onRechazar: () => Navigator.pop(context),
        onReportar: (codigo) async {'''

if old in content:
    content = content.replace(old, new)
    with open('lib/features/encuentros/pantallas/cerca_de_ti_pantalla.dart', 'w') as f:
        f.write(content)
    print('Replaced successfully')
else:
    print('NOT FOUND')
    idx = content.find('onRechazar: esMatch')
    if idx >= 0:
        print('Found at index:', idx)
        print(repr(content[idx:idx+600]))