Future<List<String>> fotosMockDePrueba(String nombre) async {
  const carpetas = [
    'Alice',
    'Bob',
    'Carla',
    'David',
    'Elena',
    'Julio Cesar',
  ];
  final n = nombre.trim().toLowerCase();
  var carpeta = '';
  for (final c in carpetas) {
    if (c.toLowerCase() == n) {
      carpeta = c;
      break;
    }
  }
  if (carpeta.isEmpty) carpeta = carpetas.first;
  return [
    for (var i = 1; i <= 4; i++)
      'assets/fotos_prueba/${Uri.encodeComponent(carpeta)}/imagen$i.png',
  ];
}