-- ============================================================
-- FIX: function public.enviar_push_pg is not unique (HTTP 400 en
-- POST /rest/v1/messages -> mensajes atascados en "enviando").
-- Causa: sobrecargas duplicadas en la BD remota (firmas viejas tipo
-- varchar vs text). CREATE OR REPLACE no las elimina, y el literal
-- 'mensajes' (tipo unknown) vuelve la llamada ambigua (code 42725).
-- Además los triggers no tenían guard: cualquier fallo de push rompía
-- el insert original.
--
-- USO: pegar TODO este archivo en Supabase Dashboard -> SQL Editor
-- y ejecutar. Luego verificar con el SELECT del paso 4 (1 sola fila)
-- y reenviar un mensaje desde la app.
-- ============================================================

-- 0. Diagnóstico (ver las firmas duplicadas antes de borrar):
-- SELECT oid::regprocedure FROM pg_proc
-- WHERE proname = 'enviar_push_pg' AND pronamespace = 'public'::regnamespace;

-- 1. Borrar TODAS las sobrecargas existentes:
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT oid::regprocedure AS sig FROM pg_proc
    WHERE proname = 'enviar_push_pg' AND pronamespace = 'public'::regnamespace
  LOOP
    EXECUTE 'DROP FUNCTION ' || r.sig || ';';
  END LOOP;
END $$;

-- 2. Recrear la ÚNICA versión canónica:
create function public.enviar_push_pg(
  p_usuario_id uuid,
  p_titulo text,
  p_cuerpo text,
  p_categoria text default 'mensajes'
)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_url text;
  v_secret text;
  v_body jsonb;
  v_headers jsonb;
  v_permitido boolean := true;
begin
  select case lower(coalesce(p_categoria, 'mensajes'))
      when 'mensajes' then coalesce(mensajes, true)
      when 'matches' then coalesce(matches, true)
      when 'lesgusto' then coalesce(les_gusto, true)
      when 'visitas' then coalesce(visitas, true)
      when 'cercadeti' then coalesce(cerca_de_ti, true)
      when 'regalos' then coalesce(regalos, true)
      when 'consejos' then coalesce(consejos, true)
      when 'sondeos' then coalesce(sondeos, true)
      else true
    end
    into v_permitido
    from public.notif_prefs
    where usuario_id = p_usuario_id;
  if v_permitido is false then
    return;
  end if;
  select valor into v_url from public.app_config where clave = 'push_url';
  if v_url is null or v_url like 'REEMPLAZA_%' or p_usuario_id is null then
    return;
  end if;
  select valor into v_secret from public.app_config where clave = 'push_secret';
  v_headers := jsonb_build_object(
    'content-type', 'application/json',
    'x-flumi-secret', coalesce(v_secret, '')
  );
  v_body := jsonb_build_object(
    'usuario_id', p_usuario_id,
    'titulo', p_titulo,
    'cuerpo', p_cuerpo,
    'categoria', coalesce(p_categoria, 'mensajes')
  );
  begin
    if to_regnamespace('net') is not null then
      begin
        perform net.http_post(url := v_url, body := v_body, headers := v_headers);
        perform public.registrar_push_log(p_usuario_id, coalesce(p_categoria,'mensajes'), p_titulo, 'net', true, 'enqueued');
        return;
      exception when others then
        perform public.registrar_push_log(p_usuario_id, coalesce(p_categoria,'mensajes'), p_titulo, 'net', false, SQLERRM);
      end;
    else
      perform public.registrar_push_log(p_usuario_id, coalesce(p_categoria,'mensajes'), p_titulo, 'ninguno', false, 'pg_net no disponible (falta CREATE EXTENSION)');
    end if;
  exception when others then
    perform public.registrar_push_log(p_usuario_id, coalesce(p_categoria,'mensajes'), p_titulo, 'error', false, SQLERRM);
  end;
end;
$$;

-- 3. Triggers blindados (casts ::text + guard: el push nunca rompe el insert):
create or replace function public.notificar_push_mensaje()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_nombre text;
begin
  if new.emisor_id = new.receptor_id then
    return new;
  end if;
  select nombre into v_nombre from public.profiles where id = new.emisor_id;
  begin
    perform public.enviar_push_pg(
      new.receptor_id,
      ('Nuevo mensaje de ' || coalesce(v_nombre, 'Alguien'))::text,
      left(coalesce(new.contenido, ''), 100)::text,
      'mensajes'::text
    );
  exception when others then
    null;
  end;
  return new;
end;
$$;

drop trigger if exists notificar_push_mensaje_trg on public.messages;
create trigger notificar_push_mensaje_trg
  after insert on public.messages
  for each row execute function public.notificar_push_mensaje();

create or replace function public.notificar_push_like()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_nombre text;
begin
  select nombre into v_nombre from public.profiles where id = new.usuario_id;
  begin
    perform public.enviar_push_pg(
      new.usuario_likeado_id,
      'Flumi'::text,
      (coalesce(v_nombre, 'Alguien') || ' te dio Me Gusta')::text,
      'lesGusto'::text
    );
  exception when others then
    null;
  end;
  return new;
end;
$$;

drop trigger if exists notificar_push_like_trg on public.historial_likes;
create trigger notificar_push_like_trg
  after insert on public.historial_likes
  for each row execute function public.notificar_push_like();

create or replace function public.notificar_push_visita()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_nombre text;
begin
  select nombre into v_nombre from public.profiles where id = new.visitante_id;
  begin
    perform public.enviar_push_pg(
      new.visitado_id,
      'Flumi'::text,
      (coalesce(v_nombre, 'Alguien') || ' visitó tu perfil')::text,
      'visitas'::text
    );
  exception when others then
    null;
  end;
  return new;
end;
$$;

drop trigger if exists notificar_push_visita_trg on public.visitas;
create trigger notificar_push_visita_trg
  after insert on public.visitas
  for each row execute function public.notificar_push_visita();

create or replace function public.notificar_push_match()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_nombre text;
begin
  select nombre into v_nombre from public.profiles where id = new.usuario_a_id;
  begin
    perform public.enviar_push_pg(
      new.usuario_b_id,
      'Flumi'::text,
      (coalesce(v_nombre, 'Alguien') || ' hizo match contigo')::text,
      'matches'::text
    );
  exception when others then
    null;
  end;
  select nombre into v_nombre from public.profiles where id = new.usuario_b_id;
  begin
    perform public.enviar_push_pg(
      new.usuario_a_id,
      'Flumi'::text,
      (coalesce(v_nombre, 'Alguien') || ' hizo match contigo')::text,
      'matches'::text
    );
  exception when others then
    null;
  end;
  return new;
end;
$$;

drop trigger if exists notificar_push_match_trg on public.matches;
create trigger notificar_push_match_trg
  after insert on public.matches
  for each row execute function public.notificar_push_match();

-- 4. Verificación (debe devolver UNA sola fila):
-- SELECT oid::regprocedure FROM pg_proc
-- WHERE proname = 'enviar_push_pg' AND pronamespace = 'public'::regnamespace;

-- 5. FIX: leer recibido (like-only / oficiales) → permitir al destinatario
-- actualizar leido_hasta para que ✓✓ funcione en vivo sin match.
-- historial_likes: policy actual solo permite usuario_id (emisor). Añadimos
-- permiso para usuario_likeado_id (receptor) SOLO en columna leido_hasta.
drop policy if exists "usuario_gestiona_sus_likes" on public.historial_likes;
create policy "usuario_gestiona_sus_likes"
  on public.historial_likes for all
  using (auth.uid() = usuario_id)
  with check (auth.uid() = usuario_id);

-- El receptor (usuario_likeado_id) puede actualizar su leido_hasta.
drop policy if exists "receptor_actualiza_leido_hasta_like" on public.historial_likes;
create policy "receptor_actualiza_leido_hasta_like"
  on public.historial_likes for update
  using (auth.uid() = usuario_likeado_id)
  with check (auth.uid() = usuario_likeado_id and leido_hasta is not null);

-- 6. Tabla remota para conversaciones_leidas (cuentas oficiales / sin match).
-- Permite a cada participante escribir/leer su propio marcador de leído.
create table if not exists public.conversaciones_leidas (
  usuario_id      uuid not null references public.profiles(id) on delete cascade,
  otro_usuario_id uuid not null references public.profiles(id) on delete cascade,
  leido_hasta     timestamptz not null default now(),
  primary key (usuario_id, otro_usuario_id)
);

alter table public.conversaciones_leidas enable row level security;

drop policy if exists "usuario_gestiona_sus_conversaciones_leidas" on public.conversaciones_leidas;
create policy "usuario_gestiona_sus_conversaciones_leidas"
  on public.conversaciones_leidas for all
  using (auth.uid() = usuario_id)
  with check (auth.uid() = usuario_id);

-- Realtime para que el leído de oficiales/like-only llegue en vivo.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'conversaciones_leidas'
  ) then
    alter publication supabase_realtime add table public.conversaciones_leidas;
  end if;
end $$;

-- 7. Sincronización: el cliente también escribe en conversaciones_leidas remoto.
-- Añadir en Dart (marcarConversacionLeida) tras el bloque de historial_likes:
-- await Supabase.instance.client
--     .from('conversaciones_leidas')
--     .upsert({
--       'usuario_id': miId,
--       'otro_usuario_id': otroUsuarioId,
--       'leido_hasta': ahora.toUtc().toIso8601String(),
--     })
--     .timeout(const Duration(seconds: 5));

-- 8. Trigger: si se inserta/actualiza un rechazo entre dos usuarios que
-- tienen match, se rompe el match automáticamente (server-side, cubre
-- sync offline). AFTER INSERT OR UPDATE cubre upsert que haga UPDATE.
create or replace function public.romper_match_por_rechazo()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  delete from public.matches
  where (usuario_a_id = NEW.usuario_id and usuario_b_id = NEW.rechazado_id)
     or (usuario_a_id = NEW.rechazado_id and usuario_b_id = NEW.usuario_id);
  return NEW;
end;
$$;

drop trigger if exists trg_romper_match_por_rechazo on public.rechazos;
create trigger trg_romper_match_por_rechazo
  after insert or update on public.rechazos
  for each row execute function public.romper_match_por_rechazo();
