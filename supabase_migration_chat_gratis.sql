-- ============================================================
-- CHAT: FLAG DE COBRO + PREMIUM SIN MATCH CON SOLICITUDES
--
-- Reglas de `validar_envio_mensaje`:
--   1. `mensajes_requieren_plus` (app_config) decide si el chat exige
--      Plus/Premium. Por defecto false: el plan gratis tambien chatea.
--   2. Con match se chatea libre.
--   3. Sin match solo Premium puede EMPEZAR, y lo hace con una solicitud
--      que el receptor acepta o descarta. Mientras esta pendiente nadie
--      mas escribe; si la descarta, el emisor queda bloqueado para ese par.
--   4. Tope diario: app_config.limite_solicitudes_chat_diarias (5).
--
-- Bloqueos, suspension y cuentas oficiales se mantienen.
--
-- Idempotente. Ejecutar en Supabase Dashboard -> SQL Editor.
-- ============================================================

insert into public.app_config (clave, valor, tipo)
values
  ('mensajes_requieren_plus', 'false', 'feature'),
  ('limite_solicitudes_chat_diarias', '5', 'feature')
on conflict (clave) do nothing;
create table if not exists public.chat_solicitudes (
  emisor_id   uuid not null references public.profiles(id) on delete cascade,
  receptor_id uuid not null references public.profiles(id) on delete cascade,
  estado      text not null default 'pendiente'
              check (estado in ('pendiente', 'aceptada', 'rechazada')),
  creado_en   timestamptz not null default now(),
  resuelto_en timestamptz,
  primary key (emisor_id, receptor_id)
);

create index if not exists chat_solicitudes_receptor_idx
  on public.chat_solicitudes (receptor_id, estado);
create index if not exists chat_solicitudes_emisor_idx
  on public.chat_solicitudes (emisor_id, creado_en);

alter table public.chat_solicitudes enable row level security;

drop policy if exists "solicitudes_visibles_solo_para_participantes" on public.chat_solicitudes;
create policy "solicitudes_visibles_solo_para_participantes"
  on public.chat_solicitudes for select
  using (auth.uid() = emisor_id or auth.uid() = receptor_id);

-- Solo el receptor decide. El emisor no puede borrar ni reabrir la solicitud
-- (si no, el "descartar" no serviría de nada).
drop policy if exists "receptor_responde_su_solicitud" on public.chat_solicitudes;
create policy "receptor_responde_su_solicitud"
  on public.chat_solicitudes for update
  using (auth.uid() = receptor_id)
  with check (
    auth.uid() = receptor_id
    and estado in ('aceptada', 'rechazada')
  );

drop policy if exists "admin_gestiona_solicitudes" on public.chat_solicitudes;
create policy "admin_gestiona_solicitudes"
  on public.chat_solicitudes for all
  using (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true))
  with check (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true));

-- MATCHES
-- Realtime: el receptor recibe la solicitud al instante (y el emisor el
-- cambio de estado) sin esperar al siguiente sync.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'chat_solicitudes'
  ) then
    alter publication supabase_realtime add table public.chat_solicitudes;
  end if;
end $$;

create or replace function public.validar_envio_mensaje()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_sol    public.chat_solicitudes%rowtype;
  v_limite int;
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
  -- Entre usuarios regulares: con match se chatea libre; sin match solo se
  -- puede EMPEZAR con una solicitud (beneficio de Premium), que el receptor
  -- acepta o descarta. Mientras esté pendiente nadie más escribe en el hilo.
  if new.emisor_id not in ('00000000-0000-0000-0000-00000000000a','00000000-0000-0000-0000-00000000000f')
     and new.receptor_id not in ('00000000-0000-0000-0000-00000000000a','00000000-0000-0000-0000-00000000000f') then
    if not exists (select 1 from public.matches m
                    where (m.usuario_a_id = new.emisor_id and m.usuario_b_id = new.receptor_id)
                       or (m.usuario_a_id = new.receptor_id and m.usuario_b_id = new.emisor_id)) then
      select * into v_sol
        from public.chat_solicitudes s
       where (s.emisor_id = new.emisor_id and s.receptor_id = new.receptor_id)
          or (s.emisor_id = new.receptor_id and s.receptor_id = new.emisor_id)
       limit 1;
      if v_sol.emisor_id is null then
        -- No hay match ni solicitud: solo Premium puede abrir una.
        if public.plan_efectivo(new.emisor_id) <> 'premium' then
          raise exception 'No hay match';
        end if;
        select case when valor ~ '^[0-9]+$' then valor::int end
          into v_limite
          from public.app_config
         where clave = 'limite_solicitudes_chat_diarias';
        v_limite := coalesce(v_limite, 5);
        if (select count(*) from public.chat_solicitudes s
             where s.emisor_id = new.emisor_id
               and s.creado_en >= date_trunc('day', now())) >= v_limite then
          raise exception 'Alcanzaste el limite de solicitudes de hoy';
        end if;
        insert into public.chat_solicitudes (emisor_id, receptor_id)
        values (new.emisor_id, new.receptor_id);
      elsif v_sol.estado = 'rechazada' then
        raise exception 'Solicitud rechazada';
      elsif v_sol.estado = 'pendiente' then
        -- El primer mensaje creó la solicitud; los siguientes esperan turno.
        -- También bloquea al receptor: no puede responder sin aceptar antes.
        raise exception 'Solicitud pendiente de aceptacion';
      end if;
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists validar_envio_mensaje_trg on public.messages;
create trigger validar_envio_mensaje_trg
  before insert on public.messages
  for each row execute function public.validar_envio_mensaje();

-- Recarga el esquema en PostgREST para que la nueva tabla y el trigger tomen el cambio.
notify pgrst, 'reload schema';