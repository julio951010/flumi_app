with open('lib/features/chat/pantallas/chats_pantalla.dart', 'r') as f:
    content = f.read()

# Find the build method and replace it more flexibly
import re

# Pattern to match from @override Widget build to the end of the method (before next method)
pattern = r'(  @override\n  Widget build\(BuildContext context\) \{(.*?\n  \})'

# Use a more specific pattern to match the exact old build method
old_pattern = r'(  @override\n  Widget build\(BuildContext context\) \{\n    return StreamBuilder<List<ResumenConversacion>>\(\n      stream: widget\.repositorio\.observarConversaciones\(widget\.miId\),\n      builder: \(context, snapshot\) \{\n        if \(snapshot\.hasError\) \{\n          return Center\(\n            child: Text\(\n              \'No se pudieron cargar las conversaciones\',\n              style: TextStyle\(color: Colors\.grey\[500\], fontSize: 15\),\n            \),\n          \);\n        \}\n        final conversaciones = snapshot\.data;\n        if \(conversaciones == null\) return _esqueleto\(\);\n\n        return StreamBuilder<List<PerfilChat>>\(\n          stream: widget\.repositorio\.observarPerfiles\(widget\.miId\),\n          builder: \(context, snapPerf\) \{\n            final perfiles = snapPerf\.data \?\? const <PerfilChat>\[\];\n            // El vacío solo se muestra cuando no hay conversaciones NI\n            // perfiles: la sección "Personas" sigue visible con matches,\n            // aunque hayas borrado la última conversación.\n            if \(conversaciones\.isEmpty \&\&\n                snapPerf\.hasData \&\&\n                perfiles\.isEmpty\) \{\n              return _vacio\(\);\n            \}\n            final noLeidos = conversaciones\.fold<int>\(\n                0, \(acc, c\) => acc \+ c\.noLeidos\);\)'
# Simpler: just use string find and replace with a unique marker
import re

# Find the start of build method
start = content.find('  @override\n  Widget build(BuildContext context) {')
if start >= 0:
    # Find the matching closing brace - we'll look for the next method definition
    end = content.find('\n  ', start + 100)
    # Actually let's find the end of the build method by looking for the next method
    # Find the next '  ' (two spaces) followed by a word and '(' at the same indentation
    pass

# Simpler approach: just replace the specific parts we need
# 1. Add imports
# 2. Add Scaffold with AppBar in build method
# 3. Wrap _fila with Dismissible

# Let's do targeted replacements
# First, add imports
old_imports = """import 'package:flutter/material.dart';
import '../../../core/base_datos_local/database.dart';
import '../../../core/servicios/suscripcion_servicio.dart';
import '../../../widgets_comunes/avatar_usuario.dart';
import '../../../widgets_comunes/shimmer_caja.dart';
import '../chat_repositorio.dart';
import 'chat_pantalla.dart';"""

new_imports = """import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/base_datos_local/database.dart';
import '../../../core/servicios/notificacion_servicio.dart';
import '../../../core/servicios/suscripcion_servicio.dart';
import '../../../widgets_comunes/avatar_usuario.dart';
import '../../../widgets_comunes/shimmer_caja.dart';
import '../chat_repositorio.dart';
import 'chat_pantalla.dart';"""

if old_imports in content:
    content = content.replace(old_imports, new_imports)
    print('Imports updated')
else:
    print('Imports not found')

with open('lib/features/chat/pantallas/chats_pantalla.dart', 'w') as f:
    f.write(content)
print('Done with imports')