-- ============================================
-- Tabla unificada de notificaciones vistas (cross-device)
-- Ejecutar en Supabase Dashboard → SQL Editor
-- ============================================

CREATE TABLE notificaciones_vistas (
  usuario_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  notificacion_id text NOT NULL,  -- ej: 'soporte:abc:123', 'mensaje:xyz:456', 'like:123', 'visita:456', 'match:789'
  visto_en timestamptz DEFAULT now(),
  PRIMARY KEY (usuario_id, notificacion_id)
);

-- RLS: cada usuario solo ve/gestiona las suyas
ALTER TABLE notificaciones_vistas ENABLE ROW LEVEL SECURITY;

CREATE POLICY "own_vistas_select" ON notificaciones_vistas
  FOR SELECT TO authenticated USING (usuario_id = auth.uid());

CREATE POLICY "own_vistas_insert" ON notificaciones_vistas
  FOR INSERT TO authenticated WITH CHECK (usuario_id = auth.uid());

CREATE POLICY "own_vistas_upsert" ON notificaciones_vistas
  FOR UPDATE TO authenticated USING (usuario_id = auth.uid()) WITH CHECK (usuario_id = auth.uid());

-- Índice para consultas rápidas "¿cuántas no vistas tengo?"
CREATE INDEX idx_notificaciones_vistas_usuario ON notificaciones_vistas (usuario_id);

-- Comentario para documentar el formato de notificacion_id
COMMENT ON COLUMN notificaciones_vistas.notificacion_id IS 
  'Formato: <tipo>:<referencia_id>:<timestamp_ms>. Tipos: soporte, mensaje, like, visita, match, sistema';