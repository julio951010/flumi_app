-- ============================================================
-- HARDENING SEGURO · Flumi
-- Cambios SOLO de servidor: no requieren compilar ni reinstalar la app,
-- y no alteran ninguna firma de función, política RLS ni columna.
-- Idempotente: se puede ejecutar varias veces.
--
-- ESTADO 2026-11-18 — YA APLICADO en Flumi_App (gzozmebdrsdcupgvxuiv):
--   [x] Índices en FKs          -> 0 FKs sin índice
--   [x] Revoke anon             -> anon solo ejecuta email_existe,
--                                  es_admin y registrar_instalacion
--   [x] Revoke en triggers      -> verificado con una prueba aislada:
--                                  Postgres NO comprueba EXECUTE al
--                                  disparar un trigger, solo al invocarlo
--   [x] search_path en 7        -> proconfig fijado
--   [ ] spatial_ref_sys         -> imposible: la tabla es de la extensión
--   [ ] Contraseñas filtradas   -> requiere plan Pro (402 entitlement)
--
-- Este archivo queda como registro histórico. La versión reproducible vive
-- en supabase/schema.sql (bloque "HARDENING DE PERMISOS" al final).
--
-- Qué hace:
--   1. Índices en las 10 FKs que no tenían índice  (rendimiento puro).
--   2. Quita a `anon` el EXECUTE de las funciones RPC que la app solo
--      llama con sesión. Deja las 3 que sí se usan sin sesión.
--   3. Fija `search_path` en las 7 funciones que lo tenían mutable.
--   4. Activa RLS en `spatial_ref_sys` (PostGIS) con lectura pública.
--
-- Qué NO hace (a propósito, para no romper nada):
--   · No reescribe políticas RLS existentes.
--   · No fusiona políticas duplicadas.
--   · No borra tablas ni columnas (`reports` vs `reportes`, `profiles.edad`).
--   · No cambia firmas de funciones ni permisos de `authenticated`/`service_role`.
--
-- Ejecutar en: Supabase Dashboard -> SQL Editor -> New query.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1. ÍNDICES EN FKs SIN ÍNDICE
-- ------------------------------------------------------------
create index if not exists idx_device_tokens_usuario_id
  on public.device_tokens (usuario_id);

create index if not exists idx_rechazos_rechazado_id
  on public.rechazos (rechazado_id);

create index if not exists idx_blocks_bloqueado_id
  on public.blocks (bloqueado_id);

create index if not exists idx_conversaciones_leidas_otro_usuario_id
  on public.conversaciones_leidas (otro_usuario_id);

create index if not exists idx_historial_likes_usuario_likeado_id
  on public.historial_likes (usuario_likeado_id);

create index if not exists idx_chat_solicitudes_emisor_id
  on public.chat_solicitudes (emisor_id);

create index if not exists idx_chat_solicitudes_receptor_id
  on public.chat_solicitudes (receptor_id);

create index if not exists idx_messages_receptor_id
  on public.messages (receptor_id);

-- `reports` y `reportes` conviven (una está vacía). Se indexan solo si la
-- tabla y la columna existen, así el script nunca falla.
do $$
declare
  r record;
begin
  for r in
    select * from (values
      ('reports',  'reportado_id'),
      ('reports',  'reportante_id'),
      ('reportes', 'reportado_id'),
      ('reportes', 'reportante_id')
    ) as t(tabla, columna)
  loop
    if exists (
      select 1 from information_schema.columns
       where table_schema = 'public'
         and table_name  = r.tabla
         and column_name = r.columna
    ) then
      execute format(
        'create index if not exists %I on public.%I (%I)',
        'idx_' || r.tabla || '_' || r.columna, r.tabla, r.columna
      );
    end if;
  end loop;
end $$;

-- ------------------------------------------------------------
-- 2. `anon` YA NO PUEDE EJECUTAR RPCs INTERNAS
-- ------------------------------------------------------------
-- La app solo llama sin sesión a:
--   · email_existe         (validación en la pantalla de registro)
--   · registrar_instalacion (ping anónimo al arrancar)
--   · es_admin              (inocua: para anon devuelve false; la usan
--                            políticas/panel y se deja por seguridad)
-- Todo lo demás se llama con sesión (`authenticated`), así que quitarle
-- el permiso a `anon` no cambia nada para los usuarios reales.
--
-- NO se toca `authenticated` ni `service_role`, ni las funciones que
-- pertenecen a extensiones (PostGIS, pgcrypto, etc.).
do $$
declare
  r record;
  v_n int := 0;
begin
  for r in
    select p.oid::regprocedure as sig, p.proname
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.prokind = 'f'
       and p.proname not in ('email_existe', 'registrar_instalacion', 'es_admin')
       and not exists (
         select 1
           from pg_depend d
          where d.objid = p.oid
            and d.deptype = 'e'          -- función propiedad de una extension
       )
       and has_function_privilege('anon', p.oid, 'execute')
  loop
    execute format('revoke execute on function %s from anon', r.sig);
    v_n := v_n + 1;
  end loop;

  raise notice 'RPCs sin acceso para anon: %', v_n;
end $$;

-- ------------------------------------------------------------
-- 3. `search_path` FIJO (7 funciones)
-- ------------------------------------------------------------
-- ALTER FUNCTION solo agrega la configuración: NO reescribe el cuerpo ni
-- la firma. En estas 7 funciones todas las referencias son a `public` o
-- están calificadas, así que el resultado es idéntico.
do $$
declare
  r record;
  v_n int := 0;
begin
  for r in
    select p.oid::regprocedure as sig
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname in (
         'sync_ubicacion',
         'validar_ubicacion_perfil',
         'validar_genero_perfil',
         'bloquear_respuesta_bots',
         'normalizar_genero',
         'cumple_genero',
         'perfiles_cercanos'
       )
       and not exists (
         select 1 from unnest(coalesce(p.proconfig, '{}'::text[])) c
          where c like 'search_path=%'
       )
  loop
    execute format('alter function %s set search_path = public', r.sig);
    v_n := v_n + 1;
  end loop;

  raise notice 'Funciones con search_path fijado: %', v_n;
end $$;

-- ------------------------------------------------------------
-- 4. RLS EN spatial_ref_sys (PostGIS)  ->  NO APLICABLE
-- ------------------------------------------------------------
-- En este proyecto la tabla pertenece a la extensión (owner:
-- supabase_admin), así que `alter table ... enable row level security`
-- falla con "must be owner". No se puede arreglar desde el SQL Editor con
-- el rol `postgres`.
--
-- Riesgo real: NULO. Es el catálogo de referencia EPSG (solo lectura, sin
-- datos de usuarios) y PostGIS la lee con privilegios de la extensión. La
-- única salida sería mover PostGIS a otro schema, que sí es un cambio con
-- riesgo y cero beneficio. Se deja como está a propósito.
--
-- (Bloque original, conservado para referencia:)
-- do $$
-- begin
--   if to_regclass('public.spatial_ref_sys') is not null then
--     execute 'alter table public.spatial_ref_sys enable row level security';
--     execute 'drop policy if exists "spatial_ref_sys_lectura" on public.spatial_ref_sys';
--     execute 'create policy "spatial_ref_sys_lectura" on public.spatial_ref_sys for select using (true)';
--   end if;
-- end $$;

commit;

-- PostgREST cachea privilegios: recargar el esquema.
notify pgrst, 'reload schema';

-- ============================================================
-- VERIFICACIÓN (opcional, ejecutar después)
-- ============================================================
-- 1) Funciones que anon todavía puede ejecutar: debe devolver solo
--    email_existe, registrar_instalacion y es_admin.
-- select p.proname
--   from pg_proc p
--   join pg_namespace n on n.oid = p.pronamespace
--  where n.nspname = 'public'
--    and has_function_privilege('anon', p.oid, 'execute')
--  order by 1;
--
-- 2) Funciones de public sin search_path fijo: debe devolver 0 filas.
-- select p.proname
--   from pg_proc p
--   join pg_namespace n on n.oid = p.pronamespace
--  where n.nspname = 'public'
--    and p.prosecdef
--    and not exists (select 1 from unnest(coalesce(p.proconfig,'{}'::text[])) c
--                     where c like 'search_path=%');
--
-- 3) RLS en tablas de public sin RLS (debe quedar solo lo intencional):
-- select relname from pg_class c
--   join pg_namespace n on n.oid = c.relnamespace
--  where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;
