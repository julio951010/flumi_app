-- ============================================================
-- RLS Storage bucket profile-photos (fotos + verificación)
-- Archivos: '{uuid}_{ts}.jpg' en raíz y 'verificacion/{uuid}_{ts}.jpg'.
-- Ejecutar en Supabase Dashboard → SQL Editor.
--
-- PASO 0 (obligatorio): listar policies existentes y ELIMINAR cualquiera
-- permisiva sobre este bucket (p. ej. plantillas "allow all" del dashboard),
-- o estas restricciones no sirven de nada:
--   select policyname, cmd, roles, qual
--   from pg_policies
--   where schemaname = 'storage' and tablename = 'objects'
--     and (qual ilike '%profile-photos%' or with_check ilike '%profile-photos%');
--   drop policy "<nombre_permisiva>" on storage.objects;  -- repetir por cada una
-- ============================================================

-- Lectura pública de fotos normales (las URLs de getPublicUrl deben abrir sin login).
-- Las selfies de verificación NO son públicas.
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

-- Subida: SOLO archivos propios ({mi_uuid}_* o verificacion/{mi_uuid}_*).
-- starts_with (no LIKE): el '_' de LIKE es comodín y permitiría prefijos
-- ajenos; con starts_with la coincidencia es exacta (36 chars + '_').
drop policy if exists "profile_photos_subida_propia" on storage.objects;
create policy "profile_photos_subida_propia"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'profile-photos'
    and (
      starts_with(name, auth.uid()::text || '_')
      or starts_with(name, 'verificacion/' || auth.uid()::text || '_')
    )
  );

-- Renombrar/mover: solo archivos propios.
drop policy if exists "profile_photos_actualiza_propia" on storage.objects;
create policy "profile_photos_actualiza_propia"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'profile-photos'
    and (
      starts_with(name, auth.uid()::text || '_')
      or starts_with(name, 'verificacion/' || auth.uid()::text || '_')
    )
  )
  with check (
    bucket_id = 'profile-photos'
    and (
      starts_with(name, auth.uid()::text || '_')
      or starts_with(name, 'verificacion/' || auth.uid()::text || '_')
    )
  );

-- Borrado: solo archivos propios. (El borrado admin de verificación
-- sigue cubierto por la policy "verificacion_admin_borra".)
drop policy if exists "profile_photos_borra_propia" on storage.objects;
create policy "profile_photos_borra_propia"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'profile-photos'
    and (
      starts_with(name, auth.uid()::text || '_')
      or starts_with(name, 'verificacion/' || auth.uid()::text || '_')
    )
  );

-- NOTA: la carpeta profile-photos/models (pesos face-api.js, si se usan)
-- queda solo-lectura para usuarios; súbela por dashboard o service_role.
