-- ============================================================
-- MIGRACIÓN SEGURIDAD FASE 1 (flumi_app + admin_flumi)
-- Ejecutar en Supabase Dashboard -> SQL Editor. Idempotente.
-- Reproduce lo que ya está en supabase/schema.sql (mantenlos iguales).
--
-- Antes de ejecutar (opcional, para ver qué cambia):
--   select tgname from pg_trigger
--    where tgrelid='public.profiles'::regclass and not tgisinternal;
-- Para deshacer una parte, ver la sección ROLLBACK al final.
-- ============================================================

alter table public.profiles
  add column if not exists suspendido boolean not null default false;

-- Blindaje de columnas sensibles de profiles: is_admin, suspendido,
-- verificado_status y score_popularidad solo las cambian admins, service_role
-- o funciones SECURITY DEFINER del servidor. Para cualquier otro cliente se
-- CONSERVA el valor anterior (sin lanzar error: así el upsert del perfil que
-- hace la app, que reenvía verificado_status/score_popularidad, no se rompe).
--
-- IMPORTANTE: la función es SECURITY INVOKER a propósito. Con SECURITY DEFINER
-- current_user sería siempre el dueño (postgres) y el trigger no protegería
-- nada (bug de la versión anterior, proteger_is_admin). Con INVOKER,
-- current_user es el rol que ejecuta el UPDATE: 'authenticated' si viene del
-- cliente y 'postgres' si lo hace una función SECURITY DEFINER o el SQL Editor.
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
  return new;
end;
$$;

drop trigger if exists proteger_is_admin_trg on public.profiles;
drop trigger if exists proteger_columnas_admin_trg on public.profiles;
drop trigger if exists proteger_columnas_admin on public.profiles;
drop trigger if exists proteger_suspendido_trg on public.profiles;
drop trigger if exists proteger_columnas_sensibles_trg on public.profiles;
create trigger proteger_columnas_sensibles_trg
  before insert or update on public.profiles
  for each row execute function public.proteger_columnas_sensibles();

-- ------------------------------------------------------------
-- Pagos: auto-aprobación por SMS (datos del cliente = falsificables)
-- queda APAGADA. Los pagos pasan a revisión manual en admin_flumi.
-- ------------------------------------------------------------
create or replace function public.solicitar_pago(
  p_metodo text,
  p_plan text,
  p_dias int,
  p_nro text,
  p_sms_nro text default null,
  p_sms_monto numeric default null,
  p_sms_remitente text default null,
  p_sms_fecha text default null,
  p_sms_beneficiario text default null
) returns jsonb
language plpgsql
security definer set search_path = public
as $$
declare
  yo uuid := auth.uid();
  v_monto int;
  v_tarjeta text;
  v_movil text;
  v_qr text;
  v_existe int;
  v_pendientes int;
  v_auto boolean := false;
  v_vence_actual timestamptz;
  v_plan_actual text;
  v_plan_nuevo text;
  v_reserva_plan text;
  v_reserva_vence timestamptz;
  v_reserva_inicio timestamptz;
  v_base timestamptz;
  v_sms_nro_norm text;
  v_sms_rem_norm text;
begin
  if yo is null then
    return jsonb_build_object('ok', false, 'error', 'no_autenticado');
  end if;
  p_metodo := lower(trim(p_metodo));
  p_plan := trim(p_plan);
  p_nro := upper(trim(p_nro));
  p_nro := regexp_replace(p_nro, '\s+', '', 'g');

  if p_metodo not in ('transfermovil','enzona') then
    return jsonb_build_object('ok', false, 'error', 'metodo_invalido');
  end if;
  if p_plan not in ('Flumi Plus','Flumi Premium') then
    return jsonb_build_object('ok', false, 'error', 'plan_invalido');
  end if;
  if p_dias not in (7,30,90) then
    return jsonb_build_object('ok', false, 'error', 'dias_invalido');
  end if;

  -- Formato Nro: 13 Transfermóvil / 12 EnZona, alfanumérico
  if p_metodo = 'transfermovil' and p_nro !~ '^[A-Za-z0-9]{13}$' then
    return jsonb_build_object('ok', false, 'error', 'nro_formato_transfermovil');
  end if;
  if p_metodo = 'enzona' and p_nro !~ '^[A-Za-z0-9]{12}$' then
    return jsonb_build_object('ok', false, 'error', 'nro_formato_enzona');
  end if;

  -- Monto canónico según plan/días (espejo de DetallePlanPantalla._precios)
  if p_plan = 'Flumi Premium' then
    v_monto := case p_dias when 7 then 200 when 30 then 500 when 90 then 1300 else 0 end;
  else
    v_monto := case p_dias when 7 then 100 when 30 then 250 when 90 then 650 else 0 end;
  end if;

  -- Config activa para el método
  select tarjeta_destino, movil_confirmar, qr_url into v_tarjeta, v_movil, v_qr
    from public.pagos_config where metodo = p_metodo and activo = true limit 1;
  if v_tarjeta is null then
    v_tarjeta := '9225 9598 7143 2108';
    v_movil := '+53 5 123 45 67';
    v_qr := '';
  end if;

  -- Anti-replay global
  select count(*) into v_existe from public.pagos where nro_transaccion = p_nro;
  if v_existe > 0 then
    return jsonb_build_object('ok', false, 'error', 'nro_duplicado');
  end if;

  -- Rate-limit: máx 3 pendientes por 24h por usuario
  select count(*) into v_pendientes from public.pagos
    where usuario_id = yo and creado_en > now() - interval '24 hours' and estado = 'pendiente';
  if v_pendientes >= 3 then
    return jsonb_build_object('ok', false, 'error', 'rate_limit');
  end if;

  -- Auto-verificación por SMS: FAIL-CLOSED. Cada chequeo debe pasar con datos
  -- presentes y coincidentes; la ausencia de cualquier dato cae al flujo
  -- manual (pendiente) en vez de auto-aprobar.
  -- ADVERTENCIA: estos datos "SMS" los envía el CLIENTE y por tanto son
  -- falsificables. La auto-aprobación queda APAGADA por defecto
  -- (app_config.pagos_auto_aprobacion = 'false'): todo pago pasa a revisión
  -- manual en admin_flumi. Actívala solo si la evidencia del pago llega al
  -- servidor por un canal que el pagador no controla (p. ej. el SMS recibido
  -- en TU teléfono receptor, enviado por una edge function con secreto).
  if coalesce((select valor from public.app_config
                where clave = 'pagos_auto_aprobacion'), 'false') = 'true'
     and p_sms_nro is not null and p_sms_remitente is not null then
    v_sms_nro_norm := upper(regexp_replace(trim(p_sms_nro), '[^A-Za-z0-9]', '', 'g'));
    v_sms_rem_norm := upper(trim(p_sms_remitente));
    if v_sms_nro_norm = p_nro then
      if (p_metodo = 'transfermovil' and v_sms_rem_norm = 'PAGOXMOVIL') or
         (p_metodo = 'enzona' and v_sms_rem_norm = 'ENZONA') then
        -- Monto obligatorio y exacto (no se anula por ausencia)
        if p_sms_monto is not null and abs(p_sms_monto - v_monto) < 0.01 then
          -- Beneficiario obligatorio: 4 primeros y 4 últimos deben coincidir
          -- con la tarjeta configurada (ambos con 8+ dígitos)
          declare
            v_ben_norm text;
            v_tar_norm text;
            v_ben_first4 text;
            v_ben_last4 text;
            v_tar_first4 text;
            v_tar_last4 text;
            v_ben_ok boolean := false;
            v_fecha_ok boolean := false;
          begin
            v_ben_norm := regexp_replace(coalesce(p_sms_beneficiario,''), '[^0-9]', '', 'g');
            v_tar_norm := regexp_replace(coalesce(v_tarjeta,''), '[^0-9]', '', 'g');
            if length(v_ben_norm) >= 8 and length(v_tar_norm) >= 8 then
              v_ben_first4 := substring(v_ben_norm from 1 for 4);
              v_ben_last4 := substring(v_ben_norm from length(v_ben_norm)-3 for 4);
              v_tar_first4 := substring(v_tar_norm from 1 for 4);
              v_tar_last4 := substring(v_tar_norm from length(v_tar_norm)-3 for 4);
              if v_ben_first4 = v_tar_first4 and v_ben_last4 = v_tar_last4 then
                v_ben_ok := true;
              end if;
            end if;
            -- Fecha obligatoria: debe ser hoy (tolerancia 1 día). Si no se
            -- puede parsear, no auto-aprueba (cae a manual).
            if p_sms_fecha is not null and p_sms_fecha <> '' then
              begin
                -- p_sms_fecha viene como 'YYYY-MM-DD' desde el cliente
                if abs(extract(epoch from (current_date - p_sms_fecha::date))/86400) <= 1 then
                  v_fecha_ok := true;
                end if;
              exception when others then
                v_fecha_ok := false;
              end;
            end if;
            if v_ben_ok and v_fecha_ok then
              v_auto := true;
            end if;
          end;
        end if;
      end if;
    end if;
  end if;

  if v_auto then
    insert into public.pagos (usuario_id, metodo, plan, dias, monto, tarjeta_destino, movil_confirmar, qr_url, nro_transaccion, estado, verificado_en, verificado_por)
    values (yo, p_metodo, p_plan, p_dias, v_monto, coalesce(v_tarjeta,''), coalesce(v_movil,''), coalesce(v_qr,''), p_nro, 'aprobado', now(), yo);
    -- Extender: los días se suman a la vigencia restante (no se pierde lo pagado).
    -- Cambiar de plan con vigencia restante: el anterior queda en reserva
    -- PAUSADO (inicio_reserva = ahora; restante = vence - ahora) y se reanuda
    -- al vencer el nuevo (pila de profundidad 1).
    select plan, vence into v_plan_actual, v_vence_actual from public.suscripciones where usuario_id = yo;
    v_plan_nuevo := case when p_plan = 'Flumi Premium' then 'premium' else 'plus' end;
    if v_plan_actual is not null and v_plan_actual <> v_plan_nuevo
       and v_vence_actual is not null and v_vence_actual > now() then
      v_reserva_plan := v_plan_actual;
      v_reserva_vence := v_vence_actual;
      v_reserva_inicio := now();
      v_base := now();
    else
      v_reserva_plan := null;
      v_reserva_vence := null;
      v_reserva_inicio := null;
      v_base := greatest(coalesce(v_vence_actual, now()), now());
    end if;
    insert into public.suscripciones (usuario_id, plan, inicio, vence, activa, plan_reserva, vence_reserva, inicio_reserva)
    values (yo, v_plan_nuevo, now(), v_base + (p_dias || ' days')::interval, true, v_reserva_plan, v_reserva_vence, v_reserva_inicio)
    on conflict (usuario_id) do update set plan = excluded.plan, inicio = excluded.inicio, vence = excluded.vence, activa = true, plan_reserva = excluded.plan_reserva, vence_reserva = excluded.vence_reserva, inicio_reserva = excluded.inicio_reserva;
    perform public.enviar_push_pg(yo, 'Pago verificado'::text, ('Tu suscripción ' || p_plan || ' (' || p_dias || ' días) está activa')::text, 'regalos'::text);
    return jsonb_build_object('ok', true, 'monto', v_monto, 'auto_aprobado', true);
  end if;

  -- El count previo es fast-path; la carrera concurrente la atrapa el unique.
  begin
    insert into public.pagos (usuario_id, metodo, plan, dias, monto, tarjeta_destino, movil_confirmar, qr_url, nro_transaccion)
    values (yo, p_metodo, p_plan, p_dias, v_monto, coalesce(v_tarjeta,''), coalesce(v_movil,''), coalesce(v_qr,''), p_nro);
  exception when unique_violation then
    return jsonb_build_object('ok', false, 'error', 'nro_duplicado');
  end;

  return jsonb_build_object('ok', true, 'monto', v_monto, 'auto_aprobado', false);
end;
$$;

-- Flag de auto-aprobación de pagos (APAGADA). Ver nota en solicitar_pago.
insert into public.app_config (clave, valor, tipo)
values ('pagos_auto_aprobacion', 'false', 'feature')
on conflict (clave) do nothing;

-- Bloqueos y suspensión también en el SERVIDOR (antes solo se respetaban en
-- el cliente / el feed). SECURITY DEFINER para poder leer `blocks` completa.
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
  return new;
end;
$$;

drop trigger if exists validar_envio_mensaje_trg on public.messages;
create trigger validar_envio_mensaje_trg
  before insert on public.messages
  for each row execute function public.validar_envio_mensaje();

create or replace function public.validar_like_suspendido()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if exists (select 1 from public.profiles
              where id = new.usuario_id and coalesce(suspendido, false)) then
    raise exception 'Cuenta suspendida';
  end if;
  return new;
end;
$$;

drop trigger if exists validar_like_suspendido_trg on public.historial_likes;
create trigger validar_like_suspendido_trg
  before insert on public.historial_likes
  for each row execute function public.validar_like_suspendido();

-- Permisos de ejecución de RPC. En Supabase, `revoke ... from public` NO quita
-- el acceso de `anon` (lo concede default privileges), hay que revocarlo
-- explícitamente. email_existe se deja a propósito accesible a anon: la app la
-- llama antes de iniciar sesión.
do $$
declare
  r record;
begin
  -- Solo las usan triggers / otras funciones SECURITY DEFINER: nadie por RPC.
  for r in
    select p.oid::regprocedure as sig
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname in ('enviar_push_pg', 'registrar_push_log')
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', r.sig);
  end loop;

  -- Solo usuarios con sesión.
  for r in
    select p.oid::regprocedure as sig
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname in ('plan_efectivo', 'registrar_me_gusta', 'registrar_visita',
                         'registrar_deshacer', 'enviar_bienvenida_nuevo_usuario',
                         'solicitar_pago', 'verificar_pago', 'cancelar_suscripcion',
                         'promover_reserva', 'limpiar_interacciones_pruebas',
                         'estadisticas_admin', 'perfiles_cercanos',
                         'registrar_device_token', 'eliminar_device_token')
  loop
    execute format('revoke execute on function %s from public, anon', r.sig);
    execute format('grant execute on function %s to authenticated', r.sig);
  end loop;
end $$;

-- ------------------------------------------------------------
-- AUDITORÍA (solo lectura): pagos aprobados por el propio usuario.
-- Revísalos a mano: son los que la auto-aprobación dio por buenos.
-- ------------------------------------------------------------
-- select id, usuario_id, plan, dias, monto, nro_transaccion, creado_en
--   from public.pagos
--  where estado = 'aprobado' and verificado_por = usuario_id
--  order by creado_en desc;

-- ------------------------------------------------------------
-- ROLLBACK (por partes, solo si algo falla en producción)
-- ------------------------------------------------------------
-- drop trigger if exists validar_envio_mensaje_trg on public.messages;
-- drop trigger if exists validar_like_suspendido_trg on public.historial_likes;
-- drop trigger if exists proteger_columnas_sensibles_trg on public.profiles;
-- update public.app_config set valor='true' where clave='pagos_auto_aprobacion';  -- reactiva auto-aprobación
-- grant execute on function public.<nombre>(<args>) to anon;                      -- si una RPC dejó de responder
