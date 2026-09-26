-- ============================================================
-- FLUMI — Esquema Supabase (PostgreSQL + PostGIS)
-- Versión IDEMPOTENTE: se puede ejecutar varias veces sin error.
-- Añade columnas/tablas solo si no existen y recrea funciones/policies.
-- ============================================================

create extension if not exists postgis;
create extension if not exists "uuid-ossp";

-- ------------------------------------------------------------
-- PROFILES (se asegura de que la tabla exista y luego añade columnas)
-- ------------------------------------------------------------
create table if not exists public.profiles (
  id       uuid primary key references auth.users(id) on delete cascade,
  nombre   text not null default ''
);

alter table public.profiles add column if not exists nombre                text not null default '';
alter table public.profiles add column if not exists edad                  int default 18;
alter table public.profiles add column if not exists fecha_nacimiento      date;
alter table public.profiles add column if not exists biografia             text default '';
alter table public.profiles add column if not exists fotos_urls            text[] default '{}';
alter table public.profiles add column if not exists preferencia_edad_min   int default 18;
alter table public.profiles add column if not exists preferencia_edad_max   int default 99;
alter table public.profiles add column if not exists genero                text check (genero in ('hombre','mujer','otro','mujer trans','hombre trans','no binario','género fluido'));
alter table public.profiles add column if not exists busca_genero          text default 'otro';
alter table public.profiles add column if not exists que_busca            text default '';
alter table public.profiles add column if not exists ciudad               text default '';
alter table public.profiles add column if not exists ubicacion_lat        double precision not null default 0;
alter table public.profiles add column if not exists ubicacion_lon        double precision not null default 0;
alter table public.profiles add column if not exists ubicacion            geography(Point, 4326);
alter table public.profiles add column if not exists verificado_status     boolean default false;
alter table public.profiles add column if not exists score_popularidad     int default 0;
alter table public.profiles add column if not exists ocultar_en_linea      boolean default false;
alter table public.profiles add column if not exists ocultar_edad          boolean default false;
alter table public.profiles add column if not exists perfil_completado     boolean default false;
alter table public.profiles add column if not exists orientacion_sexual    text default '';
alter table public.profiles add column if not exists situacion_sentimental  text default '';
alter table public.profiles add column if not exists intereses             text[] default '{}';
alter table public.profiles add column if not exists altura                text default '';
alter table public.profiles add column if not exists educacion             text default '';
alter table public.profiles add column if not exists trabajo               text default '';
alter table public.profiles add column if not exists profesion             text default '';
alter table public.profiles add column if not exists preferencia_relacion  text default '';
alter table public.profiles add column if not exists bebe                  text default '';
alter table public.profiles add column if not exists fuma                  text default '';
alter table public.profiles add column if not exists hijos                 text default '';
alter table public.profiles add column if not exists personalidad          text default '';
alter table public.profiles add column if not exists signo_zodiaco         text default '';
alter table public.profiles add column if not exists mascotas              text default '';
alter table public.profiles add column if not exists religion              text default '';
alter table public.profiles add column if not exists idiomas               text default '';
alter table public.profiles add column if not exists tatuajes              text default '';
alter table public.profiles add column if not exists preguntas_perfil      jsonb default '[]';
alter table public.profiles add column if not exists foto_verificacion     text default '';
-- Gesto solicitado en la verificación (asset de referencia, p. ej.
-- assets/images/gestos/gesto2.png). El admin lo compara con la selfie.
alter table public.profiles add column if not exists gesto_verificacion    text default '';
alter table public.profiles add column if not exists ultima_conexion       timestamptz default now();
alter table public.profiles add column if not exists creado_en             timestamptz default now();
alter table public.profiles add column if not exists ocultar_perfil        boolean default false;
alter table public.profiles add column if not exists ocultar_visitas       boolean default false;
alter table public.profiles add column if not exists is_admin              boolean default false;

-- Restricción de edad mínima (solo se añade si no existe)
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'edad_minima'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles add constraint edad_minima
      check (fecha_nacimiento is null or fecha_nacimiento <= (current_date - interval '18 years'));
  end if;
end $$;

create index if not exists profiles_ubicacion_idx on public.profiles using gist (ubicacion);
create index if not exists profiles_ciudad_idx   on public.profiles (ciudad);

-- Trigger: mantener `ubicacion` (PostGIS) sincronizado con ubicacion_lat/lon.
create or replace function public.sync_ubicacion()
returns trigger
language plpgsql
as $$
begin
   if new.ubicacion_lat is not null and new.ubicacion_lon is not null then
     new.ubicacion := public.ST_SetSRID(public.ST_MakePoint(new.ubicacion_lon, new.ubicacion_lat), 4326)::geography;
   end if;
  return new;
end;
$$;

drop trigger if exists profiles_sync_ubicacion on public.profiles;
create trigger profiles_sync_ubicacion
  before insert or update on public.profiles
  for each row execute function public.sync_ubicacion();

-- ------------------------------------------------------------
-- MATCHES
-- ------------------------------------------------------------
create table if not exists public.matches (
  id               uuid primary key default uuid_generate_v4(),
  usuario_a_id     uuid not null references public.profiles(id) on delete cascade,
  usuario_b_id     uuid not null references public.profiles(id) on delete cascade,
  timestamp_match  timestamptz default now(),

  constraint par_unico unique (usuario_a_id, usuario_b_id),
  constraint no_auto_match check (usuario_a_id <> usuario_b_id)
);

alter table public.matches add column if not exists ultimo_mensaje_preview    text;
alter table public.matches add column if not exists ultimo_mensaje_timestamp  timestamptz;
alter table public.matches add column if not exists leido_hasta               timestamptz;

create index if not exists matches_usuario_a_idx on public.matches (usuario_a_id);
create index if not exists matches_usuario_b_idx on public.matches (usuario_b_id);

-- ------------------------------------------------------------
-- MESSAGES
-- ------------------------------------------------------------
create table if not exists public.messages (
  id             uuid primary key default uuid_generate_v4(),
  emisor_id      uuid not null references public.profiles(id) on delete cascade,
  receptor_id    uuid not null references public.profiles(id) on delete cascade,
  contenido      text not null,
  "timestamp"    timestamptz default now(),
  estado_envio   text default 'enviado' check (estado_envio in ('enviado','entregado','leido')),

  constraint no_auto_mensaje check (emisor_id <> receptor_id)
);

alter table public.messages add column if not exists estado_envio text default 'enviado' check (estado_envio in ('enviado','entregado','leido'));

create index if not exists messages_emisor_idx on public.messages (emisor_id);
create index if not exists messages_receptor_idx on public.messages (receptor_id);
create index if not exists messages_conversacion_idx on public.messages (emisor_id, receptor_id, "timestamp");

-- ------------------------------------------------------------
-- REPORTS (moderación — requisito de tienda de apps)
-- ------------------------------------------------------------
create table if not exists public.reports (
  id              uuid primary key default uuid_generate_v4(),
  reportante_id   uuid not null references public.profiles(id) on delete cascade,
  reportado_id    uuid not null references public.profiles(id) on delete cascade,
  motivo          text not null check (
    motivo in ('foto_inapropiada','acoso_o_abuso','perfil_falso','spam','menor_de_edad','otro')
  ),
  detalle         text default '',
  "timestamp"     timestamptz default now(),
  revisado        boolean default false
);

alter table public.reports add column if not exists revisado boolean default false;

-- ------------------------------------------------------------
-- BLOCKS
-- ------------------------------------------------------------
create table if not exists public.blocks (
  id             uuid primary key default uuid_generate_v4(),
  bloqueador_id  uuid not null references public.profiles(id) on delete cascade,
  bloqueado_id   uuid not null references public.profiles(id) on delete cascade,
  "timestamp"    timestamptz default now(),

  constraint par_bloqueo_unico unique (bloqueador_id, bloqueado_id)
);

-- ------------------------------------------------------------
-- RECHAZOS (Nope): cada fila es un Nope. Varias filas por par = conteo
-- acumulado (3 Nopes al mismo perfil = exclusión definitiva). El RPC
-- perfiles_cercanos excluye solo los Nopes recientes (< 3 días) o con
-- 3+ filas; los demás quedan disponibles para reciclar en el feed.
-- ------------------------------------------------------------
create table if not exists public.rechazos (
  id           uuid primary key default uuid_generate_v4(),
  usuario_id   uuid not null references public.profiles(id) on delete cascade,
  rechazado_id uuid not null references public.profiles(id) on delete cascade,
  "timestamp"  timestamptz default now()
);

-- Hasta vX cada par solo podía tener un Nope; era incompatible con el
-- conteo de Nopes por perfil que exige el reciclaje.
alter table public.rechazos drop constraint if exists par_rechazo_unico;

create index if not exists rechazos_usuario_idx on public.rechazos (usuario_id);
create index if not exists rechazos_par_idx on public.rechazos (usuario_id, rechazado_id);

-- ------------------------------------------------------------
-- SUSCRIPCIONES (planes Gratis / Plus / Premium)
-- ------------------------------------------------------------
create table if not exists public.suscripciones (
  usuario_id  uuid primary key references public.profiles(id) on delete cascade,
  plan        text default 'gratis' check (plan in ('gratis','plus','premium')),
  inicio      timestamptz default now(),
  vence       timestamptz,
  activa      boolean default true,
  -- Pila de planes (profundidad 1): al cambiar de plan con vigencia restante,
  -- el plan anterior espera aquí y se reactiva al vencer el nuevo.
  plan_reserva text check (plan_reserva in ('gratis','plus','premium')),
  vence_reserva timestamptz
);

alter table public.suscripciones add column if not exists plan_reserva text check (plan_reserva in ('gratis','plus','premium'));
alter table public.suscripciones add column if not exists vence_reserva timestamptz;
-- Momento del cambio de plan: permite pausar la reserva (tiempo restante =
-- vence_reserva - inicio_reserva) en vez de congelar su fecha de vencimiento.
alter table public.suscripciones add column if not exists inicio_reserva timestamptz;

-- ------------------------------------------------------------
-- USOS DIARIOS (límites por plan)
-- ------------------------------------------------------------
create table if not exists public.usos_diarios (
  usuario_id          uuid not null references public.profiles(id) on delete cascade,
  fecha               date default current_date,
  me_gustas_usados    int default 0,
  deshacer_usados     int default 0,
  superlikes_usados   int default 0,
  boosts_usados       int default 0,
  vistas_cerca_usadas int default 0,

  primary key (usuario_id, fecha)
);

-- ------------------------------------------------------------
-- VISITAS (quién visitó a quién)
-- ------------------------------------------------------------
create table if not exists public.visitas (
  id            uuid primary key default uuid_generate_v4(),
  visitante_id  uuid not null references public.profiles(id) on delete cascade,
  visitado_id   uuid not null references public.profiles(id) on delete cascade,
  "timestamp"   timestamptz default now()
);

create index if not exists visitas_visitado_idx   on public.visitas (visitado_id);
create index if not exists visitas_visitante_idx  on public.visitas (visitante_id);

-- ------------------------------------------------------------
-- HISTORIAL LIKES
-- ------------------------------------------------------------
 create table if not exists public.historial_likes (
   id                uuid primary key default uuid_generate_v4(),
   usuario_id        uuid not null references public.profiles(id) on delete cascade,
   usuario_likeado_id uuid not null references public.profiles(id) on delete cascade,
   "timestamp"       timestamptz default now(),
   es_super          boolean default false
 );

-- Fase 6: leído de conversaciones like-only (premium, sin match todavía).
-- Espejo de matches.leido_hasta para que el badge de no leídos funcione
-- también cuando no existe fila en matches.
alter table public.historial_likes add column if not exists leido_hasta timestamptz;
alter table public.historial_likes add column if not exists es_super boolean default false;

create index if not exists historial_likes_usuario_idx   on public.historial_likes (usuario_id);
create index if not exists historial_likes_likeado_idx   on public.historial_likes (usuario_likeado_id);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
alter table public.profiles        enable row level security;
alter table public.matches         enable row level security;
alter table public.messages        enable row level security;
alter table public.reports         enable row level security;
alter table public.blocks          enable row level security;
alter table public.suscripciones   enable row level security;
alter table public.usos_diarios    enable row level security;
alter table public.visitas          enable row level security;
alter table public.historial_likes enable row level security;
alter table public.rechazos        enable row level security;

-- PROFILES
drop policy if exists "perfiles_visibles_para_autenticados" on public.profiles;
create policy "perfiles_visibles_para_autenticados"
  on public.profiles for select
  using (auth.role() = 'authenticated');

drop policy if exists "usuario_edita_su_propio_perfil" on public.profiles;
create policy "usuario_edita_su_propio_perfil"
  on public.profiles for update
  using (auth.uid() = id);

-- Blindaje is_admin: ningún usuario puede auto-otorgarse admin. Solo
-- service_role/postgres o un admin existente pueden cambiar esa columna.
-- (Sin esto, UPDATE propio + is_admin=true daba premium + poderes de admin.)
create or replace function public.proteger_is_admin()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_admin boolean := false;
begin
  if current_user in ('service_role', 'postgres', 'supabase_admin') then
    return new;
  end if;
  select coalesce(is_admin, false) into v_admin
    from public.profiles where id = auth.uid();
  if v_admin then
    return new;
  end if;
  if TG_OP = 'INSERT' then
    new.is_admin := false;
  else
    new.is_admin := old.is_admin;
  end if;
  return new;
end;
$$;

drop trigger if exists proteger_is_admin_trg on public.profiles;
create trigger proteger_is_admin_trg
  before insert or update on public.profiles
  for each row execute function public.proteger_is_admin();

drop policy if exists "usuario_crea_su_propio_perfil" on public.profiles;
create policy "usuario_crea_su_propio_perfil"
  on public.profiles for insert
  with check (auth.uid() = id);

-- Admin (verificación manual de cuentas, moderación): puede actualizar
-- cualquier perfil. El trigger proteger_is_admin sigue permitiendo el cambio
-- de is_admin/verificado_status solo a admins y service_role.
drop policy if exists "admin_actualiza_perfiles" on public.profiles;
create policy "admin_actualiza_perfiles"
  on public.profiles for update
  using (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true))
  with check (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true));

-- MESSAGES
drop policy if exists "mensajes_visibles_solo_para_participantes" on public.messages;
create policy "mensajes_visibles_solo_para_participantes"
  on public.messages for select
  using (auth.uid() = emisor_id or auth.uid() = receptor_id);

drop policy if exists "usuario_envia_mensajes_como_si_mismo" on public.messages;
create policy "usuario_envia_mensajes_como_si_mismo"
  on public.messages for insert
  with check (auth.uid() = emisor_id);

-- Editar mensaje: solo el emisor puede modificar su propio mensaje. Sin esta
-- política el upsert del App falla por RLS y el texto editado nunca sube.
drop policy if exists "usuario_edita_mensajes_como_si_mismo" on public.messages;
create policy "usuario_edita_mensajes_como_si_mismo"
  on public.messages for update
  using (auth.uid() = emisor_id);

-- Borrar mensajes: cualquiera de los dos participantes puede borrar mensajes
-- de la conversacion (equivale a "eliminar mensaje" del App, que borra el
-- mensaje tambien en el servidor para que no reaparezca al sincronizar).
drop policy if exists "participantes_borran_mensajes" on public.messages;
create policy "participantes_borran_mensajes"
  on public.messages for delete
  using (auth.uid() = emisor_id or auth.uid() = receptor_id);

-- Conversaciones oficiales (Administrador / Flumi): los usuarios solo reciben
-- mensajes, no pueden escribir ni responder. El soporte funciona con tickets
-- (tabla soporte_mensajes), no con chat directo. El admin escribe como el bot
-- (emisor = bot), lo cual sigue permitido.
create or replace function public.bloquear_respuesta_bots()
returns trigger
language plpgsql
as $$
begin
  if (new.receptor_id = '00000000-0000-0000-0000-00000000000a'
   or new.receptor_id = '00000000-0000-0000-0000-00000000000f')
     and new.emisor_id <> new.receptor_id then
    raise exception 'No puedes enviar mensajes a esta conversacion oficial';
  end if;
  return new;
end;
$$;

drop trigger if exists bloquear_respuesta_bots_trg on public.messages;
create trigger bloquear_respuesta_bots_trg
  before insert on public.messages
  for each row execute function public.bloquear_respuesta_bots();

-- MATCHES
drop policy if exists "matches_visibles_solo_para_participantes" on public.matches;
create policy "matches_visibles_solo_para_participantes"
  on public.matches for select
  using (auth.uid() = usuario_a_id or auth.uid() = usuario_b_id);

-- Fase 4: los participantes actualizan su leido_hasta (estado "leído").
drop policy if exists "participantes_actualizan_su_leido_hasta" on public.matches;
create policy "participantes_actualizan_su_leido_hasta"
  on public.matches for update
  using (auth.uid() = usuario_a_id or auth.uid() = usuario_b_id)
  with check (auth.uid() = usuario_a_id or auth.uid() = usuario_b_id);

-- REPORTS
drop policy if exists "usuario_crea_reportes_como_si_mismo" on public.reports;
create policy "usuario_crea_reportes_como_si_mismo"
  on public.reports for insert
  with check (auth.uid() = reportante_id);

-- BLOCKS
drop policy if exists "usuario_gestiona_sus_bloqueos" on public.blocks;
create policy "usuario_gestiona_sus_bloqueos"
  on public.blocks for all
  using (auth.uid() = bloqueador_id)
  with check (auth.uid() = bloqueador_id);

-- SUSCRIPCIONES: el usuario SOLO lee. Toda escritura (activar, extender,
-- cancelar, promover reserva) pasa por RPCs security definer que validan la
-- compra. El upsert ciego cliente->servidor permitía auto-escalado a premium.
drop policy if exists "usuario_gestiona_su_suscripcion" on public.suscripciones;
drop policy if exists "usuario_lee_su_suscripcion" on public.suscripciones;
create policy "usuario_lee_su_suscripcion"
  on public.suscripciones for select
  using (auth.uid() = usuario_id);

-- USOS DIARIOS: el usuario SOLO lee (el sync ya es solo-descarga y los RPCs
-- escriben como security definer). Con UPDATE propio se reseteaban los cupos.
drop policy if exists "usuario_gestiona_sus_usos_diarios" on public.usos_diarios;
drop policy if exists "usuario_lee_sus_usos_diarios" on public.usos_diarios;
create policy "usuario_lee_sus_usos_diarios"
  on public.usos_diarios for select
  using (auth.uid() = usuario_id);

-- VISITAS
drop policy if exists "usuario_ve_sus_visitas" on public.visitas;
create policy "usuario_ve_sus_visitas"
  on public.visitas for select
  using (auth.uid() = visitante_id or auth.uid() = visitado_id);

drop policy if exists "usuario_registra_sus_visitas" on public.visitas;
create policy "usuario_registra_sus_visitas"
  on public.visitas for insert
  with check (auth.uid() = visitante_id);

-- HISTORIAL LIKES
drop policy if exists "usuario_gestiona_sus_likes" on public.historial_likes;
create policy "usuario_gestiona_sus_likes"
  on public.historial_likes for all
  using (auth.uid() = usuario_id)
  with check (auth.uid() = usuario_id);

-- Fase 5: el likeado ve quién le dio like (necesario para "Le gustas",
-- el badge y que Realtime le entregue el evento bajo RLS).
drop policy if exists "usuario_ve_likes_recibidos" on public.historial_likes;
create policy "usuario_ve_likes_recibidos"
  on public.historial_likes for select
  using (auth.uid() = usuario_likeado_id);

-- RECHAZOS
drop policy if exists "usuario_gestiona_sus_rechazos" on public.rechazos;
create policy "usuario_gestiona_sus_rechazos"
  on public.rechazos for all
  using (auth.uid() = usuario_id)
  with check (auth.uid() = usuario_id);

-- CONVERSACIONES BORRADAS
-- Marcador "borre la conversacion solo para mi" (estilo WhatsApp). Cuando
-- los DOS participantes la marcan, el trigger borra fisicamente los mensajes
-- del par en el servidor: no queda basura ocupando espacio para siempre.
create table if not exists public.conversaciones_borradas (
  usuario_id      uuid not null references public.profiles(id) on delete cascade,
  otro_usuario_id uuid not null references public.profiles(id) on delete cascade,
  borrado_en      timestamptz default now(),
  primary key (usuario_id, otro_usuario_id)
);

create index if not exists conversaciones_borradas_otro_idx
  on public.conversaciones_borradas (otro_usuario_id);

alter table public.conversaciones_borradas enable row level security;

drop policy if exists "usuario_gestiona_sus_conversaciones_borradas" on public.conversaciones_borradas;
create policy "usuario_gestiona_sus_conversaciones_borradas"
  on public.conversaciones_borradas for all
  using (auth.uid() = usuario_id)
  with check (auth.uid() = usuario_id);

-- Limpieza automatica: al marcar B su borrado, si A tambien la marco, borra
-- los mensajes del par. El match y los likes se conservan (si uno escribe de
-- nuevo la conversacion renace normal). Los marcadores se conservan para que
-- una reinstalacion siga ocultando la conversacion; cada usuario elimina el
-- suyo al volver a escribir (lo hace el App).
create or replace function public.limpiar_conversacion_borrada_por_ambos()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if exists (
    select 1 from public.conversaciones_borradas cb
    where cb.usuario_id = new.otro_usuario_id
      and cb.otro_usuario_id = new.usuario_id
  ) then
    delete from public.messages
    where (emisor_id = new.usuario_id and receptor_id = new.otro_usuario_id)
       or (emisor_id = new.otro_usuario_id and receptor_id = new.usuario_id);
  end if;
  return new;
end;
$$;

drop trigger if exists conversaciones_borradas_limpieza on public.conversaciones_borradas;
create trigger conversaciones_borradas_limpieza
  after insert on public.conversaciones_borradas
  for each row execute function public.limpiar_conversacion_borrada_por_ambos();

-- ============================================================
-- TRIGGER: crear perfil automáticamente al registrarse
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, nombre, ubicacion_lat, ubicacion_lon)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'nombre', split_part(new.email, '@', 1)),
    0,
    0
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- TRIGGER: crear match automáticamente con like recíproco
-- ============================================================
create or replace function public.try_crear_match()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  a uuid := least(new.usuario_id, new.usuario_likeado_id);
  b uuid := greatest(new.usuario_id, new.usuario_likeado_id);
begin
  if exists (
    select 1 from public.historial_likes
    where usuario_id = new.usuario_likeado_id
      and usuario_likeado_id = new.usuario_id
  ) then
    insert into public.matches (usuario_a_id, usuario_b_id)
    values (a, b)
    on conflict (usuario_a_id, usuario_b_id) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists historial_likes_try_match on public.historial_likes;
create trigger historial_likes_try_match
  after insert on public.historial_likes
  for each row execute function public.try_crear_match();

-- ============================================================
-- Fuente canónica del plan (app + RPCs deben coincidir).
-- Orden (espejo de SuscripcionServicio.planActual en la app):
--  1. kill-switch: app_config.suscripciones_habilitadas = 'false' -> premium
--     (modo sin monetización: todo ilimitado, igual que en la app).
--  2. admin: profiles.is_admin = true -> premium.
--  3. suscripción activa y vigente; si no hay, gratis.
-- Independientemente de cómo se obtuvo el plan (fila suscripciones,
-- is_admin o kill-switch), todos los RPCs leen de aquí.
-- ============================================================
create or replace function public.plan_efectivo(p_uid uuid)
returns text
language plpgsql
security definer set search_path = public
as $$
declare
  v text;
  v_bool boolean := false;
begin
  if p_uid is null then
    return 'gratis';
  end if;

  select valor into v
    from public.app_config
   where clave = 'suscripciones_habilitadas';
  if v is not null and lower(v) = 'false' then
    return 'premium';
  end if;

  select coalesce(is_admin, false) into v_bool
    from public.profiles
   where id = p_uid;
  if v_bool then
    return 'premium';
  end if;

  select coalesce(plan, 'gratis') into v
    from public.suscripciones
   where usuario_id = p_uid
     and coalesce(activa, true) = true
     and (vence is null or vence > now());
  if v is null then
    -- Pila de planes: si el plan actual venció pero hay reserva con tiempo
    -- restante, la reserva es el plan efectivo. La reserva está PAUSADA:
    -- restante = vence_reserva - inicio_reserva (no se erosiona con el tiempo).
    -- Filas legacy sin inicio_reserva usan el criterio viejo (vence futuro).
    select plan_reserva into v
      from public.suscripciones
     where usuario_id = p_uid
       and plan_reserva is not null
       and ((inicio_reserva is not null
             and vence_reserva is not null
             and vence_reserva > inicio_reserva)
            or (inicio_reserva is null
             and (vence_reserva is null or vence_reserva > now())));
    if v is null then
      return 'gratis';
    end if;
  end if;
  return v;
end;
$$;

revoke all on function public.plan_efectivo(uuid) from public;
grant execute on function public.plan_efectivo(uuid) to authenticated;

-- ============================================================
-- FASE 3: RPC registrar_me_gusta (valida límite + like + match)
-- Retorna {match, likeado, limite}. El límite diario vive en
-- usos_diarios (server), no en el reloj del teléfono.
-- ============================================================
create or replace function public.registrar_me_gusta(perfil_id uuid, es_super boolean default false)
returns jsonb
language plpgsql
security definer set search_path = public
as $$
declare
  yo uuid := auth.uid();
  plane text := 'gratis';
  limite int := 0;
  usado int := 0;
  hay_match boolean := false;
begin
  if yo is null or perfil_id is null or perfil_id = yo then
    return jsonb_build_object('match', false, 'likeado', false, 'limite', false, 'error', 'destino_invalido');
  end if;

  -- Fuente canónica (admin / kill-switch / suscripción vigente).
  plane := public.plan_efectivo(yo);

  -- Límites por plan (espejo de LimitesPlan en la app):
  -- gratis: 15 me gustas/día, 0 superlikes; plus: -1 y 10; premium: -1 y -1.
  if plane = 'plus' then
    limite := case when es_super then 10 else -1 end;
  elsif plane = 'premium' then
    limite := -1;
  else
    limite := case when es_super then 0 else 15 end;
  end if;

  if es_super then
    select coalesce(superlikes_usados, 0) into usado
      from public.usos_diarios
     where usuario_id = yo and fecha = current_date;
  else
    select coalesce(me_gustas_usados, 0) into usado
      from public.usos_diarios
     where usuario_id = yo and fecha = current_date;
  end if;

  if limite >= 0 and usado >= limite then
    return jsonb_build_object('match', false, 'likeado', false, 'limite', true);
  end if;

  if es_super then
    insert into public.usos_diarios (usuario_id, fecha, superlikes_usados)
    values (yo, current_date, 1)
    on conflict (usuario_id, fecha) do update
      set superlikes_usados = public.usos_diarios.superlikes_usados + 1;
  else
    insert into public.usos_diarios (usuario_id, fecha, me_gustas_usados)
    values (yo, current_date, 1)
    on conflict (usuario_id, fecha) do update
      set me_gustas_usados = public.usos_diarios.me_gustas_usados + 1;
  end if;

  -- Like (sin duplicar el par); el trigger crea el match si es recíproco.
  insert into public.historial_likes (usuario_id, usuario_likeado_id, es_super)
  select yo, perfil_id, es_super
  where not exists (
    select 1 from public.historial_likes
    where usuario_id = yo and usuario_likeado_id = perfil_id
  );

  select exists (
    select 1 from public.matches m
    where (m.usuario_a_id = yo and m.usuario_b_id = perfil_id)
       or (m.usuario_a_id = perfil_id and m.usuario_b_id = yo)
  ) into hay_match;

  return jsonb_build_object('match', hay_match, 'likeado', true, 'limite', false);
end;
$$;

revoke all on function public.registrar_me_gusta(uuid, boolean) from public;
grant execute on function public.registrar_me_gusta(uuid, boolean) to authenticated;

-- ============================================================
-- FASE 3: RPC registrar_visita (sin límite)
-- ============================================================
create or replace function public.registrar_visita(perfil_id uuid)
returns jsonb
language plpgsql
security definer set search_path = public
as $$
declare
  yo uuid := auth.uid();
begin
  if yo is null or perfil_id is null or perfil_id = yo then
    return jsonb_build_object('error', 'destino_invalido');
  end if;

  -- Modo invisible: si el visitante tiene activado "ocultar visitas",
  -- la visita no se registra y nadie puede verla.
  if exists (
    select 1 from public.profiles
    where id = yo and ocultar_visitas = true
  ) then
    return jsonb_build_object('ok', true, 'ocultada', true);
  end if;

  insert into public.visitas (visitante_id, visitado_id)
  values (yo, perfil_id);

  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.registrar_visita(uuid) from public;
grant execute on function public.registrar_visita(uuid) to authenticated;

-- ============================================================
-- FASE 6: RPC registrar_deshacer (cupo de Deshacer en el servidor)
-- Retorna {ok, limite}. gratis: 1/día; plus/premium: -1 (ilimitado).
-- Si el cupo está agotado NO borra el rechazo.
-- Plan desde public.plan_efectivo (fuente canónica).
-- ============================================================
create or replace function public.registrar_deshacer(perfil_id uuid)
returns jsonb
language plpgsql
security definer set search_path = public
as $$
declare
  yo uuid := auth.uid();
  plane text := 'gratis';
  cupo int := 1;
  reg public.usos_diarios%rowtype;
begin
  if yo is null or perfil_id is null or perfil_id = yo then
    return jsonb_build_object('ok', false, 'limite', false, 'error', 'destino_invalido');
  end if;

  -- Fuente canónica (admin / kill-switch / suscripción vigente).
  plane := public.plan_efectivo(yo);

  if plane in ('plus', 'premium') then
    cupo := -1;
  end if;

  if cupo >= 0 then
    insert into public.usos_diarios (usuario_id, fecha, deshacer_usados)
    values (yo, current_date, 1)
    on conflict (usuario_id, fecha) do update
      set deshacer_usados = public.usos_diarios.deshacer_usados + 1
    returning * into reg;

    if reg.deshacer_usados > cupo then
      update public.usos_diarios
         set deshacer_usados = deshacer_usados - 1
       where usuario_id = yo and fecha = reg.fecha;
      return jsonb_build_object('ok', false, 'limite', true);
    end if;
  end if;

  delete from public.rechazos where usuario_id = yo and rechazado_id = perfil_id;

  return jsonb_build_object('ok', true, 'limite', false);
end;
$$;

revoke all on function public.registrar_deshacer(uuid) from public;
grant execute on function public.registrar_deshacer(uuid) to authenticated;

-- ============================================================
-- FUNCIÓN: verificar si un email ya está registrado
-- ============================================================
create or replace function public.email_existe(email_ingresado text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  return exists(
    select 1 from auth.users where email = email_ingresado
  );
end;
$$;

-- ============================================================
-- FUNCIÓN: normalizar género (para el feed y criterios base)
-- ============================================================
create or replace function public.normalizar_genero(valor text)
returns text
language sql
immutable
as $$
  select translate(lower(replace(replace(coalesce(valor, ''), ' ', ''), '_', '')), 'áéíóúüñ', 'aeiouun');
$$;

-- ============================================================
-- FUNCIÓN: ¿el género [genero] cumple la opción seleccionada?
-- ============================================================
create or replace function public.cumple_genero(opcion text, genero text)
returns boolean
language sql
immutable
as $$
  select case
    when normalizar_genero(opcion) in ('hombres', 'hombre')
      then normalizar_genero(genero) in ('hombre', 'hombretrans')
    when normalizar_genero(opcion) in ('mujeres', 'mujer')
      then normalizar_genero(genero) in ('mujer', 'mujertrans')
    when normalizar_genero(opcion) in ('nobinarias', 'nobinario')
      then normalizar_genero(genero) in ('nobinario', 'generofluido')
    else normalizar_genero(genero) = normalizar_genero(opcion)
  end;
$$;

-- ============================================================
-- FUNCIÓN: perfiles cercanos (feed de descubrimiento, online-first)
-- Aplica en el servidor: distancia, criterios base del perfil propio
-- (busca_genero + preferencia_edad), filtros del usuario, y exclusiones
-- (uno mismo, bloqueos, rechazados con 3+ Nopes, y ya gustados).
-- Los rechazados sin 3 Nopes llegan al cliente, que decide reciclarlos
-- (sin espera si no quedan nuevos, o tras la edad mínima si aún hay).
-- `filtros` (jsonb): ampliar(bool), orden('distancia'|'score'),
--   generos(text[]), edad_min(int), edad_max(int),
--   en_linea(bool), verificado(bool), ciudad(text).
-- ============================================================
create or replace function public.perfiles_cercanos(
  lat double precision default 0,
  lon double precision default 0,
  radio_metros int default 20000,
  filtros jsonb default '{}'::jsonb,
  desde int default 0,
  cuantos int default 10
)
returns setof public.profiles
language plpgsql
stable
security definer set search_path = public
as $$
declare
  yo uuid := auth.uid();
  busca text := 'otro';
  p_min int := 18;
  p_max int := 99;
  gen_extra text[];
  e_min int := 18;
  e_max int := 99;
  en_linea boolean := false;
  verificado boolean := false;
  ciudad text := '';
  ampliar boolean := false;
  orden text := 'distancia';
  clausulas text := '';
  ordenar text := '';
begin
  if yo is null then
    return;
  end if;

  select coalesce(busca_genero, 'otro'),
         coalesce(preferencia_edad_min, 18),
         coalesce(preferencia_edad_max, 99)
    into busca, p_min, p_max
    from public.profiles
   where id = yo;

  gen_extra := (select array_agg(e)
                  from jsonb_array_elements_text(filtros -> 'generos') as e);
  e_min := coalesce((filtros ->> 'edad_min')::int, 18);
  e_max := coalesce((filtros ->> 'edad_max')::int, 99);
  en_linea := coalesce((filtros ->> 'en_linea')::boolean, false);
  verificado := coalesce((filtros ->> 'verificado')::boolean, false);
  ciudad := coalesce(filtros ->> 'ciudad', '');
  ampliar := coalesce((filtros ->> 'ampliar')::boolean, false);
  orden := coalesce(filtros ->> 'orden', 'distancia');

  if radio_metros >= 0 then
    clausulas := clausulas || format(
      'and ST_DWithin(p.ubicacion, ST_SetSRID(ST_MakePoint($3, $2), 4326)::geography, $4) ');
  end if;

  if not ampliar and coalesce(busca, '') not in ('', 'todos', 'ambos', 'prefiero_no_decirlo', 'otro') then
    clausulas := clausulas ||
      'and exists (select 1 from unnest(string_to_array($5, '','')) as opciones(opcion) where public.cumple_genero(opciones.opcion, p.genero)) ';
  end if;

  if not ampliar and gen_extra is not null and cardinality(gen_extra) > 0 then
    clausulas := clausulas ||
      'and exists (select 1 from unnest($6::text[]) as opciones(opcion) where public.cumple_genero(opciones.opcion, p.genero)) ';
  end if;

  if not ampliar then
    clausulas := clausulas ||
      format('and p.edad between greatest($7, %s) and least($8, %s) ', p_min, p_max);
  end if;

  if not ampliar and en_linea then
    clausulas := clausulas ||
      'and p.ocultar_en_linea = false and p.ultima_conexion > now() - interval ''5 minutes'' ';
  end if;

  if not ampliar and verificado then
    clausulas := clausulas || 'and p.verificado_status = true ';
  end if;

  if not ampliar and ciudad <> '' then
    clausulas := clausulas ||
      'and lower(p.ciudad) like ''%'' || lower($9) || ''%'' ';
  end if;

  if orden = 'score' then
    ordenar := 'order by p.score_popularidad desc, p.id asc';
  else
    ordenar := 'order by ST_Distance(p.ubicacion, ST_SetSRID(ST_MakePoint($3, $2), 4326)::geography) asc, p.id asc';
  end if;

   return query execute format(
     'select p.* from public.profiles p
      where p.ubicacion is not null
        and p.id <> $1
        and p.ocultar_perfil = false
        and p.id not in (''00000000-0000-0000-0000-00000000000a'', ''00000000-0000-0000-0000-00000000000f'')
        %s
        and not exists (select 1 from public.blocks b
                        where (b.bloqueador_id = $1 and b.bloqueado_id = p.id)
                           or (b.bloqueador_id = p.id and b.bloqueado_id = $1))
        -- Sin veto permanente por nopes: el rechazo solo ordena/recicla en
        -- el cliente (VotosServicio.componerDeck) y el Deshacer borra la fila.
        -- El abuso por ciclado nope/deshacer ya lo frena el cupo de Deshacer.
        and not exists (select 1 from public.historial_likes h
                        where h.usuario_id = $1 and h.usuario_likeado_id = p.id)
     %s
     limit $10 offset $11',
    clausulas, ordenar)
    using yo, lat, lon, radio_metros, busca, gen_extra, e_min, e_max, ciudad, cuantos, desde;
end;
$$;

-- ============================================================
-- REALTIME: tablas publicadas para actualizaciones en vivo
-- ============================================================
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'profiles'
  ) then
    alter publication supabase_realtime add table public.profiles;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'historial_likes'
  ) then
    alter publication supabase_realtime add table public.historial_likes;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'visitas'
  ) then
    alter publication supabase_realtime add table public.visitas;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'matches'
  ) then
    alter publication supabase_realtime add table public.matches;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;

end $$;

-- ============================================================
-- SOPORTE: tickets de ayuda (Ayuda y soporte > Contactar con soporte).
-- El usuario escribe mensajes que se leen y responden desde admin_flumi.
-- No es un chat directo con el Administrador.
-- ============================================================
create table if not exists public.soporte_mensajes (
  id uuid primary key default uuid_generate_v4(),
  usuario_id uuid not null references public.profiles(id) on delete cascade,
  mensaje text not null,
  respuesta text not null default '',
  respondido boolean not null default false,
  creado_en timestamptz not null default now(),
  respondido_en timestamptz
);

create index if not exists soporte_usuario_idx on public.soporte_mensajes (usuario_id);
create index if not exists soporte_pendientes_idx on public.soporte_mensajes (respondido, creado_en);

alter table public.soporte_mensajes enable row level security;

-- Usuario: crea sus tickets y lee sus tickets + respuestas.
drop policy if exists "usuario_crea_soporte" on public.soporte_mensajes;
create policy "usuario_crea_soporte"
  on public.soporte_mensajes for insert
  with check (auth.uid() = usuario_id);

drop policy if exists "usuario_lee_soporte" on public.soporte_mensajes;
create policy "usuario_lee_soporte"
  on public.soporte_mensajes for select
  using (auth.uid() = usuario_id);

-- Admin: lectura y respuesta de todos los tickets.
drop policy if exists "admin_gestiona_soporte" on public.soporte_mensajes;
create policy "admin_gestiona_soporte"
  on public.soporte_mensajes for all
  using (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true))
  with check (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true));

-- Realtime para el panel admin (después del CREATE TABLE, si no ALTER falla
-- con 42P01 aunque el IF de publicación pase).
do $$
begin
  if to_regclass('public.soporte_mensajes') is not null
     and not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'soporte_mensajes'
  ) then
    alter publication supabase_realtime add table public.soporte_mensajes;
  end if;
end $$;

-- ============================================================
-- PUSH MÓVIL: tokens FCM + envío a la Edge Function
-- ============================================================
-- Tokens de dispositivo por usuario: los registra la app (FCM) al iniciar
-- sesión y los borra al cerrarla.
create table if not exists public.device_tokens (
  id uuid primary key default uuid_generate_v4(),
  usuario_id uuid not null references public.profiles(id) on delete cascade,
  token text not null unique,
  plataforma text not null default 'android',
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

alter table public.device_tokens enable row level security;

drop policy if exists "usuario_gestiona_sus_tokens" on public.device_tokens;
create policy "usuario_gestiona_sus_tokens"
  on public.device_tokens for all
  using (auth.uid() = usuario_id)
  with check (auth.uid() = usuario_id);

-- Preferencias de notificaciones (las sube la app; sin fila = todo ON).
-- Los triggers de push las respetan vía enviar_push_pg(p_categoria).
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

-- El cliente registra su token FCM (upsert por token).
create or replace function public.registrar_device_token(p_token text, p_plataforma text default 'android')
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'No autenticado';
  end if;
  insert into public.device_tokens (usuario_id, token, plataforma)
  values (auth.uid(), p_token, p_plataforma)
  on conflict (token) do update
  set usuario_id = excluded.usuario_id,
      plataforma = excluded.plataforma,
      actualizado_en = now();
end;
$$;

-- Al cerrar sesión el cliente elimina su token.
create or replace function public.eliminar_device_token(p_token text)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  delete from public.device_tokens
  where token = p_token and usuario_id = auth.uid();
end;
$$;

-- Configuración del envío: URL de la Edge Function y secreto compartido.
-- Rellenar tras desplegar la función (ver supabase/functions/enviar-push).
create table if not exists public.app_config (
  clave text primary key,
  valor text not null,
  tipo text not null check (tipo in ('push', 'config', 'feature'))
);

alter table public.app_config enable row level security;
drop policy if exists "app_config_solo_service" on public.app_config;
create policy "app_config_solo_service"
  on public.app_config for select
  using (auth.role() = 'service_role');

-- La app (authenticated) solo puede leer flags públicos (kill-switch de
-- suscripciones, mantenimiento y versión mínima), nunca los secretos push.
-- El RPC plan_efectivo (security definer) lee todo sin RLS, así app y
-- servidor comparten la misma fuente.
drop policy if exists "app_config_flag_publica" on public.app_config;
create policy "app_config_flag_publica"
  on public.app_config for select
  to authenticated
  using (clave in ('suscripciones_habilitadas', 'mantenimiento',
    'mantenimiento_mensaje', 'version_minima_build', 'actualizar_url',
    'actualizar_mensaje'));

-- El panel admin (usuarios is_admin) gestiona flags y datos de pago.
-- Sin esto, los upsert de admin_flumi fallan por RLS en silencio.
drop policy if exists "app_config_admin" on public.app_config;
create policy "app_config_admin"
  on public.app_config for all
  using (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true))
  with check (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true));

insert into public.app_config (clave, valor, tipo)
values
  ('push_url', 'https://gzozmebdrsdcupgvxuiv.supabase.co/functions/v1/enviar-push', 'push'),
  ('push_secret', 'HdSAjqJCMFko7DvLUblIigVBmx1eGNX8', 'push'),
  ('suscripciones_habilitadas', 'true', 'feature'),
  ('mantenimiento', 'false', 'feature'),
  ('mantenimiento_mensaje', 'Estamos mejorando Flumi para ti. Vuelve en unos minutos.', 'feature'),
  ('version_minima_build', '1', 'feature'),
  ('actualizar_url', '', 'feature'),
  ('actualizar_mensaje', 'Hay una nueva versión de Flumi con mejoras importantes. Actualiza para seguir usándola.', 'feature')
on conflict (clave) do nothing;

-- ============================================================
-- CONTENIDOS LEGALES / SOBRE NOSOTROS (editables desde admin_flumi).
-- Claves: terminos, privacidad, seguridad_infantil, licencias, contactos,
-- sobre_flumi. La app los muestra en Configuración > Sobre nosotros.
-- ============================================================
create table if not exists public.contenidos_legales (
  clave text primary key,
  titulo text not null,
  cuerpo text not null default '',
  actualizado_en timestamptz not null default now()
);

alter table public.contenidos_legales enable row level security;

drop policy if exists "contenidos_lectura" on public.contenidos_legales;
create policy "contenidos_lectura"
  on public.contenidos_legales for select
  using (auth.role() = 'authenticated');

drop policy if exists "contenidos_admin" on public.contenidos_legales;
create policy "contenidos_admin"
  on public.contenidos_legales for all
  using (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true))
  with check (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true));

insert into public.contenidos_legales (clave, titulo, cuerpo)
values
  ('terminos', 'Términos y condiciones de uso', 'Contenido en redacción.'),
  ('privacidad', 'Políticas de privacidad', 'Contenido en redacción.'),
  ('seguridad_infantil', 'Políticas de seguridad infantil', 'Contenido en redacción.'),
  ('licencias', 'Licencias', 'Contenido en redacción.'),
  ('contactos', 'Contactos', 'Contenido en redacción.'),
  ('sobre_flumi', 'Sobre Flumi', 'Contenido en redacción.')
on conflict (clave) do nothing;

-- ============================================================
-- PAGOS: configuración de datos de transferencia por método
-- Gestionado desde flumi_admin. La app lee la fila activa por método
-- y muestra tarjeta/QR/móvil. Si no hay fila, usa fallback local.
-- ============================================================
create table if not exists public.pagos_config (
  id uuid primary key default uuid_generate_v4(),
  metodo text not null check (metodo in ('transfermovil','enzona')),
  tarjeta_destino text not null default '',
  movil_confirmar text not null default '',
  qr_url text not null default '',
  concepto text not null default 'Flumi',
  activo boolean not null default true,
  actualizado_en timestamptz not null default now(),
  unique(metodo)
);

alter table public.pagos_config enable row level security;

drop policy if exists "pagos_config_lectura" on public.pagos_config;
create policy "pagos_config_lectura"
  on public.pagos_config for select
  using (auth.role() = 'authenticated');

drop policy if exists "pagos_config_admin" on public.pagos_config;
create policy "pagos_config_admin"
  on public.pagos_config for all
  using (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true))
  with check (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true));

-- Datos de prueba (EnZona usa el QR de prueba del repo)
insert into public.pagos_config (metodo, tarjeta_destino, movil_confirmar, qr_url, concepto, activo)
values
  ('transfermovil', '9225 9598 7143 2108', '+53 5 123 45 67', '', 'Flumi', true),
  ('enzona', '9225 9598 7143 2108', '+53 5 123 45 67', '', 'Flumi EnZona', true)
on conflict (metodo) do nothing;

-- Bucket para QR de pagos (Transfermóvil y EnZona). Público para que la app pueda mostrarlos sin auth.
insert into storage.buckets (id, name, public)
values ('pagos_qr', 'pagos_qr', true)
on conflict (id) do nothing;

-- Políticas de storage para pagos_qr: lectura pública, escritura solo admin/service_role
drop policy if exists "pagos_qr_lectura_publica" on storage.objects;
create policy "pagos_qr_lectura_publica"
  on storage.objects for select
  using (bucket_id = 'pagos_qr');

drop policy if exists "pagos_qr_escritura_admin" on storage.objects;
create policy "pagos_qr_escritura_admin"
  on storage.objects for all
  using (bucket_id = 'pagos_qr' and exists (select 1 from public.profiles where id = auth.uid() and is_admin = true))
  with check (bucket_id = 'pagos_qr' and exists (select 1 from public.profiles where id = auth.uid() and is_admin = true));

-- Admin: puede borrar las selfies de verificación tras revisarlas
-- (solo prefijo verificacion/ del bucket profile-photos).
drop policy if exists "verificacion_admin_borra" on storage.objects;
create policy "verificacion_admin_borra"
  on storage.objects for delete
  using (bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = 'verificacion'
    and exists (select 1 from public.profiles where id = auth.uid() and is_admin = true));

-- Envía un push sin bloquear la transacción que lo dispara.
-- Respeta public.notif_prefs del destinatario (sin fila = todo ON).
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
  -- NOTA: net.http_post VA CON NOTACIÓN NOMBRADA. Su firma es
  -- (url, body, params, headers, timeout): la llamada posicional anterior
  -- (v_url, v_headers, v_body) mandaba los headers como body y el body como
  -- params, por lo que x-flumi-secret nunca llegaba y la Edge Function
  -- respondía 401 en silencio.
  begin
    -- Prioridad: supabase_functions (interno, no necesita egress) > net.
    -- Si el primer transporte falla, se intenta con el segundo en vez de
    -- rendirse: cada intento queda en push_log para diagnóstico.
    if to_regnamespace('supabase_functions') is not null
       and to_regprocedure('supabase_functions.http_request(text,text,jsonb,jsonb)') is not null then
      begin
        perform supabase_functions.http_request(v_url, 'POST', v_headers, v_body);
        perform public.registrar_push_log(p_usuario_id, coalesce(p_categoria,'mensajes'), p_titulo, 'supabase_functions', true, 'ok');
        return;
      exception when others then
        perform public.registrar_push_log(p_usuario_id, coalesce(p_categoria,'mensajes'), p_titulo, 'supabase_functions', false, SQLERRM);
      end;
    end if;
    if to_regnamespace('net') is not null then
      begin
        perform net.http_post(url := v_url, body := v_body, headers := v_headers);
        perform public.registrar_push_log(p_usuario_id, coalesce(p_categoria,'mensajes'), p_titulo, 'net', true, 'ok');
        return;
      exception when others then
        perform public.registrar_push_log(p_usuario_id, coalesce(p_categoria,'mensajes'), p_titulo, 'net', false, SQLERRM);
      end;
    else
      perform public.registrar_push_log(p_usuario_id, coalesce(p_categoria,'mensajes'), p_titulo, 'ninguno', false, 'sin transporte: ni supabase_functions ni pg_net disponibles');
    end if;
  exception when others then
    -- Un fallo de push nunca debe romper el insert original.
    perform public.registrar_push_log(p_usuario_id, coalesce(p_categoria,'mensajes'), p_titulo, 'error', false, SQLERRM);
  end;
end;
$$;

-- Log de intentos de push (diagnóstico; sin esto los fallos son invisibles).
-- Solo el servidor escribe; nadie lee por API (se consulta en el dashboard).
create table if not exists public.push_log (
  id bigserial primary key,
  creado_en timestamptz not null default now(),
  usuario_id uuid,
  categoria text not null default '',
  titulo text not null default '',
  transporte text not null default '',
  ok boolean not null default false,
  detalle text not null default ''
);

alter table public.push_log enable row level security;

create or replace function public.registrar_push_log(
  p_usuario_id uuid,
  p_categoria text,
  p_titulo text,
  p_transporte text,
  p_ok boolean,
  p_detalle text
) returns void
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.push_log (usuario_id, categoria, titulo, transporte, ok, detalle)
  values (p_usuario_id, coalesce(p_categoria,''), coalesce(left(p_titulo,120),''), coalesce(p_transporte,''), coalesce(p_ok,false), coalesce(left(p_detalle,500),''));
  delete from public.push_log where creado_en < now() - interval '7 days';
exception when others then
  null;
end;
$$;

-- Trigger: avisar al destinatario de un mensaje nuevo.
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

drop trigger if exists notificar_push_mensaje_trg on public.messages;
create trigger notificar_push_mensaje_trg
  after insert on public.messages
  for each row execute function public.notificar_push_mensaje();

-- Trigger: avisar al likeado de un Me Gusta nuevo.
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

drop trigger if exists notificar_push_like_trg on public.historial_likes;
create trigger notificar_push_like_trg
  after insert on public.historial_likes
  for each row execute function public.notificar_push_like();

-- Trigger: avisar al visitado de una visita nueva.
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

drop trigger if exists notificar_push_visita_trg on public.visitas;
create trigger notificar_push_visita_trg
  after insert on public.visitas
  for each row execute function public.notificar_push_visita();

-- Trigger: avisar a ambos usuarios de un match nuevo.
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

drop trigger if exists notificar_push_match_trg on public.matches;
create trigger notificar_push_match_trg
  after insert on public.matches
  for each row execute function public.notificar_push_match();

-- ============================================================
-- PAGOS MANUALES (Transfermóvil / EnZona) — verificación segura
-- ============================================================
create table if not exists public.pagos (
  id uuid primary key default uuid_generate_v4(),
  usuario_id uuid not null references public.profiles(id) on delete cascade,
  metodo text not null check (metodo in ('transfermovil','enzona')),
  plan text not null check (plan in ('Flumi Plus','Flumi Premium')),
  dias int not null check (dias in (7,30,90)),
  monto int not null,
  tarjeta_destino text not null,
  movil_confirmar text not null,
  qr_url text not null default '',
  nro_transaccion text not null,
  estado text not null default 'pendiente' check (estado in ('pendiente','aprobado','rechazado')),
  creado_en timestamptz not null default now(),
  verificado_en timestamptz,
  verificado_por uuid references public.profiles(id),
  motivo_rechazo text,
  unique(nro_transaccion)
);

create index if not exists pagos_usuario_idx on public.pagos (usuario_id);
create index if not exists pagos_estado_idx on public.pagos (estado);
create index if not exists pagos_nro_idx on public.pagos (nro_transaccion);

alter table public.pagos enable row level security;

-- PAGOS: el usuario SOLO lee sus pagos. La creación pasa por solicitar_pago
-- (valida formato, monto, anti-replay y rate-limit). Con UPDATE propio se
-- falsificaba "aprobado" y con DELETE se borraba evidencia y rate-limit.
drop policy if exists "pagos_usuario_gestiona" on public.pagos;
drop policy if exists "pagos_usuario_lee" on public.pagos;
create policy "pagos_usuario_lee"
  on public.pagos for select
  using (auth.uid() = usuario_id);

drop policy if exists "pagos_admin_ve_todo" on public.pagos;
create policy "pagos_admin_ve_todo"
  on public.pagos for select
  using (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true));

drop policy if exists "pagos_admin_actualiza" on public.pagos;
create policy "pagos_admin_actualiza"
  on public.pagos for update
  using (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true))
  with check (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true));

-- Realtime para admin (pendientes en vivo)
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and tablename='pagos') then
    alter publication supabase_realtime add table public.pagos;
  end if;
end $$;

-- Solicitar pago: valida en servidor (monto, formato, anti-replay, rate-limit)
-- Si se adjunta prueba SMS (p_sms_nro/monto/remitente) y coincide con lo que
-- el usuario escribió + remitente esperado + monto, se auto-aprueba sin admin.
-- Limpieza de firmas viejas PRIMERO: REVOKE/GRANT fallan con 42883 si la firma
-- no existe, y CREATE OR REPLACE no puede cambiar la lista de argumentos.
drop function if exists public.solicitar_pago(text,text,int,text);
drop function if exists public.solicitar_pago(text,text,int,text,text,numeric,text);
drop function if exists public.solicitar_pago(text,text,int,text,text,numeric,text,text,text);
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
  if p_sms_nro is not null and p_sms_remitente is not null then
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
    perform public.enviar_push_pg(yo, 'Pago verificado', 'Tu suscripción ' || p_plan || ' (' || p_dias || ' días) está activa', 'regalos');
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

grant execute on function public.solicitar_pago(text,text,int,text,text,numeric,text,text,text) to authenticated;

-- Verificar pago (solo admin): aprueba/rechaza y activa suscripción
create or replace function public.verificar_pago(
  p_pago_id uuid,
  p_estado text,
  p_motivo text default null
) returns jsonb
language plpgsql
security definer set search_path = public
as $$
declare
  yo uuid := auth.uid();
  es_admin boolean := false;
  r public.pagos%rowtype;
  v_vence_actual timestamptz;
  v_plan_actual text;
  v_plan_nuevo text;
  v_reserva_plan text;
  v_reserva_vence timestamptz;
  v_reserva_inicio timestamptz;
  v_base timestamptz;
begin
  if yo is null then return jsonb_build_object('ok', false, 'error', 'no_autenticado'); end if;
  select coalesce(is_admin,false) into es_admin from public.profiles where id = yo;
  if not es_admin then return jsonb_build_object('ok', false, 'error', 'no_admin'); end if;
  p_estado := lower(trim(p_estado));
  if p_estado not in ('aprobado','rechazado') then return jsonb_build_object('ok', false, 'error', 'estado_invalido'); end if;

  select * into r from public.pagos where id = p_pago_id for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'no_encontrado'); end if;
  if r.estado <> 'pendiente' then return jsonb_build_object('ok', false, 'error', 'ya_verificado'); end if;

  update public.pagos
    set estado = p_estado,
        verificado_en = now(),
        verificado_por = yo,
        motivo_rechazo = case when p_estado='rechazado' then coalesce(p_motivo,'') else null end
    where id = p_pago_id;

  if p_estado = 'aprobado' then
    -- Activa/extiende suscripción (plan en minúsculas para la tabla
    -- suscripciones). Mismo plan: los días se suman a la vigencia restante.
    -- Cambio de plan con vigencia: el anterior queda en reserva PAUSADO
    -- (inicio_reserva = ahora) y se reanuda al vencer el nuevo.
    select plan, vence into v_plan_actual, v_vence_actual from public.suscripciones where usuario_id = r.usuario_id;
    v_plan_nuevo := case when r.plan = 'Flumi Premium' then 'premium' else 'plus' end;
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
    values (
      r.usuario_id,
      v_plan_nuevo,
      now(),
      v_base + (r.dias || ' days')::interval,
      true,
      v_reserva_plan,
      v_reserva_vence,
      v_reserva_inicio
    )
    on conflict (usuario_id) do update set
      plan = excluded.plan,
      inicio = excluded.inicio,
      vence = excluded.vence,
      activa = true,
      plan_reserva = excluded.plan_reserva,
      vence_reserva = excluded.vence_reserva,
      inicio_reserva = excluded.inicio_reserva;
    -- Notifica al usuario
    perform public.enviar_push_pg(r.usuario_id, 'Pago aprobado', 'Tu suscripción ' || r.plan || ' (' || r.dias || ' días) está activa', 'regalos');
  else
    perform public.enviar_push_pg(r.usuario_id, 'Pago rechazado', coalesce(p_motivo, 'Tu pago fue rechazado. Revisa el Nro. e intenta de nuevo.'), 'regalos');
  end if;

  return jsonb_build_object('ok', true, 'estado', p_estado);
end;
$$;

revoke all on function public.verificar_pago(uuid,text,text) from public;
grant execute on function public.verificar_pago(uuid,text,text) to authenticated;

-- ============================================================
-- Cancelar suscripción (propia): desactiva el plan y limpia la reserva.
-- El usuario ya no puede escribir suscripciones directo (SELECT-only).
-- ============================================================
create or replace function public.cancelar_suscripcion()
returns jsonb
language plpgsql
security definer set search_path = public
as $$
declare
  yo uuid := auth.uid();
begin
  if yo is null then return jsonb_build_object('ok', false, 'error', 'no_autenticado'); end if;
  update public.suscripciones
    set activa = false,
        plan_reserva = null,
        vence_reserva = null,
        inicio_reserva = null
    where usuario_id = yo;
  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.cancelar_suscripcion() from public;
grant execute on function public.cancelar_suscripcion() to authenticated;

-- ============================================================
-- Promover reserva (propia): si el plan actual venció y hay reserva con
-- tiempo restante (pausado), la activa. La app lo llama al detectar
-- vencimiento con reserva vigente.
-- ============================================================
create or replace function public.promover_reserva()
returns jsonb
language plpgsql
security definer set search_path = public
as $$
declare
  yo uuid := auth.uid();
  r public.suscripciones%rowtype;
  v_restante interval;
begin
  if yo is null then return jsonb_build_object('ok', false, 'error', 'no_autenticado'); end if;
  select * into r from public.suscripciones where usuario_id = yo;
  if not found then return jsonb_build_object('ok', false, 'error', 'sin_suscripcion'); end if;
  if r.plan_reserva is null then return jsonb_build_object('ok', false, 'error', 'sin_reserva'); end if;
  -- Cancelado explícito no se resucita: la cancelación limpia la reserva,
  -- pero si quedara resto legacy, no promover sobre un activa=false.
  if coalesce(r.activa, true) = false then
    return jsonb_build_object('ok', false, 'error', 'cancelado');
  end if;
  -- Solo promueve si el plan actual ya no está vigente
  if coalesce(r.activa, true) = true and (r.vence is null or r.vence > now()) then
    return jsonb_build_object('ok', false, 'error', 'plan_vigente');
  end if;
  -- Tiempo restante pausado; legacy sin inicio_reserva usa vence absoluto
  if r.inicio_reserva is not null and r.vence_reserva is not null and r.vence_reserva > r.inicio_reserva then
    v_restante := r.vence_reserva - r.inicio_reserva;
  elsif r.vence_reserva is not null and r.vence_reserva > now() then
    v_restante := r.vence_reserva - now();
  else
    return jsonb_build_object('ok', false, 'error', 'reserva_vencida');
  end if;
  update public.suscripciones
    set plan = r.plan_reserva,
        inicio = now(),
        vence = now() + v_restante,
        activa = true,
        plan_reserva = null,
        vence_reserva = null,
        inicio_reserva = null
    where usuario_id = yo;
  return jsonb_build_object('ok', true, 'plan', r.plan_reserva);
end;
$$;

revoke all on function public.promover_reserva() from public;
grant execute on function public.promover_reserva() to authenticated;

-- Herramienta admin: limpiar interacciones de pruebas (solo admin)
create or replace function public.limpiar_interacciones_pruebas()
returns jsonb
language plpgsql
security definer set search_path = public
as $$
declare
  yo uuid := auth.uid();
  es_admin boolean := false;
begin
  if yo is null then return jsonb_build_object('ok', false, 'error', 'no_autenticado'); end if;
  select coalesce(is_admin,false) into es_admin from public.profiles where id = yo;
  if not es_admin then return jsonb_build_object('ok', false, 'error', 'no_admin'); end if;

  delete from public.rechazos;
  delete from public.historial_likes;
  delete from public.visitas;
  delete from public.matches;
  delete from public.messages;
  delete from public.blocks;
  delete from public.reports;
  delete from public.usos_diarios;
  delete from public.pagos where estado = 'pendiente';
  delete from public.conversaciones_borradas;
  -- No borra profiles ni suscripciones ni pagos aprobados/rechazados (auditoría)
  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.limpiar_interacciones_pruebas() from public;
grant execute on function public.limpiar_interacciones_pruebas() to authenticated;
