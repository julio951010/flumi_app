-- ============================================================
-- CHAT: FLAG DE COBRO + PREMIUM SIN MATCH + RESPUESTA
--
-- Reglas de `validar_envio_mensaje`:
--   1. `mensajes_requieren_plus` (app_config) decide si el chat exige
--      Plus/Premium. Por defecto false: el plan gratis tambien chatea.
--   2. Premium puede iniciar conversacion CON O SIN match.
--   3. Gratis/Plus necesitan match, PERO pueden responder a quien ya les
--      escribio (si no, el receptor nunca podria contestar a un Premium).
--
-- Bloqueos, suspension y cuentas oficiales se mantienen.
--
-- Idempotente. Ejecutar en Supabase Dashboard -> SQL Editor.
-- ============================================================

insert into public.app_config (clave, valor, tipo)
values ('mensajes_requieren_plus', 'false', 'feature')
on conflict (clave) do nothing;
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
  -- Cobro del chat: se controla en caliente con
  -- app_config.mensajes_requieren_plus. Por defecto false: el chat es gratis
  -- y se monetiza el descubrimiento (ver likes/visitas, filtros, boosts).
  -- Con 'true', un plan gratis no puede enviar ni responder (Plus/Premium sí).
  -- Responder a cuentas oficiales/sistema queda permitido para cualquier plan.
  if new.emisor_id not in ('00000000-0000-0000-0000-00000000000a','00000000-0000-0000-0000-00000000000f')
     and new.receptor_id not in ('00000000-0000-0000-0000-00000000000a','00000000-0000-0000-0000-00000000000f') then
    if coalesce(
         (select lower(valor) = 'true'
            from public.app_config
           where clave = 'mensajes_requieren_plus'),
         false)
       and public.plan_efectivo(new.emisor_id) = 'gratis' then
      raise exception 'Plan insuficiente para enviar mensajes';
    end if;
  end if;
  -- Entre usuarios regulares se requiere match previo, salvo que:
  --   * el emisor sea Premium (puede iniciar conversación sin match), o
  --   * el receptor ya le haya escrito antes (respuesta a una conversación
  --     iniciada por un Premium sin match; sin esto el receptor gratis
  --     nunca podría contestar y el beneficio quedaría roto).
  if new.emisor_id not in ('00000000-0000-0000-0000-00000000000a','00000000-0000-0000-0000-00000000000f')
     and new.receptor_id not in ('00000000-0000-0000-0000-00000000000a','00000000-0000-0000-0000-00000000000f') then
    if public.plan_efectivo(new.emisor_id) <> 'premium'
       and not exists (select 1 from public.matches m
                        where (m.usuario_a_id = new.emisor_id and m.usuario_b_id = new.receptor_id)
                           or (m.usuario_a_id = new.receptor_id and m.usuario_b_id = new.emisor_id))
       and not exists (select 1 from public.messages prev
                        where prev.emisor_id = new.receptor_id
                          and prev.receptor_id = new.emisor_id) then
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

-- Recarga el esquema en PostgREST para que los RPCs tomen el cambio.
notify pgrst, 'reload schema';