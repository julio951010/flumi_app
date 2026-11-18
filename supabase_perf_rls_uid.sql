-- ============================================================
-- RENDIMIENTO RLS · Envolver auth.uid()/auth.role()/auth.jwt()
-- ============================================================
-- Misma semántica, distinto coste: hoy Postgres reevalúa `auth.uid()`
-- por CADA FILA evaluada por la política. Con `(select auth.uid())` se
-- evalúa UNA vez por consulta (InitPlan). Es el arreglo que recomienda
-- el advisor de Supabase.
--
-- · No cambia el resultado de ninguna política: `auth.uid()` es estable
--   durante toda la consulta, así que devuelve el mismo valor.
-- · No toca nombres, roles, ni el comando (SELECT/INSERT/...) de las
--   políticas: usa ALTER POLICY, que solo reescribe la expresión.
-- · No requiere tocar la app.
--
-- MODO SEGURO POR DEFECTO: con v_aplicar = false solo IMPRIME lo que
-- haría (en la pestaña "Messages"/"Notices" del SQL Editor). Revisa la
-- lista, y si te parece bien pon true y vuelve a ejecutar.
-- ============================================================

begin;

do $$
declare
  v_aplicar boolean := false;   -- <<< cambiar a true para aplicar
  r          record;
  v_using    text;
  v_check    text;
  v_sql      text;
  v_vistas   int := 0;
  v_aplicadas int := 0;
begin
  for r in
    select schemaname, tablename, policyname, cmd, qual, with_check
      from pg_policies
     where schemaname = 'public'
       and (
         coalesce(qual, '')       ~* 'auth\.(uid|role|jwt)\(\)'
         or coalesce(with_check, '') ~* 'auth\.(uid|role|jwt)\(\)'
       )
     order by tablename, policyname
  loop
    v_vistas := v_vistas + 1;

    v_using := r.qual;
    v_check := r.with_check;

    -- 1) deshacer un envoltorio previo, para que el script sea idempotente
    if v_using is not null then
      v_using := regexp_replace(
        v_using, '\(\s*select\s+auth\.(uid|role|jwt)\(\)\s*\)', 'auth.\1()', 'gi');
      -- 2) envolver
      v_using := regexp_replace(
        v_using, 'auth\.(uid|role|jwt)\(\)', '(select auth.\1())', 'gi');
    end if;

    if v_check is not null then
      v_check := regexp_replace(
        v_check, '\(\s*select\s+auth\.(uid|role|jwt)\(\)\s*\)', 'auth.\1()', 'gi');
      v_check := regexp_replace(
        v_check, 'auth\.(uid|role|jwt)\(\)', '(select auth.\1())', 'gi');
    end if;

    if not v_aplicar then
      raise notice '[SECO] %.%  |  using: %  |  check: %',
        r.tablename, r.policyname, v_using, v_check;
      continue;
    end if;

    v_sql := format('alter policy %I on %I.%I', r.policyname, r.schemaname, r.tablename);

    -- `using` solo aplica a SELECT/UPDATE/DELETE/ALL; `with check` a
    -- INSERT/UPDATE/ALL. Los nulos ya vienen así desde pg_policies, y
    -- ALTER POLICY rechaza la cláusula que no corresponde a ese comando.
    if v_using is not null then
      v_sql := v_sql || format(' using (%s)', v_using);
    end if;
    if v_check is not null then
      v_sql := v_sql || format(' with check (%s)', v_check);
    end if;

    execute v_sql;
    v_aplicadas := v_aplicadas + 1;
  end loop;

  raise notice 'Políticas con auth.*(): %  |  aplicadas: %', v_vistas, v_aplicadas;
end $$;

commit;

notify pgrst, 'reload schema';

-- ============================================================
-- DESPUÉS DE APLICAR: comprobar que no queda ninguna sin envolver
-- ============================================================
-- select tablename, policyname
--   from pg_policies
--  where schemaname = 'public'
--    and coalesce(qual,'') ~* 'auth\.(uid|role|jwt)\(\)'
--    and coalesce(qual,'') !~* '\(select auth\.';
--
-- Prueba funcional rápida (con la app): entrar, ver feed, abrir un chat,
-- dar like. Si algo fallara, revertir es reejecutar el bloque con el
-- envoltorio invertido.
