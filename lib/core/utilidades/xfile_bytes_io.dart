import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

Future<XFile> xfileDesdeBytesImpl(Uint8List bytes, String nombre) async {
  final dir = await getTemporaryDirectory();
  final archivo = File('${dir.path}/$nombre');
  await archivo.writeAsBytes(bytes);
  return XFile(archivo.path, name: nombre, mimeType: 'image/png');
}
