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
  "timestamp"       timestamptz default now()
);

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
alter table public.visitas         enable row level security;
alter table public.historial_likes enable row level security;

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

-- MATCHES
drop policy if exists "matches_visibles_solo_para_participantes" on public.matches;
create policy "matches_visibles_solo_para_participantes"
  on public.matches for select
  using (auth.uid() = usuario_a_id or auth.uid() = usuario_b_id);

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
-- FUNCIÓN: perfiles cercanos (feed de descubrimiento)
-- ============================================================
create or replace function public.perfiles_cercanos(
  lat double precision,
  lon double precision,
  radio_metros int default 20000
)
returns setof public.profiles
language sql
stable
as $$
  select *
  from public.profiles
  where ubicacion is not null
    and ST_DWithin(
      ubicacion,
      ST_SetSRID(ST_MakePoint(lon, lat), 4326)::geography,
      radio_metros
    )
    and id <> auth.uid()
    and id not in (select bloqueado_id from public.blocks where bloqueador_id = auth.uid())
    and id not in (select bloqueador_id from public.blocks where bloqueado_id = auth.uid());
$$;
