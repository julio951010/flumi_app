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

revoke select (fecha_nacimiento, ubicacion_lat, ubicacion_lon, ubicacion, orientacion_sexual, religion, foto_verificacion, is_admin, score_popularidad, suspendido) on public.profiles from anon, authenticated;
