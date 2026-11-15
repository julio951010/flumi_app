-- ============================================================
-- DIAGNÓSTICO: ¿por qué no veo a una persona en el feed?
--
-- ⚠️ ANTES DE EJECUTAR: sustituye los dos marcadores por los UUID reales.
--    'MI_ID_AQUI'   -> tu id
--    'SU_ID_AQUI'   -> el id de la otra persona
--
-- Para obtenerlos, ejecuta primero la sección 0 (lista todos los perfiles).
--
-- Las comparaciones usan `id::text`, así que si te olvidas de sustituir un
-- marcador la consulta NO falla: devuelve una fila con
-- `falta_id_mio` / `falta_id_ella` en true.
--
-- El feed (`perfiles_cercanos`) descarta un perfil por cualquiera de estas
-- razones, en este orden:
--   1. No tiene género            -> nunca coincide con mi preferencia.
--   2. La otra persona no me busca (género)   -> reciprocidad.
--   3. Edad fuera de su rango o del mío       -> reciprocidad de edad.
--   4. Está sin ubicación real (lat/lon = 0,0) -> cae a miles de km.
--   5. Fuera del radio (20 km por defecto).
--   6. `ocultar_perfil` (modo invisible) o suspendida.
--   7. Bloqueo entre los dos, o reporte pendiente.
--   8. Ya le di Me Gusta (se mueve a "Me gusta", no al feed).
-- ============================================================

-- ------------------------------------------------------------
-- 0) Lista de perfiles (de aquí salen los dos UUID)
-- ------------------------------------------------------------
select id,
       nombre,
       genero,
       busca_genero,
       edad,
       ciudad
  from public.profiles
 order by creado_en;

-- ------------------------------------------------------------
-- 1) La ficha completa de ella (datos crudos)
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
 where id::text = 'SU_ID_AQUI';

-- ------------------------------------------------------------
-- 2) Matriz de reciprocidad + motivos en texto claro.
--    Si `motivos` sale vacío, el servidor SÍ debería mostrarla: el problema
--    estaría en la caché local del teléfono (refresca el feed).
-- ------------------------------------------------------------
select *,
       coalesce(nullif(concat_ws(' · ',
         case when falta_id_mio then 'falta MI_ID_AQUI' end,
         case when falta_id_ella then 'falta SU_ID_AQUI' end,
         case when not tiene_genero then 'ella no tiene género (invisible para quien busca un género concreto)' end,
         case when tiene_genero and not cumple_mi_filtro then 'su género no entra en tu preferencia' end,
         case when not ella_me_busca then 'ella no busca tu género (reciprocidad)' end,
         case when not edad_ella_me_incluye then 'tu edad queda fuera de su rango de edad' end,
         case when not edad_yo_la_incluyo then 'su edad queda fuera de tu rango de edad' end,
         case when sin_gps_real then 'ella no tiene ubicación real (lat/lon = 0,0)' end,
         case when not visible_en_feed then 'ella tiene el modo invisible activado (ocultar_perfil)' end,
         case when not no_suspendida then 'ella está suspendida' end,
         case when km_entre_los_dos is not null and km_entre_los_dos > 20
              then 'está fuera del radio por defecto de 20 km' end
       ), ''), '(sin bloqueos de servidor)') as motivos
  from (
    select (select id from public.profiles where id::text = 'MI_ID_AQUI') as yo_id,
           (select id from public.profiles where id::text = 'SU_ID_AQUI') as ella_id,
           y.nombre as yo,
           e.nombre as ella,
           e.genero as su_genero,
           e.busca_genero as ella_busca,
           y.busca_genero as yo_busco,
           (e.id is null) as falta_id_ella,
           (y.id is null) as falta_id_mio,
           coalesce(trim(e.genero), '') <> '' as tiene_genero,
           coalesce(public.cumple_genero(
             coalesce(nullif(trim(y.busca_genero), ''), 'todos'), e.genero), false)
             as cumple_mi_filtro,
           coalesce(
             coalesce(e.busca_genero, '') in ('', 'todos', 'ambos', 'otro', 'prefiero_no_decirlo')
             or exists (
               select 1
                 from unnest(string_to_array(coalesce(e.busca_genero, ''), ',')) as op(opcion)
                where public.cumple_genero(op.opcion, y.genero)
             ), false) as ella_me_busca,
           coalesce(coalesce(e.preferencia_edad_min, 18) <= y.edad
                and coalesce(e.preferencia_edad_max, 99) >= y.edad, false)
             as edad_ella_me_incluye,
           coalesce(coalesce(y.preferencia_edad_min, 18) <= e.edad
                and coalesce(y.preferencia_edad_max, 99) >= e.edad, false)
             as edad_yo_la_incluyo,
           coalesce(e.ubicacion_lat = 0 and e.ubicacion_lon = 0, false) as sin_gps_real,
           round((public.ST_Distance(e.ubicacion, y.ubicacion) / 1000)::numeric, 1) as km_entre_los_dos,
           (e.id is not null and not coalesce(e.ocultar_perfil, false)) as visible_en_feed,
           (e.id is not null and not coalesce(e.suspendido, false)) as no_suspendida
      from (select 1) dummy
      left join public.profiles y on y.id::text = 'MI_ID_AQUI'
      left join public.profiles e on e.id::text = 'SU_ID_AQUI'
  ) t;

-- ------------------------------------------------------------
-- 3) Exclusiones por historial: like previo, bloqueo o reporte
-- ------------------------------------------------------------
select exists (select 1 from public.historial_likes h
                where h.usuario_id::text = 'MI_ID_AQUI'
                  and h.usuario_likeado_id::text = 'SU_ID_AQUI')            as ya_le_di_like,
       exists (select 1 from public.blocks b
                where (b.bloqueador_id::text = 'MI_ID_AQUI' and b.bloqueado_id::text = 'SU_ID_AQUI')
                   or (b.bloqueador_id::text = 'SU_ID_AQUI' and b.bloqueado_id::text = 'MI_ID_AQUI'))
                                                                           as hay_bloqueo,
       exists (select 1 from public.reports r
                where r.reportante_id::text = 'MI_ID_AQUI'
                  and r.reportado_id::text = 'SU_ID_AQUI'
                  and coalesce(r.revisado, false) = false)                 as reporte_pendiente;

-- ------------------------------------------------------------
-- 4) Prueba definitiva: ejecutar el feed real como si fuera yo, SIN límite
--    de distancia (radio_metros = -1). Si ella sale aquí pero no en la app,
--    el problema es la caché local del teléfono, no el servidor.
-- ------------------------------------------------------------
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', (select id from public.profiles where id::text = 'MI_ID_AQUI')::text,
    'role', 'authenticated'
  )::text,
  true
);

select id, nombre, genero, edad
  from public.perfiles_cercanos(
         lat          => (select ubicacion_lat from public.profiles where id::text = 'MI_ID_AQUI'),
         lon          => (select ubicacion_lon from public.profiles where id::text = 'MI_ID_AQUI'),
         radio_metros => -1,
         filtros      => '{}'::jsonb,
         desde        => 0,
         cuantos      => 500
       );
