-- ============================================================
-- PUSH: respetar preferencias del destinatario (fix 2)
-- Ejecutar en Supabase SQL Editor. Idempotente.
-- Requiere: tabla notif_prefs + enviar_push_pg con categoría.
-- La app sube las prefs al guardar (write-through); sin fila = todo ON.
-- ============================================================

create table if not exists public.notif_prefs (
  usuario_id uuid primary key references public.profiles(id) on delete cascade,
  mensajes   boolean not null default true,
  matches    boolean not null default true,
  les_gusto  boolean not null default true,
  visitas    boolean not null default true,
  cerca_de_ti boolean not null default true,
  regalos    boolean not null default true,
  consejos   boolean not null default true,
  sondeos    boolean not null default true,
  actualizado_en timestamptz not null default now()
);

alter table public.notif_prefs enable row level security;

drop policy if exists "usuario_gestiona_sus_prefs" on public.notif_prefs;
create policy "usuario_gestiona_sus_prefs"
  on public.notif_prefs for all
  using (auth.uid() = usuario_id)
  with check (auth.uid() = usuario_id);

-- enviar_push_pg v2: respeta la preferencia del destinatario.
create or replace function public.enviar_push_pg(
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
  -- Sin fila de prefs = todo activado.
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
    'cuerpo', p_cuerpo
  );
  begin
    if to_regnamespace('net') is not null then
      perform net.http_post(v_url, v_headers, v_body);
    elsif to_regnamespace('supabase_functions') is not null then
      perform supabase_functions.http_request(v_url, 'POST', v_headers, v_body);
    end if;
  exception when others then
    -- Un fallo de push nunca debe romper el insert original.
    null;
  end;
end;
$$;

-- Triggers: pasan su categoría (la firma del trigger no cambia).
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
  perform public.enviar_push_pg(
    new.receptor_id,
    'Nuevo mensaje de ' || coalesce(v_nombre, 'Alguien'),
    left(coalesce(new.contenido, ''), 100),
    'mensajes'
  );
  return new;
end;
$$;

create or replace function public.notificar_push_like()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_nombre text;
begin
  select nombre into v_nombre from public.profiles where id = new.usuario_id;
  perform public.enviar_push_pg(
    new.usuario_likeado_id,
    'Flumi',
    coalesce(v_nombre, 'Alguien') || ' te dio Me Gusta',
    'lesGusto'
  );
  return new;
end;
$$;

create or replace function public.notificar_push_visita()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_nombre text;
begin
  select nombre into v_nombre from public.profiles where id = new.visitante_id;
  perform public.enviar_push_pg(
    new.visitado_id,
    'Flumi',
    coalesce(v_nombre, 'Alguien') || ' visitó tu perfil',
    'visitas'
  );
  return new;
end;
$$;

create or replace function public.notificar_push_match()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_nombre text;
begin
  select nombre into v_nombre from public.profiles where id = new.usuario_a_id;
  perform public.enviar_push_pg(
    new.usuario_b_id,
    'Flumi',
    coalesce(v_nombre, 'Alguien') || ' hizo match contigo',
    'matches'
  );
  select nombre into v_nombre from public.profiles where id = new.usuario_b_id;
  perform public.enviar_push_pg(
    new.usuario_a_id,
    'Flumi',
    coalesce(v_nombre, 'Alguien') || ' hizo match contigo',
    'matches'
  );
  return new;
end;
$$;
