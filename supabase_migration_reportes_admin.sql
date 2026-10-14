-- ============================================================
-- Moderación funcional: el admin lee los reportes REALES de la app
-- (la app escribe en `reports`; admin_flumi leía la tabla vacía
-- `reportes`). Además el botón Suspender del admin ahora sí oculta
-- al usuario del feed.
-- Ejecutar en Supabase Dashboard → SQL Editor. Idempotente.
-- ============================================================

-- ------------------------------------------------------------
-- 1) Workflow de estados en `reports` (el admin filtra por estado
--    y lo cambia: pendiente/revisado/desestimado/resuelto).
-- ------------------------------------------------------------
alter table public.reports
  add column if not exists estado text default 'pendiente'
    check (estado in ('pendiente','revisado','desestimado','resuelto'));

alter table public.reports
  add column if not exists resuelto_en timestamptz;

-- Backfill único: lo ya revisado queda como 'revisado'.
update public.reports
   set estado = 'revisado'
 where coalesce(revisado, false) = true
   and estado = 'pendiente';

-- Sincroniza estado <-> revisado/resuelto_en en ambos sentidos, para que
-- el auto-ocultado por reportes (que mira `revisado`) y los filtros del
-- admin (que miran `estado`) siempre coincidan, venga el cambio de donde
-- venga (panel admin o SQL directo).
create or replace function public.sync_reporte_estado()
returns trigger
language plpgsql
as $$
begin
  if NEW.estado = 'pendiente' then
    NEW.revisado := false;
    NEW.resuelto_en := null;
  else
    NEW.revisado := true;
    NEW.resuelto_en := coalesce(NEW.resuelto_en, now());
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_sync_reporte_estado on public.reports;
create trigger trg_sync_reporte_estado
  before insert or update on public.reports
  for each row execute function public.sync_reporte_estado();

-- ------------------------------------------------------------
-- 2) RLS: el admin lee y gestiona los reportes de la app.
-- ------------------------------------------------------------
drop policy if exists "admin_lee_reportes" on public.reports;
create policy "admin_lee_reportes"
  on public.reports for select
  using (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true));

drop policy if exists "admin_gestiona_reportes" on public.reports;
create policy "admin_gestiona_reportes"
  on public.reports for update
  using (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true))
  with check (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true));

-- ------------------------------------------------------------
-- 3) Suspender sí oculta del feed (antes el botón del admin solo
--    marcaba el flag y la app lo ignoraba).
-- ------------------------------------------------------------
alter table public.profiles
  add column if not exists suspendido boolean not null default false;

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
