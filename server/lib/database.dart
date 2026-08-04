import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class DatabaseManager {
  final Connection connection;
  DatabaseManager(this.connection);

  static Future<DatabaseManager> create() async {
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
    return DatabaseManager(conn);
  }

  Future<void> setupSchema() async {
    await connection.execute('create schema if not exists flumi;');

    await connection.execute('''
      create table if not exists flumi.users (
        id text primary key,
        email text unique not null,
        password_hash text not null,
        nombre text not null default '',
        created_at timestamptz default now(),
        recovery_token text,
        recovery_token_expires_at timestamptz
      );
    ''');

    await connection.execute('''
      create table if not exists flumi.profiles (
        id text primary key references flumi.users(id) on delete cascade,
        nombre text not null,
        fecha_nacimiento date,
        biografia text default '',
        fotos_urls text[] default '{}',
        preferencia_edad_min int default 18,
        preferencia_edad_max int default 99,
        genero text default 'otro',
        busca_genero text default 'otro',
        ubicacion_lat double precision default 0,
        ubicacion_lon double precision default 0,
        verificado_status boolean default false,
        score_popularidad int default 0,
        ultima_conexion timestamptz default now(),
        creado_en timestamptz default now()
      );
    ''');

    await connection.execute('''
      create table if not exists flumi.matches (
        id text primary key,
        usuario_a_id text not null references flumi.profiles(id) on delete cascade,
        usuario_b_id text not null references flumi.profiles(id) on delete cascade,
        timestamp_match timestamptz default now(),
        unique (usuario_a_id, usuario_b_id)
      );
    ''');

    await connection.execute('''
      create table if not exists flumi.messages (
        id text primary key,
        emisor_id text not null references flumi.profiles(id) on delete cascade,
        receptor_id text not null references flumi.profiles(id) on delete cascade,
        contenido text not null,
        timestamp timestamptz default now(),
        estado_envio text default 'enviado'
      );
    ''');

    await connection.execute('''
      create table if not exists flumi.reports (
        id text primary key,
        reportante_id text not null references flumi.profiles(id) on delete cascade,
        reportado_id text not null references flumi.profiles(id) on delete cascade,
        motivo text not null,
        detalle text default '',
        timestamp timestamptz default now(),
        revisado boolean default false
      );
    ''');

    await connection.execute('''
      create table if not exists flumi.blocks (
        id text primary key,
        bloqueador_id text not null references flumi.profiles(id) on delete cascade,
        bloqueado_id text not null references flumi.profiles(id) on delete cascade,
        timestamp timestamptz default now(),
        unique (bloqueador_id, bloqueado_id)
      );
    ''');
  }

  Future<void> seedData() async {
    final existing = await connection.execute(
      'select count(*) as cnt from flumi.profiles',
    );
    final count = existing.first.toColumnMap()['cnt'] as int;
    if (count > 0) return;

    final users = [
      {'id': _uuid.v4(), 'email': 'alice@test.com', 'password': 'test123', 'nombre': 'Alice', 'genero': 'mujer', 'busca': 'hombre', 'edad': 25, 'bio': 'Amante del café y los libros', 'lat': 19.4326, 'lon': -99.1332},
      {'id': _uuid.v4(), 'email': 'bob@test.com', 'password': 'test123', 'nombre': 'Bob', 'genero': 'hombre', 'busca': 'mujer', 'edad': 28, 'bio': 'Fotógrafo y viajero', 'lat': 19.4270, 'lon': -99.1670},
      {'id': _uuid.v4(), 'email': 'carla@test.com', 'password': 'test123', 'nombre': 'Carla', 'genero': 'mujer', 'busca': 'otro', 'edad': 22, 'bio': 'Música y cine', 'lat': 19.4200, 'lon': -99.1500},
      {'id': _uuid.v4(), 'email': 'david@test.com', 'password': 'test123', 'nombre': 'David', 'genero': 'hombre', 'busca': 'mujer', 'edad': 30, 'bio': 'Chef aficionado', 'lat': 19.4400, 'lon': -99.1200},
      {'id': _uuid.v4(), 'email': 'elena@test.com', 'password': 'test123', 'nombre': 'Elena', 'genero': 'mujer', 'busca': 'hombre', 'edad': 27, 'bio': 'Yoga y meditación', 'lat': 19.4150, 'lon': -99.1450},
    ];

    for (final u in users) {
      await connection.execute(
        Sql.named('insert into flumi.users (id, email, password_hash, nombre) values (@id, @email, @hash, @nombre)'),
        parameters: {
          'id': u['id'],
          'email': u['email'],
          'hash': _hashPassword(u['password'] as String),
          'nombre': u['nombre'],
        },
      );

      final fechaNac = '${DateTime.now().year - (u['edad'] as int)}-01-15';
      await connection.execute(
        Sql.named('''
          insert into flumi.profiles (id, nombre, fecha_nacimiento, biografia, genero, busca_genero, ubicacion_lat, ubicacion_lon, verificado_status, score_popularidad)
          values (@id, @nombre, @fecha, @bio, @genero, @busca, @lat, @lon, true, @score)
        '''),
        parameters: {
          'id': u['id'],
          'nombre': u['nombre'],
          'fecha': fechaNac,
          'bio': u['bio'],
          'genero': u['genero'],
          'busca': u['busca'],
          'lat': u['lat'],
          'lon': u['lon'],
          'score': 50 + (users.indexOf(u) * 10),
        },
      );
    }

    print('Seed data inserted: ${users.length} users');
  }

  Future<Map<String, dynamic>?> queryRow(String sql, {Map<String, dynamic>? parameters}) async {
    final query = parameters != null ? Sql.named(sql) : sql;
    final result = await connection.execute(query, parameters: parameters);
    if (result.isEmpty) return null;
    return result.first.toColumnMap();
  }

  Future<List<Map<String, dynamic>>> query(String sql, {Map<String, dynamic>? parameters}) async {
    final query = parameters != null ? Sql.named(sql) : sql;
    final result = await connection.execute(query, parameters: parameters);
    if (result.isEmpty) return [];
    return result.map((row) => row.toColumnMap()).toList();
  }
}

String _hashPassword(String password) {
  return sha256.convert(utf8.encode(password)).toString();
}
