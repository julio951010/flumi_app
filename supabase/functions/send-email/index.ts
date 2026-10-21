// Auth Hook "Send Email" de Supabase -> envía el código OTP por Resend.
//
// SEGURIDAD: esta función se despliega con verify_jwt = false (Supabase Auth
// no manda un JWT de usuario), así que SIN verificar la firma del hook
// cualquiera con la URL podía hacer que tu cuenta de Resend enviara correos
// de "Flumi" a cualquier dirección. Ahora se exige la firma Standard Webhooks.
//
// Secretos necesarios (supabase secrets set ...):
//   RESEND_API_KEY          clave de Resend
//   SEND_EMAIL_HOOK_SECRET  el secreto del hook (Dashboard -> Authentication ->
//                           Hooks -> Send Email; formato "v1,whsec_...")
//   EMAIL_FROM              (opcional) p. ej. "Flumi <no-reply@tudominio.com>".
//                           Con el remitente de pruebas onboarding@resend.dev,
//                           Resend solo entrega a TU propio correo: verifica un
//                           dominio en Resend para usuarios reales.
import "@supabase/functions-js/edge-runtime.d.ts";
import { Webhook } from "standardwebhooks";

interface HookPayload {
  user?: { email?: string };
  // Formato documentado por Supabase.
  email_data?: { token?: string; email_action_type?: string };
  // Formato que esperaba la versión anterior de esta función.
  token?: string;
  email?: { template?: string };
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

const error = (status: number, message: string) =>
  json({ error: { http_code: status, message } }, status);

Deno.serve(async (req) => {
  if (req.method !== "POST") return error(405, "Método no permitido");

  const resendKey = Deno.env.get("RESEND_API_KEY");
  const hookSecret = Deno.env.get("SEND_EMAIL_HOOK_SECRET");
  if (!resendKey || !hookSecret) {
    // Falla cerrado: sin secreto no se envía nada.
    console.error("send-email: faltan RESEND_API_KEY o SEND_EMAIL_HOOK_SECRET");
    return error(500, "Configuración incompleta");
  }

  // 1) Autenticidad: firma Standard Webhooks (id + timestamp + HMAC).
  const raw = await req.text();
  let data: HookPayload;
  try {
    data = new Webhook(hookSecret.replace("v1,whsec_", "")).verify(
      raw,
      Object.fromEntries(req.headers),
    ) as HookPayload;
  } catch {
    return error(401, "Firma inválida");
  }

  // 2) Validación estricta (el HTML se arma con estos valores).
  const destino = data.user?.email;
  const token = data.email_data?.token ?? data.token;
  const tipo = data.email_data?.email_action_type ?? data.email?.template ??
    "signup";
  if (
    typeof destino !== "string" ||
    !/^[^\s@<>"']+@[^\s@<>"']+\.[^\s@<>"']+$/.test(destino)
  ) {
    return error(400, "Correo inválido");
  }
  if (typeof token !== "string" || !/^[0-9]{4,10}$/.test(token)) {
    return error(400, "Código inválido");
  }

  const esReset = tipo === "recovery" || tipo === "reset_password";
  const subject = esReset
    ? "Restablecer contraseña - Flumi"
    : "Código de verificación - Flumi";
  const html = esReset
    ? `<h2>Restablecer contraseña</h2>
       <p>Ingresa este código en la app:</p>
       <h1 style="letter-spacing:8px;color:#3AA5ED">${token}</h1>
       <p>Expira en 10 minutos.</p>`
    : `<h2>Bienvenido a Flumi</h2>
       <p>Tu código de verificación es:</p>
       <h1 style="letter-spacing:8px;color:#3AA5ED">${token}</h1>
       <p>Expira en 10 minutos.</p>`;

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${resendKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: Deno.env.get("EMAIL_FROM") ?? "Flumi <onboarding@resend.dev>",
      to: [destino],
      subject,
      html,
    }),
  });

  if (!res.ok) {
    console.error("send-email: Resend respondió", res.status, await res.text());
    return error(500, "No se pudo enviar el correo");
  }
  return json({});
});
