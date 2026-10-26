-- ============================================================
-- MIGRACION SEGURIDAD FASE 2 (flumi_app + admin_flumi)
-- Idempotente. Ejecutar en Supabase Dashboard -> SQL Editor.
-- ============================================================

-- 1. Mensajes: plan + match en servidor (antes solo suspension + bloqueos).
create or replace function public.validar_envio_mensaje()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if exists (select 1 from public.profiles
              where id = new.emisor_id and coalesce(suspendido, false)) then
    raise exception 'Cuenta suspendida';
  end if;
  if exists (select 1 from public.blocks b
              where (b.bloqueador_id = new.receptor_id and b.bloqueado_id = new.emisor_id)
                 or (b.bloqueador_id = new.emisor_id and b.bloqueado_id = new.receptor_id)) then
    raise exception 'No puedes enviar mensajes a este usuario';
  end if;
  if new.emisor_id not in ('00000000-0000-0000-0000-00000000000a','00000000-0000-0000-0000-00000000000f')
     and new.receptor_id not in ('00000000-0000-0000-0000-00000000000a','00000000-0000-0000-0000-00000000000f') then
    if public.plan_efectivo(new.emisor_id) = 'gratis' then
      raise exception 'Plan insuficiente para enviar mensajes';
    end if;
  end if;
  if new.emisor_id not in ('00000000-0000-0000-0000-00000000000a','00000000-0000-0000-0000-00000000000f')
     and new.receptor_id not in ('00000000-0000-0000-0000-00000000000a','00000000-0000-0000-0000-00000000000f') then
    if not exists (select 1 from public.matches m
                    where (m.usuario_a_id = new.emisor_id and m.usuario_b_id = new.receptor_id)
                       or (m.usuario_a_id = new.receptor_id and m.usuario_b_id = new.emisor_id)) then
      raise exception 'No hay match';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists validar_envio_mensaje_trg on public.messages;
create trigger validar_envio_mensaje_trg
  before insert on public.messages
  for each row execute function public.validar_envio_mensaje();

-- 2. Edad derivada de fecha_nacimiento.
create or replace function public.proteger_columnas_sensibles()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_admin boolean := false;
begin
  if current_user in ('postgres', 'supabase_admin', 'service_role', 'supabase_auth_admin') then
    return new;
  end if;
  select coalesce(is_admin, false) into v_admin
    from public.profiles where id = auth.uid();
  if v_admin then
    -- admins aun derivan edad
    if new.fecha_nacimiento is not null then
      new.edad := extract(year from age(current_date, new.fecha_nacimiento))::int;
    end if;
    return new;
  end if;
  if TG_OP = 'INSERT' then
    new.is_admin := false;
    new.suspendido := false;
    new.verificado_status := false;
    new.score_popularidad := 0;
  else
    new.is_admin := old.is_admin;
    new.suspendido := old.suspendido;
    new.verificado_status := old.verificado_status;
    new.score_popularidad := old.score_popularidad;
  end if;
  if new.fecha_nacimiento is not null then
    new.edad := extract(year from age(current_date, new.fecha_nacimiento))::int;
  end if;
  return new;
end;
$$;

-- 3. Quitar funcion de limpieza de produccion (idempotente).
do $$
begin
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
             where n.nspname = 'public' and p.proname = 'limpiar_interacciones_pruebas') then
    revoke all on function public.limpiar_interacciones_pruebas() from public, anon, authenticated;
    drop function public.limpiar_interacciones_pruebas();
  end if;
end $$;
