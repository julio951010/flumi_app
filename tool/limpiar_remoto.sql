-- Limpieza remota (Supabase): borra TODAS las interacciones de todos los
-- usuarios para empezar a probar de cero.
-- Ejecuta este SQL en el editor SQL del proyecto Supabase
-- (https://supabase.com/dashboard -> SQL Editor).
--
-- Se conservan: profiles (perfiles), suscripciones y profile-photos.
-- Incluye rechazos (Nopes): cada fila es un Nope y el conteo por perfil
-- depende de TODAS las filas, así que el borrado total resetea el conteo.

delete from public.rechazos;
delete from public.historial_likes;
delete from public.visitas;
delete from public.matches;
delete from public.messages;
delete from public.blocks;
delete from public.reports;
delete from public.usos_diarios;