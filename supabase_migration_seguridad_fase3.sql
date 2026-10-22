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
