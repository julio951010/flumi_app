import 'dart:html' as html;
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

Future<XFile> xfileDesdeBytesImpl(Uint8List bytes, String nombre) async {
  final blob = html.Blob([bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  return XFile(url, name: nombre, mimeType: 'image/png');
}
