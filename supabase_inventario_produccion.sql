-- ============================================================
-- Inventario de estado de producción (solo lectura, no cambia nada)
-- Ejecutar en Supabase Dashboard → SQL Editor y pegar TODO el resultado.
-- ============================================================

-- 1. Policies de storage para profile-photos (deben ser 5: 4 mías + admin)
select 'POLICIES_STORAGE' as bloque, policyname, cmd
from pg_policies
where schemaname = 'storage' and tablename = 'objects'
  and (qual ilike '%profile-photos%' or with_check ilike '%profile-photos%')
order by policyname;

-- 2. Columnas nuevas
select 'COLUMNAS' as bloque,
  (select count(*) from information_schema.columns where table_name = 'profiles' and column_name in ('ocultar_ubicacion','suspendido')) as profiles_ok_de_2,
  (select count(*) from information_schema.columns where table_name = 'messages' and column_name = 'reply_to') as messages_reply_to,
  (select count(*) from information_schema.columns where table_name = 'reports' and column_name in ('estado','resuelto_en')) as reports_ok_de_2;

-- 3. Tablas nuevas
select 'TABLAS' as bloque,
  (select count(*) from pg_tables where schemaname = 'public' and tablename in ('notificaciones_vistas','redes_sociales')) as tablas_ok_de_2;

-- 4. Claves app_config de Sobre nosotros (deben ser 10)
select 'APP_CONFIG' as bloque, count(*) as claves_ok_de_10
from public.app_config
where clave in ('invitacion_mensaje','descarga_url','valorar_url','donacion_mensaje','donacion_cuenta','donacion_telefono','mostrar_invitar','mostrar_valorar','mostrar_descargar','mostrar_donar');

-- 5. Realtime (deben salir las 2)
select 'REALTIME' as bloque, tablename
from pg_publication_tables
where pubname = 'supabase_realtime' and tablename in ('redes_sociales','contenidos_legales');

-- 6. FK reply_to con SET NULL (confdeltype debe ser 'n')
select 'FK_REPLY' as bloque, confdeltype as debe_ser_n
from pg_constraint where conname = 'messages_reply_to_fkey';

-- 7. Trigger sync estado reportes
select 'TRIGGER_REPORTES' as bloque, count(*) as debe_ser_1
from pg_trigger where tgname = 'trg_sync_reporte_estado';

-- 8. Policies admin en reports
select 'POLICIES_REPORTS' as bloque, policyname
from pg_policies
where schemaname = 'public' and tablename = 'reports'
  and policyname like '%admin%'
order by policyname;
