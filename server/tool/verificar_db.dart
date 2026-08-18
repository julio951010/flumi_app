import 'package:postgres/postgres.dart';

Future<void> main() async {
  final conn = await Connection.open(
    Endpoint(
      host: 'localhost',
      port: 5432,
      database: 'flumi_dev',
      username: 'postgres',
      password: 'jchd',
    ),
    settings: ConnectionSettings(sslMode: SslMode.disable),
  );

  try {
    final perfiles = await conn.execute(Sql.named('''
      select p.id, p.nombre, p.genero, p.busca_genero,
             p.fecha_nacimiento, p.preferencia_edad_min, p.preferencia_edad_max,
             p.ubicacion_lat, p.ubicacion_lon
      from flumi.profiles p
      order by p.nombre
    '''));

    print('==== PERFILES ====');
    for (final r in perfiles) {
      final m = r.toColumnMap();
      print(
          '${m['nombre']} | genero=${m['genero']} | busca=${m['busca_genero']} '
          '| fechanac=${m['fecha_nacimiento']} | prefiere=${m['preferencia_edad_min']}-${m['preferencia_edad_max']} '
          '| lat=${m['ubicacion_lat']} lon=${m['ubicacion_lon']} | id=${m['id']}');
    }

    final ids = <String, String>{};
    for (final r in perfiles) {
      final m = r.toColumnMap();
      ids[m['nombre'] as String] = m['id'] as String;
    }

    Future<void> consultar(String etiqueta, String sql) async {
      final rows = await conn.execute(Sql.named(sql));
      print('\n==== $etiqueta ====');
      if (rows.isEmpty) {
        print('(sin filas)');
        return;
      }
      for (final r in rows) {
        print((r.toColumnMap()).toString());
      }
    }

    final yumilka = ids['Yumilka'] ?? ids.values.firstWhere(
        (id) => true, orElse: () => '');
    for (final entry in ids.entries) {
      if (entry.key == 'Yumilka' || entry.key == 'Pedro') {
        final esYumilka = entry.key == 'Yumilka';
        await consultar('$entry.key -> rechazos (salientes y entrantes)',
            'select * from flumi.rechazos where usuario_id = @id or rechazado_id = @id'.replaceAll(
                '@id', "'${entry.value}'"));
        await consultar('$entry.key -> historial_likes (en ambos sentidos)',
            'select * from flumi.historial_likes where usuario_id = @id or usuario_likeado_id = @id'.replaceAll(
                '@id', "'${entry.value}'"));
      }
    }

    await consultar('matches (todos)',
        'select * from flumi.matches');
  } finally {
    await conn.close();
  }
}