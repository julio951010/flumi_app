import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class InfoActualizacion {
  final String version;
  final int build;
  final String apkUrl;
  final String changelog;
  final bool obligatoria;

  const InfoActualizacion({
    required this.version,
    required this.build,
    required this.apkUrl,
    this.changelog = '',
    this.obligatoria = false,
  });

  factory InfoActualizacion.fromJson(Map<String, dynamic> json) {
    return InfoActualizacion(
      version: (json['version'] ?? '').toString(),
      build: int.tryParse((json['build'] ?? 0).toString()) ?? 0,
      apkUrl: (json['apk_url'] ?? '').toString(),
      changelog: (json['changelog'] ?? '').toString(),
      obligatoria: json['obligatoria'] == true,
    );
  }
}

class ActualizadorAppServicio {
  ActualizadorAppServicio._();
  static final ActualizadorAppServicio instancia = ActualizadorAppServicio._();

  String urlVersion = '';

  Future<InfoActualizacion?> comprobar() async {
    if (urlVersion.trim().isEmpty) return null;
    if (kIsWeb) return null;
    try {
      final res = await http
          .get(Uri.parse(urlVersion))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return null;
      final info = InfoActualizacion.fromJson(decoded);
      if (info.apkUrl.isEmpty) return null;

      final actual = await PackageInfo.fromPlatform();
      final buildActual = int.tryParse(actual.buildNumber) ?? 0;
      if (info.build <= buildActual) return null;
      return info;
    } catch (_) {
      return null;
    }
  }

  Future<bool> descargarEInstalar(
    InfoActualizacion info, {
    void Function(double)? onProgreso,
  }) async {
    if (kIsWeb) return false;
    try {
      if (Platform.isAndroid) {
        final estado = await Permission.requestInstallPackages.status;
        if (!estado.isGranted) {
          final pedido = await Permission.requestInstallPackages.request();
          if (!pedido.isGranted) {
            await openAppSettings();
            return false;
          }
        }
      }

      final dir = await getApplicationSupportDirectory();
      final archivo = File('${dir.path}/flumi_update.apk');
      if (await archivo.exists()) await archivo.delete();

      final req = http.Request('GET', Uri.parse(info.apkUrl));
      final resp = await http.Client().send(req);
      if (resp.statusCode != 200) return false;

      final total = resp.contentLength ?? 0;
      int recibido = 0;
      final sink = archivo.openWrite();
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        recibido += chunk.length;
        if (total > 0) onProgreso?.call(recibido / total);
      }
      await sink.close();

      final resultado = await OpenFilex.open(archivo.path);
      return resultado.type == ResultType.done;
    } catch (_) {
      return false;
    }
  }

  Future<void> comprobarYMostrar(BuildContext context) async {
    final info = await comprobar();
    if (info == null || !context.mounted) return;
    await _mostrarDialogoDescarga(context, info, obligatoria: info.obligatoria);
  }

  Future<void> comprobarYMostrarUrl(
    BuildContext context, {
    required String apkUrl,
    String mensaje = '',
  }) async {
    if (apkUrl.trim().isEmpty || kIsWeb) return;
    final info = InfoActualizacion(
      version: '',
      build: 999999,
      apkUrl: apkUrl.trim(),
      changelog: mensaje,
      obligatoria: true,
    );
    if (!context.mounted) return;
    await _mostrarDialogoDescarga(context, info, obligatoria: false, mensaje: mensaje);
  }

  Future<void> _mostrarDialogoDescarga(
    BuildContext context,
    InfoActualizacion info, {
    bool obligatoria = false,
    String mensaje = '',
  }) async {
    final texto = mensaje.isEmpty
        ? (info.changelog.isEmpty
            ? 'Hay una nueva versión de Flumi. ¿Quieres actualizar ahora?'
            : info.changelog)
        : mensaje;

    final descargar = await showDialog<bool>(
      context: context,
      barrierDismissible: !obligatoria,
      builder: (ctx) => AlertDialog(
        title: const Text('Actualización disponible'),
        content: SingleChildScrollView(child: Text(texto)),
        actions: [
          if (!obligatoria)
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Más tarde'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
    if (descargar != true || !context.mounted) return;

    double progreso = 0;
    void Function(void Function())? setStateDialog;
    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          setStateDialog = setState;
          return AlertDialog(
            title: const Text('Descargando actualización'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: progreso == 0 ? null : progreso),
                const SizedBox(height: 8),
                Text('${(progreso * 100).toStringAsFixed(0)}%'),
              ],
            ),
          );
        },
      ),
    );

    final ok = await descargarEInstalar(
      info,
      onProgreso: (p) {
        progreso = p;
        setStateDialog?.call(() {});
      },
    );

    if (context.mounted) navigator.pop();
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo instalar la actualización.')),
      );
    }
  }
}
