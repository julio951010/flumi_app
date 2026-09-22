-- ============================================================
-- ELIMINAR CUENTA COMPLETA: Borra usuario, datos, storage y auth
-- ============================================================
-- ADVERTENCIA: la app NO usa esta función — usa la Edge Function
-- supabase/functions/eliminar-cuenta/index.ts, que es la que
-- realmente funciona. Este archivo queda solo como referencia de
-- cómo se intentó hacer directo en SQL, y por qué no sirve así:
--
-- `auth.delete_user(...)` NO es una función invocable desde SQL/RPC.
-- Borrar un usuario de auth.users requiere la Admin API de Supabase
-- (`supabase.auth.admin.deleteUser`), que solo puede llamarse desde
-- un contexto de servidor con la service_role key — nunca desde un
-- RPC plano, ni siquiera con `security definer`. Si se ejecuta esta
-- función tal cual, el último paso lanza un error y, al estar todo
-- dentro de una sola transacción implícita, se revierte TODO lo
-- anterior (storage y borrado de profiles incluidos) — es decir,
-- no se borra nada, aunque parezca que sí porque no hay excepción
-- visible hasta ese punto.

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

  -- 2. Borrar archivos de Storage (profile-photos bucket).
  -- Las fotos se guardan como '{usuario_id}_{timestamp}.jpg' en la RAÍZ
  -- del bucket (ver perfil_foto_servicio.dart), no en una carpeta por
  -- usuario, así que se borra por nombre de archivo directo, no por path.
  if array_length(v_foto_urls, 1) > 0 then
    foreach v_url in array v_foto_urls loop
      -- Extraer el nombre de archivo desde la URL pública
      -- Formato típico: https://xxx.supabase.co/storage/v1/object/public/profile-photos/{uuid}_{timestamp}.jpg
      declare
        v_nombre text := regexp_replace(v_url, '^.*/storage/v1/object/public/[^/]+/', '');
      begin
        delete from storage.objects
        where bucket_id = 'profile-photos' and name = v_nombre;
      exception when others then
        -- Ignorar errores de archivos que no existan
      end;
    end loop;
  end if;

  -- 3. Borrar datos de la app (cascada borra tablas relacionadas por FK)
  delete from public.profiles where id = v_usuario_id;

  -- 4. Borrar usuario de Auth: ESTO NO FUNCIONA DESDE AQUÍ.
  -- `auth.delete_user` no existe. Usa la Edge Function en su lugar.
  -- perform auth.delete_user(v_usuario_id);

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
-- El código real y actualizado de la Edge Function vive en:
--   supabase/functions/eliminar-cuenta/index.ts
-- (no se duplica aquí para evitar que las dos copias queden
-- desincronizadas — ya pasó una vez con la ruta de storage).

-- Para invocarla desde la app:
-- await supabase.functions.invoke('eliminar-cuenta')