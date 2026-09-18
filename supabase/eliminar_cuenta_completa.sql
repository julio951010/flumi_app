-- ============================================================
-- ELIMINAR CUENTA COMPLETA: Borra usuario, datos, storage y auth
-- Ejecutar en Supabase SQL Editor
-- ============================================================

-- Función para borrar completamente una cuenta
create or replace function public.eliminar_cuenta_completa()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_usuario_id uuid := auth.uid();
  v_foto_urls text[];
  v_url text;
begin
  if v_usuario_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  -- 1. Obtener URLs de fotos del usuario ANTES de borrar el perfil
  select fotos_urls into v_foto_urls from public.profiles where id = v_usuario_id;

  -- 2. Borrar archivos de Storage (profile-photos bucket)
  if array_length(v_foto_urls, 1) > 0 then
    foreach v_url in array v_foto_urls loop
      -- Extraer el path del archivo desde la URL pública
      -- Formato típico: https://xxx.supabase.co/storage/v1/object/public/profile-photos/archivo.jpg
      declare
        v_path text := regexp_replace(v_url, '^.*/storage/v1/object/public/[^/]+/', '');
      begin
        delete from storage.objects
        where bucket_id = 'profile-photos' and name = v_path;
      exception when others then
        -- Ignorar errores de archivos que no existan
      end;
    end loop;
  end if;

  -- 2. Borrar avatar del usuario si existe en bucket 'avatars'
  begin
    delete from storage.objects
    where bucket_id = 'avatars' and name like v_usuario_id || '%';
  exception when others then
    -- Ignorar errores
  end;

  -- 3. Borrar datos de la app (cascada borra tablas relacionadas por FK)
  -- El trigger on_auth_user_created creó el perfil, ahora lo borramos
  delete from public.profiles where id = v_usuario_id;

  -- 4. Borrar usuario de Auth (requiere service_role)
  -- NOTA: Esto requiere que la función se ejecute con service_role
  -- En Supabase, auth.uid() devuelve el usuario actual en la sesión
  -- Para borrar el usuario auth, usamos la función admin
  perform auth.delete_user(v_usuario_id);

  -- Si llegamos aquí, todo se borró correctamente
  return;
end;
$$;

-- Otorgar permisos para que el usuario pueda ejecutarla
grant execute on function public.eliminar_cuenta_completa() to authenticated;

-- Función alternativa usando RPC desde la app (llama a una Edge Function con service_role)
-- Si prefieres no usar service_role en la DB, usa una Edge Function

-- ============================================================
-- EDGE FUNCTION: eliminar-cuenta (alternativa recomendada)
-- ============================================================
-- En supabase/functions/eliminar-cuenta/index.ts:
--
-- import { createClient } from '@supabase/supabase-js'
-- 
-- Deno.serve(async (req) => {
--   const authHeader = req.headers.get('Authorization')!
--   const supabase = createClient(
--     Deno.env.get('SUPABASE_URL')!,
--     Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
--     { global: { headers: { Authorization: authHeader } } }
--   )
-- 
--   const { data: { user } } = await supabase.auth.getUser()
--   if (!user) return new Response('No autorizado', { status: 401 })
-- 
--   // 1. Borrar storage
--   const { data: files } = await supabase.storage
--     .from('profile-photos')
--     .list(`${user.id}/`, { limit: 100 })
--   if (files) {
--     await supabase.storage.from('profile-photos').remove(
--       files.map(f => `${user.id}/${f.name}`)
--     )
--   }
-- 
--   // 2. Borrar datos app (cascada)
--   await supabase.from('profiles').delete().eq('id', user.id)
-- 
--   // 3. Borrar usuario auth (requiere service_role)
--   await supabase.auth.admin.deleteUser(user.id)
-- 
--   return new Response(JSON.stringify({ success: true }), {
--     headers: { 'Content-Type': 'application/json' }
--   })
-- }

-- Para invocarla desde la app:
-- await supabase.functions.invoke('eliminar-cuenta')