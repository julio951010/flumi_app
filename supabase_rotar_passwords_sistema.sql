-- ============================================================
-- Rotar passwords de las cuentas de sistema (Administrador / Flumi)
-- admin_setup.sql las creó con password PÚBLICO ('cambiar-este-password'):
-- cualquiera puede loguearse como @flumi.local y enviar mensajes
-- oficiales (phishing). Esto las deja con password aleatorio desconocido
-- (son bots: nunca inician sesión con password).
-- Ejecutar en Supabase Dashboard → SQL Editor (corre como postgres).
-- ============================================================

create extension if not exists pgcrypto;

update auth.users
set encrypted_password = crypt(encode(gen_random_bytes(48), 'hex'), gen_salt('bf')),
    banned_until = '9999-12-31 23:59:59+00'::timestamptz,
    updated_at = now()
where email in ('sistema-administrador@flumi.local', 'sistema-flumi@flumi.local');

-- Verificación: deben salir 2 filas (o 0 si aún no existen las cuentas).
select email, updated_at from auth.users
where email in ('sistema-administrador@flumi.local', 'sistema-flumi@flumi.local');
