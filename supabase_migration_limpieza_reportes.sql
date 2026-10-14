-- ============================================================
-- Limpieza post-moderación: tabla `reportes` muerta + contenido muerto
-- La app escribe reportes en `reports` (que ahora lee admin_flumi); la
-- tabla `reportes` quedó vacía y sin uso. La clave `contactos` tampoco
-- se muestra en la app (la reemplazó Nuestras redes).
-- Ejecutar en Supabase Dashboard → SQL Editor. Idempotente.
-- ============================================================

-- Solo se borra si está vacía (seguridad: si algún día tuvo filas, no toca).
do $$
begin
  if to_regclass('public.reportes') is not null
     and not exists (select 1 from public.reportes) then
    drop policy if exists "admin_gestiona_reportes" on public.reportes;
    drop table public.reportes;
  end if;
end $$;

-- Contenido muerto (la app ya no lo muestra en ningún lado).
delete from public.contenidos_legales where clave = 'contactos';
