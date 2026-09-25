-- ============================================================
-- PUSH: respetar preferencias del destinatario — ARCHIVADO.
--
-- Todo este contenido (tabla notif_prefs, función enviar_push_pg y los
-- 4 triggers notificar_push_*) vive ahora en `supabase/schema.sql`, que es
-- la única fuente de verdad. Este archivo se deja como puntero para no
-- romper referencias; ejecutarlo es un no-op seguro.
--
-- Si necesitas cambiar la lógica de push, edita SOLO schema.sql.
-- ============================================================

-- No-op intencional: ver supabase/schema.sql (sección PUSH).
do $$ begin null; end $$;
