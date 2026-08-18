// Facade: exporta la implementación según la plataforma.
export 'notificacion_navegador_web.dart'
    if (dart.library.io) 'notificacion_navegador_io.dart';