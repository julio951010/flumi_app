with open('lib/features/encuentros/pantallas/cerca_de_ti_pantalla.dart', 'r') as f:
    content = f.read()

# Change 1: In _abrirPerfil, replace the ternary onRechazar with simple pop
old1 = """onRechazar: esMatch
        ? () async {
            await _chatRepo.romperMatch(usuario.uuid, widget.miId);
            if (mounted) Navigator.pop(context);
          }
        : () {
            // El "No me gusta" en Cerca de ti no registra rechazo: el perfil
            // se mantiene en el feed (los rechazos solo aplican al mazo).
            Navigator.pop(context);
          },"""

new1 = """onRechazar: () => Navigator.pop(context),"""

if old1 in content:
    content = content.replace(old1, new1)
    print('Change 1 applied')
else:
    print('Change 1 NOT FOUND')
    idx = content.find('onRechazar: esMatch')
    if idx >= 0:
        print(repr(content[idx:idx+400]))

with open('lib/features/encuentros/pantallas/cerca_de_ti_pantalla.dart', 'w') as f:
    f.write(content)