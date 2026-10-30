-- ============================================================
-- MIGRACION SEGURIDAD FASE 6 (flumi_app + admin_flumi)
-- Privacidad real de profiles + storage verificacion + menores.
-- ============================================================

-- Vista segura (sin columnas sensibles) para servir perfiles ajenos.
create or replace view public.perfiles_publicos as
select p.id, p.nombre, p.edad, null::date as fecha_nacimiento, p.biografia, p.fotos_urls, p.preferencia_edad_min, p.preferencia_edad_max, p.genero, p.busca_genero, p.que_busca, p.ciudad, 0::double precision as ubicacion_lat, 0::double precision as ubicacion_lon, null::geography as ubicacion, p.verificado_status, 0::int as score_popularidad, p.ocultar_en_linea, p.ocultar_edad, p.perfil_completado, ''::text as orientacion_sexual, p.situacion_sentimental, p.intereses, p.altura, p.educacion, p.trabajo, p.profesion, p.preferencia_relacion, p.bebe, p.fuma, p.hijos, p.personalidad, p.signo_zodiaco, p.mascotas, ''::text as religion, p.idiomas, p.tatuajes, p.preguntas_perfil, ''::text as foto_verificacion, p.gesto_verificacion, case when p.ocultar_en_linea then null else p.ultima_conexion end as ultima_conexion, p.creado_en, p.ocultar_perfil, p.ocultar_visitas, false as is_admin, false as suspendido, p.ocultar_ubicacion
from public.profiles p;

-- RPCs para leer perfiles ajenos (security definer).
create or replace function public.obtener_perfil_publico(p_user_id uuid)
returns setof public.perfiles_publicos
language sql
stable
security definer set search_path = public
as $$
  select * from public.perfiles_publicos where id = p_user_id;
$$;

create or replace function public.obtener_perfiles_publicos(p_ids uuid[])
returns setof public.perfiles_publicos
language sql
stable
security definer set search_path = public
as $$
  select * from public.perfiles_publicos where id = any(p_ids);
$$;

revoke all on function public.obtener_perfil_publico(uuid) from public;
grant execute on function public.obtener_perfil_publico(uuid) to authenticated;

revoke all on function public.obtener_perfiles_publicos(uuid[]) from public;
grant execute on function public.obtener_perfiles_publicos(uuid[]) to authenticated;

-- Cerrar lectura de profiles: solo el propio.
drop policy if exists "perfiles_visibles_para_autenticados" on public.profiles;
drop policy if exists "usuario_lee_su_propio_perfil" on public.profiles;
create policy "usuario_lee_su_propio_perfil"
  on public.profiles for select
  using (auth.uid() = id);

-- Storage: selfies de verificacion no listables por usuarios normales.
drop policy if exists "profile_photos_lectura_publica" on storage.objects;
create policy "profile_photos_lectura_publica"
  on storage.objects for select
  using (bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] <> 'verificacion');

drop policy if exists "verificacion_admin_lectura" on storage.objects;
create policy "verificacion_admin_lectura"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = 'verificacion'
    and exists (select 1 from public.profiles where id = auth.uid() and is_admin = true));
