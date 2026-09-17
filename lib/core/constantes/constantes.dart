export 'config.dart';

const String appNombre = 'Flumi';
const String appTagline = 'Deja que todo fluya';

const int sincronizacionIntentosMaximos = 5;
const int feedRadioMetrosDefault = 20000;

const String tablaProfiles = 'profiles';
const String tablaMessages = 'messages';
const String tablaMatches = 'matches';
const String tablaReports = 'reports';
const String tablaBlocks = 'blocks';
const String tablaConversacionesBorradas = 'conversaciones_borradas';

/// Cuentas de sistema de Flumi. No tienen perfil local en la BD, así que su
/// nombre se resuelve desde aquí al armar la lista/chat de conversaciones y
/// al notificar. El ID mapea al nombre visible para el usuario.
const Map<String, String> cuentasOficialesFlumi = {
  '00000000-0000-0000-0000-00000000000a': 'Administrador',
  '00000000-0000-0000-0000-00000000000f': 'Flumi',
};

/// Avatares de las cuentas de sistema (mismos IDs que [cuentasOficialesFlumi]).
const Map<String, String> fotosOficialesFlumi = {
  '00000000-0000-0000-0000-00000000000a': 'assets/images/admin_flumi_avatar.png',
  '00000000-0000-0000-0000-00000000000f': 'assets/images/flumi_avatar.png',
};

/// true si el ID corresponde a una cuenta oficial de sistema (Administrador
/// o Flumi). Estas conversaciones se abren sin importar el plan del usuario.
bool esCuentaOficial(String id) => cuentasOficialesFlumi.containsKey(id);
