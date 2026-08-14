import 'package:flutter/foundation.dart';

class VotosServicio extends ChangeNotifier {
  final Set<String> _idsRechazados = {};

  bool esRechazado(String uuid) => _idsRechazados.contains(uuid);

  void registrarRechazo(String uuid) {
    if (!_idsRechazados.add(uuid)) return;
    notifyListeners();
  }

  void quitarRechazo(String uuid) {
    if (!_idsRechazados.remove(uuid)) return;
    notifyListeners();
  }
}