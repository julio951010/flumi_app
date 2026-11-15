-- ============================================================
-- GÉNERO OBLIGATORIO (reciprocidad del feed)
--
-- Sin género, `cumple_genero()` nunca coincide y el perfil se vuelve
-- invisible para cualquiera que busque un género concreto ("Mujeres"), aunque
-- esa persona sí lo vea a él. El dato debe estar siempre.
--
-- La fila del perfil nace con el registro (auth trigger) sin género, por eso
-- no se puede exigir en el INSERT. Lo que se impide aquí es BORRARLO o
-- dejarlo vacío en una actualización: así un APK viejo o una caché local
-- incompleta no pueden volver a dejar el perfil invisible.
--
-- Complemento en la app: `GeneroObligatorioPantalla` bloquea el acceso hasta
-- que el perfil tenga género.
--
-- Idempotente. Ejecutar en Supabase Dashboard -> SQL Editor.
-- ============================================================

-- Perfiles que hoy están sin género (hay que pedirles que lo completen).
select id, nombre, created_at
  from public.profiles
 where coalesce(trim(genero), '') = '';

create or replace function public.validar_genero_perfil()
returns trigger
language plpgsql
as $$
begin
  if coalesce(trim(new.genero), '') = ''
     and coalesce(trim(old.genero), '') <> '' then
    raise exception 'El genero no puede quedar vacio';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_genero_obligatorio on public.profiles;
create trigger profiles_genero_obligatorio
  before update on public.profiles
  for each row execute function public.validar_genero_perfil();

notify pgrst, 'reload schema';
