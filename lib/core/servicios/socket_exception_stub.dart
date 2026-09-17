/// Stub web de [SocketException]: en web no existe [dart:io], pero la
/// comprobación `error is SocketException` debe compilar. Nunca coincide en
/// web (las fallas de red se reportan como [http.ClientException]).
class SocketException implements Exception {}
