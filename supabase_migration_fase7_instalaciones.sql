-- ============================================================
-- MIGRACION FASE 7: instalaciones anónimas (métricas)
-- Idempotente. Ejecutar en Supabase Dashboard -> SQL Editor.
-- ============================================================

create table if not exists public.instalaciones (
  id uuid primary key,
  plataforma text default '',
  version text default '',
  creado_en timestamptz not null default now(),
  ultima_vez timestamptz not null default now()
);

alter table public.instalaciones enable row level security;

-- Sin políticas: nadie lee/escribe directo. Solo el RPC SECURITY DEFINER.
create or replace function public.registrar_instalacion(
  p_id uuid,
  p_plataforma text default '',
  p_version text default ''
)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if p_id is null then
    return;
  end if;
  insert into public.instalaciones (id, plataforma, version)
  values (
    p_id,
    left(coalesce(p_plataforma, ''), 32),
    left(coalesce(p_version, ''), 32)
  )
  on conflict (id) do update
    set ultima_vez = now(),
        version = excluded.version,
        plataforma = excluded.plataforma;
end;
$$;

revoke all on function public.registrar_instalacion(uuid, text, text) from public;
grant execute on function public.registrar_instalacion(uuid, text, text) to anon, authenticated;
