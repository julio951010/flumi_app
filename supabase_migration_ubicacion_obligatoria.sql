-- ============================================================
-- UBICACIÓN REAL OBLIGATORIA (feed cercano)
--
-- Sin coordenadas reales, el perfil cae en (0,0) (Golfo de Guinea): a miles
-- de km de cualquier usuario, así que no aparece en el feed de nadie y el
-- propio usuario tampoco recibe feed (el sincronizado se salta con lat/lon 0).
-- Antes se podía completar el onboarding escribiendo solo el nombre de la
-- ciudad, dejando lat/lon en 0.
--
-- La fila nace con (0,0) en el registro, por eso no se puede exigir en el
-- INSERT. Lo que se impide aquí es BORRARLA después: volver a (0,0) cuando
-- ya tenía coordenadas reales.
--
-- Complemento en la app: `UbicacionObligatoriaPantalla` bloquea el acceso
-- hasta que el perfil tenga ubicación real, y el onboarding exige coords.
--
-- Idempotente. Ejecutar en Supabase Dashboard -> SQL Editor.
-- ============================================================

-- Perfiles que hoy están sin ubicación real (hay que pedirles que la completen).
select id, nombre, ciudad, ubicacion_lat, ubicacion_lon, creado_en
  from public.profiles
 where coalesce(ubicacion_lat, 0) = 0
   and coalesce(ubicacion_lon, 0) = 0;

create or replace function public.validar_ubicacion_perfil()
returns trigger
language plpgsql
as $$
begin
  if coalesce(new.ubicacion_lat, 0) = 0
     and coalesce(new.ubicacion_lon, 0) = 0
     and not (coalesce(old.ubicacion_lat, 0) = 0
              and coalesce(old.ubicacion_lon, 0) = 0) then
    raise exception 'La ubicacion no puede quedar vacia';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_ubicacion_obligatoria on public.profiles;
create trigger profiles_ubicacion_obligatoria
  before update on public.profiles
  for each row execute function public.validar_ubicacion_perfil();

notify pgrst, 'reload schema';
