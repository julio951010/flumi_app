import 'dart:io';

import 'package:face_verification/face_verification.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../../core/base_datos_local/database.dart';
import 'verificacion_servicio.dart';

/// Implementación on-device (Android/iOS) de la verificación facial con
/// FaceNet. Solo se compila en plataformas nativas; en web se usa el stub.
Future<VerificarResultado> verificarPerfilImpl({
  required Usuario perfil,
  required String rutaSelfie,
}) async {
  await _asegurarInit();

  final archivos = await _archivosPerfil(perfil);
  if (archivos.isEmpty) return VerificarResultado.sinFotos;

  // La selfie se guarda espejada; para comparar la misma persona con la
  // misma orientación, espejamos la selfie y las fotos de perfil por igual.
  final selfieEsp = await _espejarSiPosible(File(rutaSelfie));
  final perfilesEsp = <File>[];
  for (final f in archivos) {
    perfilesEsp.add(await _espejarSiPosible(f));
  }

  // Enrola (o reemplaza) las fotos de perfil como muestras de la persona.
  await FaceVerification.instance.deleteUserFaces(_idEnrolamiento);
  for (var i = 0; i < perfilesEsp.length; i++) {
    await FaceVerification.instance.registerFromImagePath(
      id: _idEnrolamiento,
      imagePath: perfilesEsp[i].path,
      imageId: 'foto_$i',
      replace: true,
    );
  }

  final match = await FaceVerification.instance.verifyFromImagePath(
    imagePath: selfieEsp.path,
    threshold: _umbral,
    staffId: _idEnrolamiento,
  );

  return match == _idEnrolamiento
      ? VerificarResultado.coincide
      : VerificarResultado.noCoincide;
}

const String _idEnrolamiento = 'perfil_propia';
const double _umbral = 0.70;

bool _inicializado = false;

/// Inicializa el modelo FaceNet una sola vez por sesión.
Future<void> _asegurarInit() async {
  if (_inicializado) return;
  await FaceVerification.instance.init();
  _inicializado = true;
}

/// Resuelve las fotos de perfil a archivos locales.
/// Usa las rutas locales cuando existen; en caso contrario descarga las
/// URLs remotas a un archivo temporal.
Future<List<File>> _archivosPerfil(Usuario perfil) async {
  final archivos = <File>[];
  for (final ruta in perfil.fotosLocalesRutas) {
    final f = File(ruta);
    if (await f.exists()) archivos.add(f);
  }
  for (final url in perfil.fotosUrls) {
    if (url.isEmpty) continue;
    try {
      final res = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw Exception('timeout'),
      );
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        final dir = await getTemporaryDirectory();
        final f = File(
          '${dir.path}/verif_${archivos.length}_'
          '${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await f.writeAsBytes(res.bodyBytes);
        archivos.add(f);
      }
    } catch (_) {
      // Ignora fotos que no se puedan resolver y continúa con las demás.
    }
  }
  return archivos;
}

/// Devuelve una copia espejada horizontalmente de [f]; si no se puede
/// procesar, retorna el archivo original.
Future<File> _espejarSiPosible(File f) async {
  try {
    if (!await f.exists()) return f;
    final bytes = await f.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return f;
    final procesada = img.flipHorizontal(img.bakeOrientation(decoded));
    final dir = await getTemporaryDirectory();
    final out = File(
      '${dir.path}/verif_esp_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await out.writeAsBytes(img.encodeJpg(procesada, quality: 90));
    return out;
  } catch (_) {
    return f;
  }
}
