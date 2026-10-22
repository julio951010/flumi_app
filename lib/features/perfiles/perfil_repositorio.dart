import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../config/env.dart';
import '../../core/base_datos_local/database.dart';
import '../../core/servicios/connectivity_service.dart';
import '../../core/servicios/sync_service.dart';
import '../../core/utilidades/app_log.dart';
import '../../core/utilidades/perfil_mapeo.dart';

class PerfilRepositorio {
  final AppDatabase _db;
  final SyncService _sync;

  final ValueNotifier<Usuario?> perfilPropio = ValueNotifier(null);

  /// Última vez que se leyó el perfil propio de la fuente de verdad, para no
  /// golpear la red en cada lectura (varias pantallas llaman a la vez).
  DateTime? _ultimoRefrescoRemoto;

  static const _frescuraMaxima = Duration(seconds: 15);

  PerfilRepositorio(this._db, this._sync);

  bool get _perfilFresco {
    final ahora = DateTime.now();
    if (_ultimoRefrescoRemoto == null) return false;
    return ahora.difference(_ultimoRefrescoRemoto!) < _frescuraMaxima;
  }

  /// Perfil propio online-first: la fuente de verdad es Supabase y la lectura
  /// es directa (sin pasar por colas de sincronización). La caché local solo
  /// es el espejo que consume el resto de la app. Sin red usa la caché.
  Future<Usuario?> obtenerPerfilPropio() async {
    if (_perfilFresco && perfilPropio.value != null) {
      return perfilPropio.value;
    }

    // Rama servidor local (legacy): se conserva la lectura por caché.
    if (kUsarServidorLocal) {
      return _leerPerfilLocal();
    }

    final id = sb.Supabase.instance.client.auth.currentUser?.id;
    if (id == null) {
      perfilPropio.value = null;
      return null;
    }

    if (ConnectivityService.instancia.hayConexion) {
      try {
        final remotoRpc = await sb.Supabase.instance.client
            .rpc('obtener_mi_perfil')
            .timeout(const Duration(seconds: 8));
        final remoto = (remotoRpc is List && remotoRpc.isNotEmpty)
            ? Map<String, dynamic>.from(remotoRpc.first as Map)
            : null;
        if (remoto != null) {
          // No pisar cambios locales pendientes (p. ej. interruptores de
          // privacidad recién movidos cuyo write-through falló): el remoto
          // trae valores viejos y el companion remoto además pone
          // pendienteDeSincronizar=false, lo que borraría la marca de
          // reintento y el cambio se perdería para siempre. El sync
          // (_sincronizarPerfilPropio) sube lo pendiente y resuelve.
          final conPendientes = await (_db.select(_db.usuarios)
                ..where((u) =>
                    u.esPerfilPropio.equals(true) &
                    u.pendienteDeSincronizar.equals(true)))
              .getSingleOrNull();
          if (conPendientes == null) {
            await _db.into(_db.usuarios).insertOnConflictUpdate(
                  PerfilMapeo.perfilRemotoACompanion(remoto, esPropio: true),
                );
            await _limpiarPerfilesDeOtrasCuentas(id);
          }
          final perfil = await _leerPerfilLocal(id);
          if (perfil != null) {
            _ultimoRefrescoRemoto = DateTime.now();
            perfilPropio.value = perfil;
            return perfil;
          }
        }
      } catch (_) {
        // Error de red o RLS: se continúa con la caché local.
      }
    }

    final perfil = await _leerPerfilLocal(id);
    if (perfil != null) {
      _ultimoRefrescoRemoto = DateTime.now();
      perfilPropio.value = perfil;
      return perfil;
    }

    // Sin caché: respaldo derivado del usuario autenticado (el trigger
    // handle_new_user ya crea el perfil remoto al registrarse).
    await _sync.asegurarPerfilPropio(id);
    final respaldo = await _leerPerfilLocal(id);
    perfilPropio.value = respaldo;
    return respaldo;
  }

  Future<Usuario?> obtenerPerfilPorUuid(String uuid) async {
    // Online-first sin bloquear: refresca el perfil remoto en segundo plano.
    if (ConnectivityService.instancia.hayConexion &&
        !_sync.estaSincronizando &&
        !_perfilFresco) {
      _ultimoRefrescoRemoto = DateTime.now();
      unawaited(_sync.refrescarPerfilRemoto(uuid));
    }
    return (_db.select(_db.usuarios)
          ..where((u) => u.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  /// Guarda el perfil escribiendo de inmediato en Supabase (fuente de verdad)
  /// y actualizando el espejo local. Sin red, queda local marcado pendiente
  /// para que la sincronización lo suba después.
  Future<void> guardarOCambiarPerfil(UsuariosCompanion perfil) async {
    final uuid = perfil.uuid.present ? perfil.uuid.value : null;
    if (uuid == null) {
      throw ArgumentError('Se requiere un uuid para guardar el perfil.');
    }

    final existe = await (_db.select(_db.usuarios)
          ..where((u) => u.uuid.equals(uuid)))
        .getSingleOrNull();

    final remoto = PerfilMapeo.perfilARemotoDesdeCompanion(perfil, base: existe);
    remoto['id'] = uuid;

    var pendiente = false;
    if (!kUsarServidorLocal && ConnectivityService.instancia.hayConexion) {
      try {
        await sb.Supabase.instance.client.from('profiles').upsert(remoto);
      } catch (e) {
        // Sin red (o RLS/CHECK): se queda marcado pendiente de sincronizar.
        appLog('[perfil] Error al subir el perfil: $e');
        pendiente = true;
      }
    } else {
      pendiente = true;
    }

    final uidActual = kUsarServidorLocal
        ? null
        : sb.Supabase.instance.client.auth.currentUser?.id;
    final esPropio = uuid == uidActual;

    var companion = PerfilMapeo.perfilRemotoACompanion(remoto, esPropio: esPropio)
        .copyWith(pendienteDeSincronizar: Value(pendiente));
    if (existe != null) {
      companion = companion.copyWith(creadoEn: Value(existe.creadoEn));
    }
    // fotosLocalesRutas (rutas de archivo en el dispositivo) es un campo
    // puramente local: no existe en Supabase, así que perfilRemotoACompanion
    // nunca lo incluye. Sin este parche, cada llamada a guardarOCambiarPerfil
    // reconstruye el companion desde la respuesta remota y pierde en
    // silencio cualquier actualización de fotosLocalesRutas que trajera el
    // companion original — causando que, al agregar una foto nueva, el
    // índice calculado para la siguiente terminara pisando una foto ya
    // existente en vez de sumarse como una nueva.
    companion = companion.copyWith(
      fotosLocalesRutas: perfil.fotosLocalesRutas.present
          ? perfil.fotosLocalesRutas
          : Value(existe?.fotosLocalesRutas ?? const []),
    );
    await _db.into(_db.usuarios).insertOnConflictUpdate(companion);

    final actualizado = await (_db.select(_db.usuarios)
          ..where((u) => u.uuid.equals(uuid)))
        .getSingleOrNull();
    if (actualizado != null && esPropio) {
      _ultimoRefrescoRemoto = DateTime.now();
      perfilPropio.value = actualizado;
    }
  }

  Future<Usuario?> _leerPerfilLocal([String? id]) async {
    if (!kUsarServidorLocal) {
      await _limpiarPerfilesDeOtrasCuentas(id);
    }
    return (_db.select(_db.usuarios)
          ..where((u) => u.esPerfilPropio.equals(true)))
        .getSingleOrNull();
  }

  /// Descarta en la caché local los perfiles propios que no correspondan a la
  /// cuenta autenticada (restos de otros logins), para que getSingleOrNull no
  /// lance MultipleResultException.
  Future<void> _limpiarPerfilesDeOtrasCuentas([String? id]) async {
    final uid = id ??
        (kUsarServidorLocal
            ? null
            : sb.Supabase.instance.client.auth.currentUser?.id);
    if (uid == null) return;
    await (_db.delete(_db.usuarios)
          ..where((u) =>
              u.esPerfilPropio.equals(true) & u.uuid.equals(uid).not()))
        .go();
  }
}