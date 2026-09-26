import 'package:flutter/material.dart';

import '../../../core/estilos/tema.dart';
import 'contactar_soporte_pantalla.dart';

class AyudaSoportePantalla extends StatelessWidget {
  const AyudaSoportePantalla({super.key});

  static const _faqs = <({String pregunta, String respuesta})>[
    (
      pregunta: '¿Cómo pago mi suscripción?',
      respuesta:
          'Ve a Perfil > tu plan > Cambiar de plan, elige Plus o Premium y los días (7, 30 o 90). Paga con Transfermóvil o EnZona usando los datos exactos que te mostramos y luego introduce el Nro. de transacción del SMS de confirmación. Si todo coincide, tu plan se activa automáticamente; si no, queda en verificación (menos de 24h).'
    ),
    (
      pregunta: '¿Por qué mi pago está "En verificación"?',
      respuesta:
          'La verificación automática necesita el SMS de PAGOxMOVIL o ENZONA en tu teléfono y que el Nro., el monto y la tarjeta coincidan. Si algo no coincide (o no diste permiso de SMS), un administrador lo revisa manualmente en menos de 24 horas. Puedes ver el estado en Administrar suscripción > Historial de pagos.'
    ),
    (
      pregunta: '¿Cómo verifico mi cuenta?',
      respuesta:
          'Ve a Perfil > Verificación de cuenta y sigue los pasos con tu cámara frontal. Tienes 3 intentos cada 24 horas. La verificación te da la insignia azul y más visibilidad.'
    ),
    (
      pregunta: '¿Cómo consigo más matches?',
      respuesta:
          'Completa tu perfil al 100% (fotos, biografía e intereses), verifica tu cuenta y usa los filtros de Encuentros. Los planes Plus y Premium multiplican tu alcance: más Me Gustas, Superlikes y perfiles en Cerca de ti.'
    ),
    (
      pregunta: '¿Cómo cancelo mi suscripción?',
      respuesta:
          'Ve a Configuración > Administrar suscripción > Cancelar suscripción. Volverás al plan Gratis al instante y podrás suscribirte de nuevo cuando quieras. Si cambias de plan con días restantes, esos días se pausan y continúan cuando el nuevo plan venza.'
    ),
    (
      pregunta: '¿Es seguro usar Flumi?',
      respuesta:
          'Nunca compartas tu PIN, códigos de tarjetas ni datos bancarios: Flumi solo te pide el Nro. público del comprobante de pago. Puedes bloquear y reportar perfiles desde el chat, y usar el Modo invisible (Premium) para ocultar tu perfil y tus visitas.'
    ),
    (
      pregunta: 'No recibo notificaciones, ¿qué hago?',
      respuesta:
          'Revisa que diste permiso de notificaciones al instalar, que esté activado en Ajustes > Notificaciones de tu teléfono, y tus preferencias en Configuración > Notificaciones. Si usas ahorro de batería agresivo, excluye a Flumi para recibir avisos en segundo plano.'
    ),
  ];

  void _contactarSoporte(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ContactarSoportePantalla(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Ayuda y soporte',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FlumiTema.colorPrimario.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: FlumiTema.colorPrimario,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.support_agent,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('¿Necesitas ayuda?',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      SizedBox(height: 2),
                      Text(
                        'Escríbenos y te respondemos lo antes posible.',
                        style:
                            TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _contactarSoporte(context),
              icon: const Icon(Icons.chat_outlined, size: 20),
              label: const Text('Contactar con soporte',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              style: FilledButton.styleFrom(
                backgroundColor: FlumiTema.colorPrimario,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Preguntas frecuentes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          for (final faq in _faqs)
            Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: ExpansionTile(
                shape: const Border(),
                title: Text(
                  faq.pregunta,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      faq.respuesta,
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
