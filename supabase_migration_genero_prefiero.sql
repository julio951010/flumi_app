-- ============================================================
-- RETIRO DE "PREFIERO NO DECIRLO" EN "¿A QUIÉN QUIERES CONOCER?"
--
-- La app ya no ofrece esa opción: en el servidor funcionaba como comodín
-- (el perfil se mostraba a todo el mundo y veía a todo el mundo), lo
-- contrario de lo que sugiere la etiqueta. Ahora se queda solo el comodín
-- explícito: "Todos/as" ('todos').
--
-- Esta migración no cambia columnas ni políticas: solo normaliza los datos
-- que quedaron guardados con los valores retirados.
--   * 'prefiero_no_decirlo' -> 'todos'
--   * 'otro'                -> 'todos'  (valor legacy, misma semántica)
--
-- Idempotente: al ejecutarla otra vez no queda ninguna fila que cambiar.
-- Ejecutar en Supabase Dashboard -> SQL Editor.
-- ============================================================

-- Antes: cuántos perfiles quedarían afectados (opcional, solo informativo).
select busca_genero, count(*) as perfiles
  from public.profiles
 where lower(trim(coalesce(busca_genero, ''))) in ('prefiero_no_decirlo', 'otro')
 group by busca_genero;

update public.profiles
   set busca_genero = 'todos'
 where lower(trim(coalesce(busca_genero, ''))) in ('prefiero_no_decirlo', 'otro');

-- Recarga el esquema en PostgREST (los RPCs ya toleran los valores viejos,
-- pero así el cambio de datos se ve al instante).
notify pgrst, 'reload schema';
