-- ============================================================
-- RECIPROCIDAD EN EL FEED (como en otras apps de citas)
--
-- Antes: `perfiles_cercanos` filtraba solo por la preferencia del que
-- mira. Un hombre que buscaba hombres veia a un hombre que solo buscaba
-- mujeres (y podia gastarle un Me Gusta que nunca podia corresponderse).
--
-- Ahora:
--   * Un perfil solo aparece si AMBOS se cumplen (genero y edad).
--   * "Ampliar" relaja distancia/ciudad/edad y los filtros de conexion,
--     pero nunca el genero: quien dijo "solo mujeres" no ve hombres.
--   * `registrar_me_gusta` rechaza likes no reciprocos con
--     {no_reciproco:true} sin consumir cupo (protege datos viejos).
--
-- Idempotente. Ejecutar en Supabase Dashboard -> SQL Editor despues de
-- `supabase/schema.sql`.
-- ============================================================
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
  -- Datos propios para exigir reciprocidad (como Tinder/Bumble).
  mi_genero text := '';
  mi_edad int := 18;
begin
  if yo is null then
    return;
  end if;

  select coalesce(busca_genero, 'otro'),
         coalesce(preferencia_edad_min, 18),
         coalesce(preferencia_edad_max, 99),
         coalesce(genero, ''),
         coalesce(edad, 18)
    into busca, p_min, p_max, mi_genero, mi_edad
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

  -- Reciprocidad: el perfil solo aparece si YO también cumplo lo que esa
  -- persona busca. No se relaja con "ampliar" (ampliar solo suelta
  -- distancia/ciudad/edad propios): nadie debe ver ni gastar un Me Gusta
  -- en alguien que declaró no buscar su género.
  if coalesce(mi_genero, '') <> '' then
    clausulas := clausulas || format(
      $f$and (coalesce(p.busca_genero, '') in ('', 'todos', 'ambos', 'otro', 'prefiero_no_decirlo')
              or exists (
                select 1
                  from unnest(string_to_array(coalesce(p.busca_genero, ''), ',')) as op(opcion)
                 where public.cumple_genero(op.opcion, %L)
              )) $f$, mi_genero);
  end if;

  clausulas := clausulas || format(
    $f$and coalesce(p.preferencia_edad_min, 18) <= %s
        and coalesce(p.preferencia_edad_max, 99) >= %s $f$, mi_edad, mi_edad);

  if radio_metros >= 0 then
    clausulas := clausulas || format(
      'and ST_DWithin(p.ubicacion, ST_SetSRID(ST_MakePoint($3, $2), 4326)::geography, $4) ');
  end if;

  if coalesce(busca, '') not in ('', 'todos', 'ambos', 'prefiero_no_decirlo', 'otro') then
    clausulas := clausulas ||
      'and exists (select 1 from unnest(string_to_array($5, '','')) as opciones(opcion) where public.cumple_genero(opciones.opcion, p.genero)) ';
  end if;

  if gen_extra is not null and cardinality(gen_extra) > 0 then
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
     'select p.id, p.nombre, p.edad, null::date as fecha_nacimiento, p.biografia, p.fotos_urls, p.preferencia_edad_min, p.preferencia_edad_max, p.genero, p.busca_genero, p.que_busca, p.ciudad, 0::double precision as ubicacion_lat, 0::double precision as ubicacion_lon, null::geography as ubicacion, p.verificado_status, 0::int as score_popularidad, p.ocultar_en_linea, p.ocultar_edad, p.perfil_completado, ''::text as orientacion_sexual, p.situacion_sentimental, p.intereses, p.altura, p.educacion, p.trabajo, p.profesion, p.preferencia_relacion, p.bebe, p.fuma, p.hijos, p.personalidad, p.signo_zodiaco, p.mascotas, ''::text as religion, p.idiomas, p.tatuajes, p.preguntas_perfil, ''::text as foto_verificacion, p.gesto_verificacion, case when p.ocultar_en_linea then null else p.ultima_conexion end as ultima_conexion, p.creado_en, p.ocultar_perfil, p.ocultar_visitas, false as is_admin, false as suspendido, p.ocultar_ubicacion from public.profiles p
      where p.ubicacion is not null
        and p.id <> $1
        and p.ocultar_perfil = false
        and coalesce(p.suspendido, false) = false
        and p.id not in (''00000000-0000-0000-0000-00000000000a'', ''00000000-0000-0000-0000-00000000000f'')
        %s
         and not exists (select 1 from public.blocks b
                         where (b.bloqueador_id = $1 and b.bloqueado_id = p.id)
                            or (b.bloqueador_id = p.id and b.bloqueado_id = $1))
         -- Reportado y pendiente de revisión: no sale en el feed del
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
  -- Reciprocidad: no se permite gastar un Me Gusta en alguien que no busca
  -- mi género ni mi edad (el feed ya lo oculta; esto protege datos viejos).
  mi_genero text := '';
  mi_edad int := 18;
  reciproco boolean := true;
begin
  if yo is null or perfil_id is null or perfil_id = yo then
    return jsonb_build_object('match', false, 'likeado', false, 'limite', false, 'error', 'destino_invalido');
  end if;

  select coalesce(genero, ''), coalesce(edad, 18)
    into mi_genero, mi_edad
    from public.profiles
   where id = yo;

  select exists (
    select 1
      from public.profiles p
     where p.id = perfil_id
       and (
         coalesce(mi_genero, '') = ''
         or coalesce(p.busca_genero, '') in ('', 'todos', 'ambos', 'otro', 'prefiero_no_decirlo')
         or exists (
           select 1
             from unnest(string_to_array(coalesce(p.busca_genero, ''), ',')) as op(opcion)
            where public.cumple_genero(op.opcion, mi_genero)
         )
       )
       and coalesce(p.preferencia_edad_min, 18) <= mi_edad
       and coalesce(p.preferencia_edad_max, 99) >= mi_edad
  ) into reciproco;

  if not reciproco then
    return jsonb_build_object(
      'match', false, 'likeado', false, 'limite', false, 'no_reciproco', true);
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

-- Recarga el esquema en PostgREST para que los RPCs tomen el cambio.
notify pgrst, 'reload schema';