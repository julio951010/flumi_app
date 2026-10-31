-- ============================================================
-- MIGRACION SEGURIDAD FASE 8 (flumi_app) - CORRECCIONES DE FASE 5 Y 6
-- Idempotente. Se puede ejecutar tanto si la fase 5/6 NO se aplico como si
-- se aplico (la fase 6 ya tiene los delimitadores corregidos; lo que sigue
-- sin corregir en ella es lo de los puntos 2 a 5).
--
-- Corrige, con prueba de ejecucion sobre PostGIS + el esquema real:
--  1. perfiles_cercanos fallaba SIEMPRE al llamarla:
--       a) las columnas OUT de "returns table" chocan con las columnas de
--          profiles ("column reference busca_genero is ambiguous");
--       b) comilla-comilla::text dentro de un literal '...' genera una comilla
--          suelta (SQL dinamico invalido): se escribe cuatro comillas.
--  2. perfiles_publicos (vista) quedaba legible por ANON y por cualquier
--     usuario: se le quitan los permisos; solo la leen las RPC SECURITY DEFINER.
--  3. RPC de perfiles ajenos: maximo 200 ids, sin bloqueados ni suspendidos;
--     perfiles_cercanos: cuantos acotado a 1..500 (la app usa 10 y 500).
--  4. Storage: (storage.foldername(name))[1] es NULL en archivos de la raiz,
--     asi que "<> 'verificacion'" daba NULL y las fotos normales dejaban de
--     ser visibles para la API (listar/borrar/reemplazar). Se usa IS DISTINCT FROM.
--  5. historial_likes: "grant update (leido_hasta)" no limita nada mientras
--     authenticated tenga UPDATE a nivel de tabla (permitia redirigir un like
--     a otro usuario). Se revoca el UPDATE de tabla y queda solo leido_hasta.
--  7. registrar_instalacion (RPC anonima): tope de altas nuevas por hora.
--  6. Trigger de perfiles: exigir fecha_nacimiento SOLO al completar el perfil
--     (no en cada update): antes bloqueaba los latidos de presencia de los
--     usuarios antiguos sin fecha y tambien al panel admin al suspenderlos.
-- ============================================================

-- ------------------------------------------------------------
-- 1. perfiles_cercanos
-- ------------------------------------------------------------
drop function if exists public.perfiles_cercanos(double precision, double precision, integer, jsonb, integer, integer);

create or replace function public.perfiles_cercanos(
  lat double precision default 0,
  lon double precision default 0,
  radio_metros int default 20000,
  filtros jsonb default '{}'::jsonb,
  desde int default 0,
  cuantos int default 10
)
returns table (
  id uuid,
  nombre text,
  edad int,
  fecha_nacimiento date,
  biografia text,
  fotos_urls text[],
  preferencia_edad_min int,
  preferencia_edad_max int,
  genero text,
  busca_genero text,
  que_busca text,
  ciudad text,
  ubicacion_lat double precision,
  ubicacion_lon double precision,
  ubicacion geography,
  verificado_status boolean,
  score_popularidad int,
  ocultar_en_linea boolean,
  ocultar_edad boolean,
  perfil_completado boolean,
  orientacion_sexual text,
  situacion_sentimental text,
  intereses text[],
  altura text,
  educacion text,
  trabajo text,
  profesion text,
  preferencia_relacion text,
  bebe text,
  fuma text,
  hijos text,
  personalidad text,
  signo_zodiaco text,
  mascotas text,
  religion text,
  idiomas text,
  tatuajes text,
  preguntas_perfil jsonb,
  foto_verificacion text,
  gesto_verificacion text,
  ultima_conexion timestamptz,
  creado_en timestamptz,
  ocultar_perfil boolean,
  ocultar_visitas boolean,
  is_admin boolean,
  suspendido boolean,
  ocultar_ubicacion boolean
)
language plpgsql
stable
security definer set search_path = public
as $$
#variable_conflict use_column
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

  -- Tope por llamada: la sincronizacion de la app pide hasta 500 (sincronizarFeedCercano),
  -- el resto 10. Evita pedir volumenes arbitrarios en una sola llamada.
  cuantos := least(greatest(coalesce(cuantos, 10), 1), 500);
  desde := greatest(coalesce(desde, 0), 0);

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
     'select p.id, p.nombre, p.edad, null::date as fecha_nacimiento, p.biografia, p.fotos_urls, p.preferencia_edad_min, p.preferencia_edad_max, p.genero, p.busca_genero, p.que_busca, p.ciudad, 0::double precision as ubicacion_lat, 0::double precision as ubicacion_lon, null::geography as ubicacion, p.verificado_status, 0::int as score_popularidad, p.ocultar_en_linea, p.ocultar_edad, p.perfil_completado, ''''::text as orientacion_sexual, p.situacion_sentimental, p.intereses, p.altura, p.educacion, p.trabajo, p.profesion, p.preferencia_relacion, p.bebe, p.fuma, p.hijos, p.personalidad, p.signo_zodiaco, p.mascotas, ''''::text as religion, p.idiomas, p.tatuajes, p.preguntas_perfil, ''''::text as foto_verificacion, p.gesto_verificacion, case when p.ocultar_en_linea then null else p.ultima_conexion end as ultima_conexion, p.creado_en, p.ocultar_perfil, p.ocultar_visitas, false as is_admin, false as suspendido, p.ocultar_ubicacion from public.profiles p
      where p.ubicacion is not null
        and p.id <> $1
        and p.ocultar_perfil = false
        and coalesce(p.suspendido, false) = false
        and p.id not in (''00000000-0000-0000-0000-00000000000a'', ''00000000-0000-0000-0000-00000000000f'')
        %s
         and not exists (select 1 from public.blocks b
                         where (b.bloqueador_id = $1 and b.bloqueado_id = p.id)
                            or (b.bloqueador_id = p.id and b.bloqueado_id = $1))
         -- Reportado y pendiente de revision: no sale en el feed del
         -- reportante (si el admin lo desestima, vuelve a salir).
         and not exists (select 1 from public.reports r
                         where r.reportante_id = $1 and r.reportado_id = p.id
                           and coalesce(r.revisado, false) = false)
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

revoke execute on function public.perfiles_cercanos(double precision, double precision, integer, jsonb, integer, integer) from public, anon;
grant execute on function public.perfiles_cercanos(double precision, double precision, integer, jsonb, integer, integer) to authenticated;

-- ------------------------------------------------------------
-- 2. Vista perfiles_publicos: SOLO para las RPC (no accesible desde la API)
-- ------------------------------------------------------------
create or replace view public.perfiles_publicos as
select p.id, p.nombre, p.edad, null::date as fecha_nacimiento, p.biografia, p.fotos_urls, p.preferencia_edad_min, p.preferencia_edad_max, p.genero, p.busca_genero, p.que_busca, p.ciudad, 0::double precision as ubicacion_lat, 0::double precision as ubicacion_lon, null::geography as ubicacion, p.verificado_status, 0::int as score_popularidad, p.ocultar_en_linea, p.ocultar_edad, p.perfil_completado, ''::text as orientacion_sexual, p.situacion_sentimental, p.intereses, p.altura, p.educacion, p.trabajo, p.profesion, p.preferencia_relacion, p.bebe, p.fuma, p.hijos, p.personalidad, p.signo_zodiaco, p.mascotas, ''::text as religion, p.idiomas, p.tatuajes, p.preguntas_perfil, ''::text as foto_verificacion, p.gesto_verificacion, case when p.ocultar_en_linea then null else p.ultima_conexion end as ultima_conexion, p.creado_en, p.ocultar_perfil, p.ocultar_visitas, false as is_admin, false as suspendido, p.ocultar_ubicacion
from public.profiles p;

revoke all on public.perfiles_publicos from public, anon, authenticated;

-- ------------------------------------------------------------
-- 3. RPC de perfiles ajenos
-- ------------------------------------------------------------
create or replace function public.obtener_perfiles_publicos(p_ids uuid[])
returns setof public.perfiles_publicos
language sql
stable
security definer set search_path = public
as $$
  select v.*
    from public.perfiles_publicos v
   where auth.uid() is not null
     and v.id = any (p_ids[1:200])
     and exists (select 1 from public.profiles p
                  where p.id = v.id and not coalesce(p.suspendido, false))
     and not exists (select 1 from public.blocks b
                      where (b.bloqueador_id = auth.uid() and b.bloqueado_id = v.id)
                         or (b.bloqueador_id = v.id and b.bloqueado_id = auth.uid()));
$$;

create or replace function public.obtener_perfil_publico(p_user_id uuid)
returns setof public.perfiles_publicos
language sql
stable
security definer set search_path = public
as $$
  select * from public.obtener_perfiles_publicos(array[p_user_id]);
$$;

revoke all on function public.obtener_perfiles_publicos(uuid[]) from public, anon;
grant execute on function public.obtener_perfiles_publicos(uuid[]) to authenticated;
revoke all on function public.obtener_perfil_publico(uuid) from public, anon;
grant execute on function public.obtener_perfil_publico(uuid) to authenticated;

-- ------------------------------------------------------------
-- Lectura de profiles: solo el propio (los admins siguen leyendo todo con
-- admin_lee_todos_perfiles, de admin_setup.sql de admin_flumi).
-- ------------------------------------------------------------
drop policy if exists "perfiles_visibles_para_autenticados" on public.profiles;
drop policy if exists "usuario_lee_su_propio_perfil" on public.profiles;
create policy "usuario_lee_su_propio_perfil"
  on public.profiles for select
  using (auth.uid() = id);

-- ------------------------------------------------------------
-- 4. Storage: selfies de verificacion no listables; fotos normales SI
-- ------------------------------------------------------------
drop policy if exists "profile_photos_lectura_publica" on storage.objects;
create policy "profile_photos_lectura_publica"
  on storage.objects for select
  using (bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] is distinct from 'verificacion');

drop policy if exists "verificacion_admin_lectura" on storage.objects;
create policy "verificacion_admin_lectura"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = 'verificacion'
    and exists (select 1 from public.profiles where id = auth.uid() and is_admin = true));

-- ------------------------------------------------------------
-- 5. historial_likes: solo leido_hasta es actualizable por el cliente
-- ------------------------------------------------------------
revoke update on public.historial_likes from anon, authenticated;
grant update (leido_hasta) on public.historial_likes to authenticated;

-- ------------------------------------------------------------
-- 6. Trigger de columnas sensibles (fecha_nacimiento solo al completar)
-- ------------------------------------------------------------
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
    if new.fecha_nacimiento is not null then
      new.edad := extract(year from age(current_date, new.fecha_nacimiento))::int;
    end if;
    return new;
  end if;

  -- Completar el perfil exige fecha de nacimiento (verificacion de mayoria de
  -- edad). Solo al INSERTAR completo o en el UPDATE que lo completa: los
  -- perfiles antiguos sin fecha siguen pudiendo actualizarse (presencia, etc.).
  if coalesce(new.perfil_completado, false)
     and new.fecha_nacimiento is null
     and (TG_OP = 'INSERT' or not coalesce(old.perfil_completado, false)) then
    raise exception 'fecha_nacimiento requerida para completar el perfil';
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
    -- La fecha ya registrada no se puede borrar (evita fijar la edad a mano).
    if new.fecha_nacimiento is null and old.fecha_nacimiento is not null then
      new.fecha_nacimiento := old.fecha_nacimiento;
    end if;
  end if;

  if new.fecha_nacimiento is not null then
    new.edad := extract(year from age(current_date, new.fecha_nacimiento))::int;
  end if;
  return new;
end;
$$;

drop trigger if exists proteger_columnas_sensibles_trg on public.profiles;
create trigger proteger_columnas_sensibles_trg
  before insert or update on public.profiles
  for each row execute function public.proteger_columnas_sensibles();

-- ------------------------------------------------------------
-- 7. registrar_instalacion: endpoint ANONIMO (la anon key es publica).
--    Sin tope, cualquiera podia insertar millones de filas con UUID aleatorios
--    (llenar la base del plan gratuito y falsear las metricas). Se limitan las
--    altas NUEVAS a 2000 por hora; las filas existentes siguen actualizandose.
--    Ajusta el numero si esperas mas instalaciones por hora.
-- ------------------------------------------------------------
do $$
begin
  if to_regclass('public.instalaciones') is not null then
    create index if not exists instalaciones_creado_en_idx
      on public.instalaciones (creado_en);
  end if;
end $$;

create or replace function public.registrar_instalacion(
  p_id uuid,
  p_plataforma text default '',
  p_version text default ''
)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if p_id is null then
    return;
  end if;

  if exists (select 1 from public.instalaciones where id = p_id) then
    update public.instalaciones
       set ultima_vez = now(),
           version = left(coalesce(p_version, ''), 32),
           plataforma = left(coalesce(p_plataforma, ''), 32)
     where id = p_id;
    return;
  end if;

  if (select count(*) from public.instalaciones
       where creado_en > now() - interval '1 hour') >= 2000 then
    return;
  end if;

  insert into public.instalaciones (id, plataforma, version)
  values (p_id, left(coalesce(p_plataforma, ''), 32), left(coalesce(p_version, ''), 32))
  on conflict (id) do nothing;
end;
$$;

revoke all on function public.registrar_instalacion(uuid, text, text) from public;
grant execute on function public.registrar_instalacion(uuid, text, text) to anon, authenticated;
