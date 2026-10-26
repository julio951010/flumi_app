-- ============================================================
-- MIGRACION SEGURIDAD FASE 5 (flumi_app + admin_flumi)
-- Correcciones sobre fases 2/3/4. Idempotente.
-- ============================================================

-- 1. Revertir revoke por columnas de fase 4 (inocuo pero inútil y
--    potencialmente rompedor). La privacidad real de profiles queda
--    para una fase posterior.
grant select on public.profiles to anon, authenticated;

-- 2. leido_hasta: grant + policy UPDATE (fase 3).
grant update (leido_hasta) on public.historial_likes to authenticated;

drop policy if exists "usuario_actualiza_leido_hasta" on public.historial_likes;
create policy "usuario_actualiza_leido_hasta"
  on public.historial_likes for update
  to authenticated
  using (auth.uid() = usuario_id or auth.uid() = usuario_likeado_id)
  with check (auth.uid() = usuario_id or auth.uid() = usuario_likeado_id);

-- 3. Mensajes: permitir responder a cuentas oficiales para cualquier plan.
--    (ver fase 2 actualizada)


-- 4. perfiles_cercanos: devolver columnas por nombre (returns table)
--    en lugar de setof profiles, para no depender del orden físico.
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
         -- Reportado y pendiente de revisiÃ³n: no sale en el feed del
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

