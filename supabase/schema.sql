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
  activa      boolean default true
);

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

drop policy if exists "usuario_crea_su_propio_perfil" on public.profiles;
create policy "usuario_crea_su_propio_perfil"
  on public.profiles for insert
  with check (auth.uid() = id);

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
-- mensajes, no pueden escribir ni responder. El admin las envía como el bot
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

-- SUSCRIPCIONES
drop policy if exists "usuario_gestiona_su_suscripcion" on public.suscripciones;
create policy "usuario_gestiona_su_suscripcion"
  on public.suscripciones for all
  using (auth.uid() = usuario_id)
  with check (auth.uid() = usuario_id);

-- USOS DIARIOS
drop policy if exists "usuario_gestiona_sus_usos_diarios" on public.usos_diarios;
create policy "usuario_gestiona_sus_usos_diarios"
  on public.usos_diarios for all
  using (auth.uid() = usuario_id)
  with check (auth.uid() = usuario_id);

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
    return 'gratis';
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

-- La app (authenticated) solo puede leer el kill-switch de suscripciones,
-- nunca los secretos push. El RPC plan_efectivo (security definer) lee
-- todo sin RLS, así app y servidor comparten la misma fuente.
drop policy if exists "app_config_flag_publica" on public.app_config;
create policy "app_config_flag_publica"
  on public.app_config for select
  to authenticated
  using (clave = 'suscripciones_habilitadas');

insert into public.app_config (clave, valor, tipo)
values
  ('push_url', 'https://gzozmebdrsdcupgvxuiv.supabase.co/functions/v1/enviar-push', 'push'),
  ('push_secret', 'HdSAjqJCMFko7DvLUblIigVBmx1eGNX8', 'push'),
  ('suscripciones_habilitadas', 'true', 'feature')
on conflict (clave) do nothing;

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
    'cuerpo', p_cuerpo
  );
  begin
    -- Prioridad: supabase_functions (interno, no necesita egress) > net (requiere egress)
    if to_regnamespace('supabase_functions') is not null then
      perform supabase_functions.http_request(v_url, 'POST', v_headers, v_body);
    elsif to_regnamespace('net') is not null then
      perform net.http_post(v_url, v_headers, v_body);
    end if;
  exception when others then
    -- Un fallo de push nunca debe romper el insert original.
    null;
  end;
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
