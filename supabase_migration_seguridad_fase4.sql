-- ============================================================
-- MIGRACION SEGURIDAD FASE 4 (flumi_app + admin_flumi)
-- Idempotente.
-- ============================================================

create or replace function public.obtener_mi_perfil()
returns setof public.profiles
language sql
stable
security definer set search_path = public
as $$
  select * from public.profiles where id = auth.uid();
$$;

revoke all on function public.obtener_mi_perfil() from public;
grant execute on function public.obtener_mi_perfil() to authenticated;

-- NOTA: el revoke por columnas NO tiene efecto cuando authenticated ya tiene
-- SELECT a nivel de tabla (caso por defecto en Supabase). Además, si llegara
-- a aplicarse, rompería updates de perfil y lecturas admin. Se deja la
-- privacidad real de profiles para una fase posterior (servir perfiles
-- ajenos por RPC / cerrar la política de SELECT).
