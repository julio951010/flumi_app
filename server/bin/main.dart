import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../lib/database.dart';
import '../lib/auth_handler.dart';
import '../lib/profiles_handler.dart';
import '../lib/messages_handler.dart';
import '../lib/matches_handler.dart';
import '../lib/reports_handler.dart';
import '../lib/blocks_handler.dart';

Future<void> main() async {
  final db = await DatabaseManager.create();
  await db.setupSchema();
  await db.seedData();

  final authHandler = AuthHandler(db);
  final profilesHandler = ProfilesHandler(db);
  final messagesHandler = MessagesHandler(db);
  final matchesHandler = MatchesHandler(db);
  final reportsHandler = ReportsHandler(db);
  final blocksHandler = BlocksHandler(db);

  final app = Router()
    ..post('/api/auth/signup', authHandler.signup)
    ..post('/api/auth/login', authHandler.login)
    ..post('/api/auth/logout', authHandler.logout)
    ..get('/api/auth/user', authHandler.getUser)
    ..post('/api/auth/recover', authHandler.recover)
    ..post('/api/auth/reset-password/<token>', authHandler.resetPassword)
    ..post('/api/auth/update-password', authHandler.updatePassword)
    ..get('/api/profiles', profilesHandler.list)
    ..get('/api/profiles/<id>', profilesHandler.get)
    ..put('/api/profiles/<id>', profilesHandler.update)
    ..get('/api/messages', messagesHandler.list)
    ..post('/api/messages', messagesHandler.create)
    ..put('/api/messages/<id>', messagesHandler.markRead)
    ..get('/api/matches', matchesHandler.list)
    ..post('/api/matches', matchesHandler.create)
    ..get('/api/reports', reportsHandler.list)
    ..post('/api/reports', reportsHandler.create)
    ..get('/api/blocks', blocksHandler.list)
    ..post('/api/blocks', blocksHandler.create)
    ..delete('/api/blocks/<id>', blocksHandler.remove)
    ..get('/api/health', (req) => Response.ok('{"status":"ok"}', headers: {'content-type': 'application/json'}));

  final corsMiddleware = createMiddleware(
    requestHandler: (req) {
      if (req.method == 'OPTIONS') {
        return Response.ok(null, headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        });
      }
      return null;
    },
    responseHandler: (res) => res.change(headers: {
      'Access-Control-Allow-Origin': '*',
    }),
  );

  final handler = const Pipeline()
      .addMiddleware(corsMiddleware)
      .addMiddleware(logRequests())
      .addHandler(app);

  final host = Platform.environment['HOST'] ?? '0.0.0.0';
  final port = int.tryParse(Platform.environment['PORT'] ?? '8081') ?? 8081;

  final server = await shelf_io.serve(handler, host, port);
  print('Flumi local server running at http://${server.address.host}:${server.port}');
  print('Database: postgresql://postgres:****@localhost:5432/flumi_dev');
}
