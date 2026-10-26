-- ============================================================
-- MIGRACION SEGURIDAD FASE 3 (flumi_app + admin_flumi)
-- Idempotente.
-- ============================================================

-- Likes: el cliente solo lee/borra; la escritura pasa por RPC
-- registrar_me_gusta (valida plan/cupo en servidor).
drop policy if exists "usuario_gestiona_sus_likes" on public.historial_likes;
drop policy if exists "usuario_lee_sus_likes" on public.historial_likes;
create policy "usuario_lee_sus_likes"
  on public.historial_likes for select
  using (auth.uid() = usuario_id);

drop policy if exists "usuario_borra_sus_likes" on public.historial_likes;
create policy "usuario_borra_sus_likes"
  on public.historial_likes for delete
  using (auth.uid() = usuario_id);

-- leido_hasta: permitir actualizar el marcador de lectura en ambos lados
-- de la conversación (propia y recibida).
grant update (leido_hasta) on public.historial_likes to authenticated;

drop policy if exists "usuario_actualiza_leido_hasta" on public.historial_likes;
create policy "usuario_actualiza_leido_hasta"
  on public.historial_likes for update
  to authenticated
  using (auth.uid() = usuario_id or auth.uid() = usuario_likeado_id)
  with check (auth.uid() = usuario_id or auth.uid() = usuario_likeado_id);
