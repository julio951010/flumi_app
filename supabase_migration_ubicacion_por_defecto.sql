-- ============================================================
-- UBICACIÓN POR DEFECTO + CAMPOS BLANDOS CON VALORES POR DEFECTO
--
-- Problema: perfiles sin ubicación real (0,0) quedaban invisibles (caían en
-- el Golfo de Guinea) y sin feed. Solución: nunca (0,0): si no hay coords
-- reales, se usan las de La Habana, Cuba y se marca `ubicacion_por_defecto`.
--
-- También se rellenan los campos "blandos" que antes podían quedar vacíos:
--   * busca_genero ''/'otro'/'prefiero_no_decirlo' -> 'todos'
--   * que_busca '' -> 'abierto_a_lo_que_surja'
--
-- Idempotente. Ejecutar en Supabase Dashboard -> SQL Editor.
-- ============================================================

alter table public.profiles add column if not exists ubicacion_por_defecto boolean default true;

-- Defaults para filas nuevas.
alter table public.profiles alter column ubicacion_lat set default 23.1136;
alter table public.profiles alter column ubicacion_lon set default -82.3666;
alter table public.profiles alter column busca_genero set default 'todos';
alter table public.profiles alter column que_busca set default 'abierto_a_lo_que_surja';

-- Normalizar datos existentes.
update public.profiles
   set ubicacion_lat = 23.1136,
       ubicacion_lon = -82.3666,
       ubicacion_por_defecto = true
 where coalesce(ubicacion_lat, 0) = 0
   and coalesce(ubicacion_lon, 0) = 0;

update public.profiles
   set busca_genero = 'todos'
 where lower(trim(coalesce(busca_genero, ''))) in ('', 'otro', 'prefiero_no_decirlo');

update public.profiles
   set que_busca = 'abierto_a_lo_que_surja'
 where coalesce(trim(que_busca), '') = '';

-- handle_new_user: nuevas cuentas nacen con coords de La Habana.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, nombre, ubicacion_lat, ubicacion_lon,
                              ubicacion_por_defecto, busca_genero, que_busca)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'nombre', split_part(new.email, '@', 1)),
    23.1136,
    -82.3666,
    true,
    'todos',
    'abierto_a_lo_que_surja'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

notify pgrst, 'reload schema';
