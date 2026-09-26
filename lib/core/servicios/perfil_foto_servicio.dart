import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../config/env.dart';

/// Lee los bytes de una ruta local o blob (multiplataforma vía XFile).
/// Devuelve null si no se puede leer (URLs remotas, assets empaquetados).
Future<Uint8List?> bytesDeRuta(String ruta) async {
  try {
    if (ruta.startsWith('http') || ruta.startsWith('assets/')) return null;
    return await XFile(ruta).readAsBytes();
  } catch (_) {
    return null;
  }
}

/// Sube fotos de perfil al backend.
///
/// El endpoint de fotos aún no existe en el servidor, por lo que cualquier
/// fallo (conexión, 404, bucket inexistente) se ignora y se devuelve `null`.
/// La app conserva la ruta local como respaldo mientras tanto.
class PerfilFotoServicio {
  PerfilFotoServicio._();

  /// Sube [archivo] asociándolo al usuario [usuarioId].
  /// Devuelve la URL pública si el backend la devolvió, o `null` en caso contrario.
  static Future<String?> subirFotoPerfil({
    required String usuarioId,
    required XFile archivo,
  }) async {
    if (kUsarServidorLocal) {
      try {
        final token = await LocalTokenStore.obtenerToken();
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$kServidorLocalUrl/api/profiles/$usuarioId/photos'),
        );
        if (token != null) {
          request.headers['authorization'] = 'Bearer $token';
        }
        request.files.add(
          http.MultipartFile.fromBytes(
            'foto',
            await archivo.readAsBytes(),
            filename: archivo.name,
          ),
        );
        final res = await request.send();
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final body =
              jsonDecode(await res.stream.bytesToString()) as Map<String, dynamic>;
          return body['url'] as String?;
        }
      } catch (_) {
        return null;
      }
      return null;
    }

    // Rama Supabase: almacenamiento en el bucket 'profile-photos'.
    try {
      final datos = await archivo.readAsBytes();
      final nombre =
          '${usuarioId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await sb.Supabase.instance.client.storage
          .from('profile-photos')
          .uploadBinary(nombre, datos);
      return sb.Supabase.instance.client.storage
          .from('profile-photos')
          .getPublicUrl(nombre);
    } catch (_) {
      return null;
    }
  }

  /// Sube la selfie de verificación a `profile-photos/verificacion/` para
  /// revisión manual en admin_flumi. Devuelve la URL pública o `null`.
  /// Acepta ruta local (nativo) en vez de XFile para no pedir file_picker.
  static Future<String?> subirFotoVerificacion({
    required String usuarioId,
    required String archivoRuta,
  }) async {
    if (kUsarServidorLocal) return null;
    try {
      final datos = await bytesDeRuta(archivoRuta);
      if (datos == null) return null;
      final nombre =
          'verificacion/${usuarioId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await sb.Supabase.instance.client.storage
          .from('profile-photos')
          .uploadBinary(nombre, datos);
      return sb.Supabase.instance.client.storage
          .from('profile-photos')
          .getPublicUrl(nombre);
    } catch (_) {
      return null;
    }
  }

  /// Elimina una foto del servidor usando su URL pública (o nombre de archivo).
  /// El nombre del archivo se extrae de la URL: con Supabase se borra del
  /// bucket 'profile-photos'; con servidor local se hace DELETE al endpoint.
  static Future<bool> eliminarFotoPerfil({
    required String usuarioId,
    required String urlOFoto,
  }) async {
    final nombre = Uri.parse(urlOFoto).pathSegments.last;
    if (nombre.isEmpty) return false;

    if (kUsarServidorLocal) {
      try {
        final token = await LocalTokenStore.obtenerToken();
        final res = await http.delete(
          Uri.parse('$kServidorLocalUrl/api/profiles/$usuarioId/photos/$nombre'),
          headers: token != null ? {'authorization': 'Bearer $token'} : {},
        );
        return res.statusCode >= 200 && res.statusCode < 300;
      } catch (_) {
        return false;
      }
    }

    try {
      await sb.Supabase.instance.client.storage
          .from('profile-photos')
          .remove([nombre]);
      return true;
    } catch (_) {
      return false;
    }
  }
}
