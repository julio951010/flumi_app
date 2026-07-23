-- ============================================================
-- FLUMI — Esquema Supabase (PostgreSQL + PostGIS)
-- Fase 1 — MVP
-- ============================================================

create extension if not exists postgis;
create extension if not exists "uuid-ossp";

-- ------------------------------------------------------------
-- PROFILES
-- Extiende auth.users. El id coincide con auth.users.id.
-- ------------------------------------------------------------
create table public.profiles (
  id                    uuid primary key references auth.users(id) on delete cascade,
  nombre                text not null,
  fecha_nacimiento      date not null,  -- validado server-side, no solo "edad"
  biografia             text default '',
  fotos_urls            text[] default '{}',
  preferencia_edad_min  int default 18,
  preferencia_edad_max  int default 99,
  genero                text not null check (genero in ('hombre','mujer','otro')),
  busca_genero          text not null,
  ubicacion             geography(Point, 4326),  -- PostGIS: lon/lat
  verificado_status     boolean default false,
  score_popularidad     int default 0,
  ultima_conexion       timestamptz default now(),
  creado_en             timestamptz default now(),

  constraint edad_minima check (
    fecha_nacimiento <= (current_date - interval '18 years')
  )
);

create index profiles_ubicacion_idx on public.profiles using gist (ubicacion);

-- ------------------------------------------------------------
-- MATCHES
-- ------------------------------------------------------------
create table public.matches (
  id               uuid primary key default uuid_generate_v4(),
  usuario_a_id     uuid not null references public.profiles(id) on delete cascade,
  usuario_b_id     uuid not null references public.profiles(id) on delete cascade,
  timestamp_match  timestamptz default now(),

  constraint par_unico unique (usuario_a_id, usuario_b_id),
  constraint no_auto_match check (usuario_a_id <> usuario_b_id)
);

create index matches_usuario_a_idx on public.matches (usuario_a_id);
create index matches_usuario_b_idx on public.matches (usuario_b_id);

-- ------------------------------------------------------------
-- MESSAGES
-- ------------------------------------------------------------
create table public.messages (
  id             uuid primary key default uuid_generate_v4(),
  emisor_id      uuid not null references public.profiles(id) on delete cascade,
  receptor_id    uuid not null references public.profiles(id) on delete cascade,
  contenido      text not null,
  "timestamp"    timestamptz default now(),
  estado_envio   text default 'enviado' check (estado_envio in ('enviado','entregado','leido')),

  constraint no_auto_mensaje check (emisor_id <> receptor_id)
);

create index messages_emisor_idx on public.messages (emisor_id);
create index messages_receptor_idx on public.messages (receptor_id);
create index messages_conversacion_idx on public.messages (emisor_id, receptor_id, "timestamp");

-- ------------------------------------------------------------
-- REPORTS (moderación — requisito de tienda de apps)
-- ------------------------------------------------------------
create table public.reports (
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

-- ------------------------------------------------------------
-- BLOCKS
-- ------------------------------------------------------------
create table public.blocks (
  id             uuid primary key default uuid_generate_v4(),
  bloqueador_id  uuid not null references public.profiles(id) on delete cascade,
  bloqueado_id   uuid not null references public.profiles(id) on delete cascade,
  "timestamp"    timestamptz default now(),

  constraint par_bloqueo_unico unique (bloqueador_id, bloqueado_id)
);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
alter table public.profiles enable row level security;
alter table public.matches  enable row level security;
alter table public.messages enable row level security;
alter table public.reports  enable row level security;
alter table public.blocks   enable row level security;

-- PROFILES: cualquier usuario autenticado puede ver perfiles (para el feed),
-- pero solo el dueño puede modificar el suyo.
create policy "perfiles_visibles_para_autenticados"
  on public.profiles for select
  using (auth.role() = 'authenticated');

create policy "usuario_edita_su_propio_perfil"
  on public.profiles for update
  using (auth.uid() = id);

create policy "usuario_crea_su_propio_perfil"
  on public.profiles for insert
  with check (auth.uid() = id);

-- MESSAGES: solo emisor o receptor pueden ver/insertar el mensaje.
create policy "mensajes_visibles_solo_para_participantes"
  on public.messages for select
  using (auth.uid() = emisor_id or auth.uid() = receptor_id);

create policy "usuario_envia_mensajes_como_si_mismo"
  on public.messages for insert
  with check (auth.uid() = emisor_id);

-- MATCHES: solo visibles para los dos usuarios involucrados.
create policy "matches_visibles_solo_para_participantes"
  on public.matches for select
  using (auth.uid() = usuario_a_id or auth.uid() = usuario_b_id);

-- REPORTS: el usuario solo puede crear reportes como sí mismo,
-- y no puede leer reportes ajenos (solo moderación vía service_role).
create policy "usuario_crea_reportes_como_si_mismo"
  on public.reports for insert
  with check (auth.uid() = reportante_id);

-- BLOCKS: el usuario solo ve y crea sus propios bloqueos.
create policy "usuario_gestiona_sus_bloqueos"
  on public.blocks for all
  using (auth.uid() = bloqueador_id)
  with check (auth.uid() = bloqueador_id);

-- ============================================================
-- FUNCIÓN: perfiles cercanos (usada por el feed de descubrimiento)
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
