import 'package:flutter/material.dart';

class TerminosPantalla extends StatelessWidget {
  const TerminosPantalla({super.key});

  @override
  Widget build(BuildContext context) {
    final primario = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Términos y Condiciones'),
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
              'Términos y Condiciones de Uso',
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
              '1. Aceptación de los Términos',
              'Al registrarte y usar Flumi ("la Aplicación"), aceptas los presentes Términos y '
                  'Condiciones. Si no estás de acuerdo con alguna parte, no debes usar la Aplicación.',
            ),
            _seccion(
              '2. Elegibilidad',
              'Debes tener al menos 18 años para usar la Aplicación. Al registrarte, declaras '
                  'y garantizas que cumples con este requisito.',
            ),
            _seccion(
              '3. Registro y Cuenta',
              'Eres responsable de mantener la confidencialidad de tus credenciales de inicio '
                  'de sesión. No debes compartir tu cuenta con terceros.',
            ),
            _seccion(
              '4. Suscripciones y Pagos',
              'Flumi ofrece los planes Gratis, Plus y Premium por períodos de 7, 30 o 90 días. '
                  'Los planes de pago se contratan con pago manual por Transfermóvil o EnZona: '
                  'tras pagar, introduces el Nro. de transacción del SMS de confirmación. Si los '
                  'datos coinciden, tu plan se activa automáticamente; si no, queda en verificación '
                  'manual (menos de 24 horas). No hay renovación automática: cada período se paga '
                  'por separado. Si un pago no se acredita, contáctanos desde Ayuda y soporte.',
            ),
            _seccion(
              '5. Verificación de Cuenta',
              'Puedes verificar tu cuenta con una selfie tomada con tu cámara frontal. La '
                  'revisión es manual y tienes 3 intentos cada 24 horas. Las cuentas verificadas '
                  'reciben una insignia y más visibilidad. La verificación confirma que hay una '
                  'persona real detrás del perfil, pero no garantiza la identidad ni la conducta '
                  'de ningún usuario.',
            ),
            _seccion(
              '6. Conducta del Usuario',
              'No está permitido: (a) acosar, abusar o dañar a otros usuarios; (b) publicar '
                  'contenido falso, inapropiado o engañoso; (c) usar la Aplicación para fines '
                  'ilegales o no autorizados; (d) crear perfiles falsos o suplantar a otros. '
                  'Puedes reportar y bloquear perfiles desde la propia Aplicación.',
            ),
            _seccion(
              '7. Moderación y Terminación',
              'Revisamos los reportes de la comunidad. Podemos ocultar perfiles, eliminar '
                  'contenido o terminar cuentas que incumplan estos Términos, sin previo aviso '
                  'en casos graves. Los perfiles con múltiples reportes pendientes pueden '
                  'ocultarse automáticamente hasta su revisión.',
            ),
            _seccion(
              '8. Contenido del Usuario',
              'Eres el único responsable de las fotos, información y contenido que publiques '
                  'en tu perfil. Al subirlo, nos otorgas una licencia gratuita para mostrarlo '
                  'dentro de la Aplicación. Nos reservamos el derecho de eliminar contenido '
                  'inapropiado.',
            ),
            _seccion(
              '9. Encuentros en Persona',
              'Flumi no verifica los antecedentes de sus usuarios ni supervisa los encuentros. '
                  'Si decides conocer a alguien en persona, hazlo en lugares públicos y avisa '
                  'a una persona de tu confianza.',
            ),
            _seccion(
              '10. Privacidad',
              'El uso de tus datos personales se rige por nuestras Políticas de Privacidad, '
                  'las cuales forman parte integral de estos Términos.',
            ),
            _seccion(
              '11. Limitación de Responsabilidad',
              'Flumi no se hace responsable por daños directos o indirectos derivados del uso '
                  'de la Aplicación, incluyendo pero no limitado a encuentros entre usuarios.',
            ),
            _seccion(
              '12. Modificaciones',
              'Nos reservamos el derecho de modificar estos Términos en cualquier momento. '
                  'Te notificaremos sobre cambios significativos a través de la Aplicación.',
            ),
            _seccion(
              '13. Contacto',
              'Para preguntas sobre estos Términos, contáctanos a través de Ayuda y soporte '
                  'en la Aplicación.',
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
