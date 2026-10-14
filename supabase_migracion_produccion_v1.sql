-- ============================================================
-- FLUMI APP v1.0.0 — Migración consolidada de producción
-- Ejecutar UNA VEZ en Supabase Dashboard → SQL Editor.
-- Idempotente: se puede re-ejecutar sin error ni duplicados.
-- Orden: (1) columnas/tablas, (2) RLS, (3) realtime, (4) seeds.
-- ============================================================

-- ------------------------------------------------------------
-- 1) profiles.ocultar_ubicacion (privacidad "Mostrar mi ubicación")
-- ------------------------------------------------------------
alter table public.profiles
  add column if not exists ocultar_ubicacion boolean default false;

COMMENT ON COLUMN public.profiles.ocultar_ubicacion IS
  'true = otros no ven mi ciudad ni mi distancia (Cerca de ti / detalle)';

-- ------------------------------------------------------------
-- 2) messages.reply_to (respuestas estilo WhatsApp/Telegram)
--    FK con ON DELETE SET NULL: borrar el mensaje citado no bloquea
--    el borrado; las respuestas quedan con reply_to = null.
-- ------------------------------------------------------------
ALTER TABLE messages ADD COLUMN IF NOT EXISTS reply_to UUID;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'messages_reply_to_fkey') THEN
    ALTER TABLE messages DROP CONSTRAINT messages_reply_to_fkey;
  END IF;
END $$;
ALTER TABLE messages ADD CONSTRAINT messages_reply_to_fkey
  FOREIGN KEY (reply_to) REFERENCES messages(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_messages_reply_to ON messages(reply_to);

COMMENT ON COLUMN messages.reply_to IS
  'UUID del mensaje al que se responde (para respuestas estilo WhatsApp/Telegram)';

-- ------------------------------------------------------------
-- 3) notificaciones_vistas (badges cross-device)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notificaciones_vistas (
  usuario_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  notificacion_id text NOT NULL,
  visto_en timestamptz DEFAULT now(),
  PRIMARY KEY (usuario_id, notificacion_id)
);

ALTER TABLE notificaciones_vistas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "own_vistas_select" ON notificaciones_vistas;
CREATE POLICY "own_vistas_select" ON notificaciones_vistas
  FOR SELECT TO authenticated USING (usuario_id = auth.uid());

DROP POLICY IF EXISTS "own_vistas_insert" ON notificaciones_vistas;
CREATE POLICY "own_vistas_insert" ON notificaciones_vistas
  FOR INSERT TO authenticated WITH CHECK (usuario_id = auth.uid());

DROP POLICY IF EXISTS "own_vistas_upsert" ON notificaciones_vistas;
CREATE POLICY "own_vistas_upsert" ON notificaciones_vistas
  FOR UPDATE TO authenticated USING (usuario_id = auth.uid()) WITH CHECK (usuario_id = auth.uid());

DROP POLICY IF EXISTS "own_vistas_delete" ON notificaciones_vistas;
CREATE POLICY "own_vistas_delete" ON notificaciones_vistas
  FOR DELETE TO authenticated USING (usuario_id = auth.uid());

CREATE INDEX IF NOT EXISTS idx_notificaciones_vistas_usuario ON notificaciones_vistas (usuario_id);

COMMENT ON COLUMN notificaciones_vistas.notificacion_id IS
  'Formato: <tipo>:<referencia_id>:<timestamp_ms>. Tipos: soporte, mensaje, like, visita, match, sistema';

-- ------------------------------------------------------------
-- 4) RLS: el usuario puede borrar SUS visitas salientes
--    (activar "Ocultar visitas" borra el historial pasado)
-- ------------------------------------------------------------
drop policy if exists "usuario_borra_sus_visitas" on public.visitas;
create policy "usuario_borra_sus_visitas"
  on public.visitas for delete
  using (auth.uid() = visitante_id);

-- ------------------------------------------------------------
-- 5) redes_sociales (Nuestras redes: app lee, admin_flumi escribe)
-- ------------------------------------------------------------
create table if not exists public.redes_sociales (
  id uuid primary key default uuid_generate_v4(),
  nombre text not null default '',
  usuario text not null default '',
  url text not null default '',
  icono text not null default 'web',
  orden int not null default 0,
  activo boolean not null default true,
  actualizado_en timestamptz not null default now()
);

alter table public.redes_sociales enable row level security;

drop policy if exists "redes_lectura" on public.redes_sociales;
create policy "redes_lectura"
  on public.redes_sociales for select
  using (auth.role() = 'authenticated');

drop policy if exists "redes_admin" on public.redes_sociales;
create policy "redes_admin"
  on public.redes_sociales for all
  using (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true))
  with check (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true));

-- ------------------------------------------------------------
-- 6) app_config: claves de Sobre nosotros + whitelist de lectura
-- ------------------------------------------------------------
insert into public.app_config (clave, valor, tipo)
values
  ('invitacion_mensaje', 'Déjate llevar por la corriente con Flumi, la app cubana para conocer personas', 'config'),
  ('descarga_url', '', 'config'),
  ('valorar_url', '', 'config'),
  ('donacion_mensaje', 'Tu apoyo mantiene Flumi en línea. ¡Gracias por donar!', 'config'),
  ('donacion_cuenta', '', 'config'),
  ('donacion_telefono', '', 'config'),
  ('mostrar_invitar', 'true', 'config'),
  ('mostrar_valorar', 'true', 'config'),
  ('mostrar_descargar', 'true', 'config'),
  ('mostrar_donar', 'true', 'config')
on conflict (clave) do nothing;

drop policy if exists "app_config_flag_publica" on public.app_config;
create policy "app_config_flag_publica"
  on public.app_config for select
  to authenticated
  using (clave in ('suscripciones_habilitadas', 'mantenimiento',
    'mantenimiento_mensaje', 'version_minima_build', 'actualizar_url',
    'actualizar_mensaje', 'invitacion_mensaje', 'descarga_url',
    'valorar_url', 'donacion_mensaje', 'donacion_cuenta',
    'donacion_telefono', 'mostrar_invitar', 'mostrar_valorar',
    'mostrar_descargar', 'mostrar_donar'));

-- ------------------------------------------------------------
-- 7) Realtime: redes_sociales + contenidos_legales
-- ------------------------------------------------------------
do $$
begin
  if to_regclass('public.redes_sociales') is not null
     and not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'redes_sociales'
  ) then
    alter publication supabase_realtime add table public.redes_sociales;
  end if;
end $$;

do $$
begin
  if to_regclass('public.contenidos_legales') is not null
     and not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'contenidos_legales'
  ) then
    alter publication supabase_realtime add table public.contenidos_legales;
  end if;
end $$;

-- ------------------------------------------------------------
-- 8) Seed redes iniciales (solo si la tabla está vacía)
-- ------------------------------------------------------------
insert into public.redes_sociales (nombre, usuario, url, icono, orden, activo)
select * from (values
  ('Telegram', '@flumi', 'https://t.me/flumi', 'telegram', 1, true),
  ('WhatsApp', '+53 5 123 45 67', 'https://wa.me/5351234567', 'whatsapp', 2, true),
  ('Instagram', '@flumi.app', 'https://instagram.com/flumi.app', 'instagram', 3, true)
) as v(nombre, usuario, url, icono, orden, activo)
where not exists (select 1 from public.redes_sociales);
