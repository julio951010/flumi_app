with open('lib/features/chat/pantallas/chats_pantalla.dart', 'r') as f:
    content = f.read()

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
    with open('lib/features/chat/pantallas/chats_pantalla.dart', 'w') as f:
        f.write(content)
    print('Imports updated')
else:
    print('Imports NOT FOUND')
    idx = content.find('import ')
    while idx >= 0:
        end = content.find('\n', idx)
        print(repr(content[idx:end]))
        idx = content.find('import ', idx + 1)