import os
os.chdir(r'C:\_Proyectos_Flutter\flumi_app')

with open('lib/features/configuracion/pantallas/cuenta_pantalla.dart', 'r', encoding='utf-8') as f:
    content = f.read()

old = """if (confirmado != true) return:

if (confirmado != true) return:

    final confirmadoFinal = await showDialog<bool>("""

new = """if (confirmado != true) return:

    final confirmadoFinal = await showDialog<bool>("""

if old in content:
    content = content.replace(old, new)
    with open('lib/features/configuracion/pantallas/cuenta_pantalla.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print('Fixed')
else:
    print('NOT FOUND')
    idx = content.find('if (confirmado != true) return:')
    if idx >= 0:
        print(repr(content[idx:idx+200]))