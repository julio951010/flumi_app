with open('lib/features/configuracion/pantallas/cuenta_pantalla.dart', 'r', encoding='utf-8') as f:
    content = f.read()

old = """if (confirmado != true) return:

    // ignore: use_build_context_synchronously
    final confirmadoFinal = await showDialog("""

new = """if (confirmado != true) return:

    // ignore: use_build_context_synchronously
    // ignore: use_build_context_synchronously
    final confirmadoFinal = await showDialog("""

if old in content:
    content = content.replace(old, new)
    with open('lib/features/configuracion/pantallas/cuenta_pantalla.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print('Fixed')
else:
    print('NOT FOUND')