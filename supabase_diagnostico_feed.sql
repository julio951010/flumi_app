-- ============================================================
-- DIAGNÓSTICO: ¿por qué no veo a una persona en el feed?
--
-- El feed (`perfiles_cercanos`) descarta un perfil por cualquiera de estas
-- razones, en este orden:
--   1. No tiene género            -> nunca coincide con mi preferencia.
--   2. La otra persona no me busca (género)   -> reciprocidad.
--   3. Edad fuera de su rango o de el mío     -> reciprocidad de edad.
--   4. Está sin ubicación real (lat/lon = 0,0) -> cae a miles de km.
--   5. Fuera del radio (20 km por defecto).
--   6. `ocultar_perfil` (modo invisible) o suspendida.
--   7. Bloqueo entre los dos, o reporte pendiente.
--   8. Ya le di Me Gusta (se mueve a "Me gusta", no al feed).
--
-- Uso: ejecutar en Supabase -> SQL Editor. Pon los dos UUID al final de cada
-- consulta. Para obtenerlos:
--   select id, nombre, genero, busca_genero, edad, ciudad from public.profiles;
-- ============================================================

-- ------------------------------------------------------------
-- 1) La ficha completa de ella (sin juzgar nada, solo datos)
-- ------------------------------------------------------------
select id,
       nombre,
       genero,
       busca_genero,
       edad,
       preferencia_edad_min,
       preferencia_edad_max,
       ciudad,
       ubicacion_lat,
       ubicacion_lon,
       (ubicacion_lat = 0 and ubicacion_lon = 0) as sin_gps_real,
       ocultar_perfil,
       coalesce(suspendido, false) as suspendida,
       perfil_completado,
       ultima_conexion
  from public.profiles
 where id = 'SU_ID_AQUI';

-- ------------------------------------------------------------
-- 2) La matriz de reciprocidad entre los dos
--    Todo debe dar `true` (y los km deben ser menores que el radio).
-- ------------------------------------------------------------
select y.nombre                       as yo,
       e.nombre                       as ella,
       e.genero                       as su_genero,
       e.busca_genero                 as ella_busca,
       y.busca_genero                 as yo_busco,
       coalesce(trim(e.genero), '') <> ''                              as tiene_genero,
       public.cumple_genero(coalesce(nullif(trim(y.busca_genero), ''), 'todos'), e.genero)
                                                                       as cumple_mi_filtro,
       (coalesce(e.busca_genero, '') in ('', 'todos', 'ambos', 'otro', 'prefiero_no_decirlo')
        or exists (
          select 1
            from unnest(string_to_array(coalesce(e.busca_genero, ''), ',')) as op(opcion)
           where public.cumple_genero(op.opcion, y.genero)
        ))                                                             as ella_me_busca,
       (coalesce(e.preferencia_edad_min, 18) <= y.edad
        and coalesce(e.preferencia_edad_max, 99) >= y.edad)            as edad_ella_me_incluye,
       (coalesce(y.preferencia_edad_min, 18) <= e.edad
        and coalesce(y.preferencia_edad_max, 99) >= e.edad)            as edad_yo_la_incluyo,
       round((public.ST_Distance(e.ubicacion, y.ubicacion) / 1000)::numeric, 1)
                                                                       as km_entre_los_dos,
       (not coalesce(e.ocultar_perfil, false))                         as visible_en_feed,
       (not coalesce(e.suspendido, false))                             as no_suspendida
  from public.profiles y
  cross join public.profiles e
 where y.id = 'MI_ID_AQUI'
   and e.id = 'SU_ID_AQUI';

-- ------------------------------------------------------------
-- 3) Exclusiones por historial: like previo, bloqueo o reporte
-- ------------------------------------------------------------
select exists (select 1 from public.historial_likes h
                where h.usuario_id = 'MI_ID_AQUI'
                  and h.usuario_likeado_id = 'SU_ID_AQUI')             as ya_le_di_like,
       exists (select 1 from public.blocks b
                where (b.bloqueador_id = 'MI_ID_AQUI' and b.bloqueado_id = 'SU_ID_AQUI')
                   or (b.bloqueador_id = 'SU_ID_AQUI' and b.bloqueado_id = 'MI_ID_AQUI'))
                                                                       as hay_bloqueo,
       exists (select 1 from public.reports r
                where r.reportante_id = 'MI_ID_AQUI'
                  and r.reportado_id = 'SU_ID_AQUI'
                  and coalesce(r.revisado, false) = false)             as reporte_pendiente;

-- ------------------------------------------------------------
-- 4) Prueba definitiva: ejecutar el feed real como si fuera yo.
--    Si ella sale aquí pero no en la app, el problema es la caché local
--    (hay que refrescar el feed) y no el servidor.
-- ------------------------------------------------------------
select set_config('request.jwt.claims',
                  json_build_object('sub', 'MI_ID_AQUI', 'role', 'authenticated')::text,
                  true);

select id, nombre, genero, edad
  from public.perfiles_cercanos(
         lat          => (select ubicacion_lat from public.profiles where id = 'MI_ID_AQUI'),
         lon          => (select ubicacion_lon from public.profiles where id = 'MI_ID_AQUI'),
         radio_metros => -1,          -- -1 = sin límite de distancia
         filtros      => '{}'::jsonb,
         desde        => 0,
         cuantos      => 500
       );
