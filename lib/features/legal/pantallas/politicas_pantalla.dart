import 'package:flutter/material.dart';

class PoliticasPantalla extends StatelessWidget {
  const PoliticasPantalla({super.key});

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Políticas de Privacidad'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Políticas de Privacidad',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primario,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Última actualización: Octubre 2026',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const Divider(height: 32),
            _seccion(
              '1. Información que Recopilamos',
              'Recopilamos la información que nos proporcionas directamente al registrarte y '
                  'usar la Aplicación: nombre, correo electrónico, fecha de nacimiento, género, '
                  'preferencias, fotos, biografía y ubicación (incluida su actualización cuando '
                  'usas la app para mostrarte personas cerca de ti). Para verificar pagos, con tu '
                  'permiso leemos los SMS de confirmación de PAGOxMOVIL y ENZONA (solo número, '
                  'monto, remitente y fecha de la transacción) y guardamos el Nro. de transacción '
                  'que introduces. Para verificar tu cuenta usamos la selfie que tomas con tu '
                  'cámara frontal. También recogemos datos técnicos básicos (notificaciones, '
                  'versión de la app) para su funcionamiento.',
            ),
            _seccion(
              '2. Cómo Usamos tu Información',
              'Usamos tu información para: (a) crear y mantener tu perfil; (b) mostrarte '
                  'perfiles compatibles según tus preferencias; (c) permitir la comunicación '
                  'entre usuarios; (d) activar tus suscripciones y verificar tus pagos; '
                  '(e) revisar reportes y garantizar la seguridad de la comunidad; '
                  '(f) enviarte notificaciones sobre actividad relevante.',
            ),
            _seccion(
              '3. Compartición de Datos',
              'No vendemos tu información personal a terceros. Tu perfil es visible para '
                  'otros usuarios registrados según tus preferencias de privacidad. Los SMS '
                  'leídos y las selfies de verificación solo se usan para el fin descrito y '
                  'no se comparten.',
            ),
            _seccion(
              '4. Seguridad',
              'Implementamos medidas de seguridad técnicas y organizativas para proteger '
                  'tus datos personales contra acceso no autorizado, pérdida o alteración.',
            ),
            _seccion(
              '5. Retención de Datos',
              'Conservamos tus datos mientras tengas una cuenta activa. Si eliminas tu '
                  'cuenta, tus datos se eliminan en un plazo de 30 días, excepto cuando '
                  'la ley requiera su retención.',
            ),
            _seccion(
              '6. Tus Derechos',
              'Tienes derecho a acceder, rectificar o eliminar tus datos personales en '
                  'cualquier momento desde la configuración de tu perfil. Puedes desactivar '
                  'los permisos de ubicación, cámara, SMS y notificaciones desde los ajustes '
                  'de tu teléfono (algunas funciones dejarán de estar disponibles).',
            ),
            _seccion(
              '7. Menores de Edad',
              'Flumi es solo para mayores de 18 años. Si detectamos una cuenta de un menor, '
                  'la eliminamos. Si eres padre o tutor y lo sospechas, repórtalo desde '
                  'Ayuda y soporte.',
            ),
            _seccion(
              '8. Cambios a esta Política',
              'Te notificaremos sobre cambios significativos a través de la Aplicación.',
            ),
            _seccion(
              '9. Contacto',
              'Si tienes preguntas sobre esta Política de Privacidad, contáctanos a '
                  'través de Ayuda y soporte en la Aplicación.',
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _seccion(String titulo, String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            texto,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
