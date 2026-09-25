// Envía notificaciones push FCM (HTTP v1) a los tokens del usuario.
// La invocan los triggers de la BD vía app_config.push_url con el header
// x-flumi-secret (debe coincidir con PUSH_SECRET).
//
// Secretos requeridos:
//   supabase secrets set PUSH_SECRET=<mismo que en app_config>
//   supabase secrets set FIREBASE_SERVICE_ACCOUNT=<JSON del service account>
import "@supabase/functions-js/edge-runtime.d.ts";

import { createClient } from "@supabase/supabase-js";

interface PushPayload {
  usuario_id: string;
  titulo?: string;
  cuerpo?: string;
  categoria?: string;
}

async function firmarJwtOauth(
  serviceAccount: Record<string, unknown>,
): Promise<string> {
  const ahora = Math.floor(Date.now() / 1000);
  const header = {
    alg: "RS256",
    typ: "JWT",
  };
  const payload = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: ahora,
    exp: ahora + 3600,
  };

  const enc = (o: unknown) =>
    btoa(JSON.stringify(o)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

  const datos = `${enc(header)}.${enc(payload)}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    Uint8Array.from(atob(String(serviceAccount.private_key)), (c) => c.charCodeAt(0)),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const firma = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(datos));
  return `${datos}.${btoa(String.fromCharCode(...new Uint8Array(firma)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "")}`;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Método no permitido", { status: 405 });
  }
  if (req.headers.get("x-flumi-secret") !== Deno.env.get("PUSH_SECRET")) {
    return new Response("No autorizado", { status: 401 });
  }

  const body: PushPayload = await req.json().catch(() => ({}));
  if (!body.usuario_id) {
    return new Response("Falta usuario_id", { status: 400 });
  }

  const serviceAccountRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  if (!serviceAccountRaw) {
    return new Response("Falta FIREBASE_SERVICE_ACCOUNT", { status: 500 });
  }
  const serviceAccount = JSON.parse(serviceAccountRaw) as Record<string, unknown>;
  const projectId = String(serviceAccount.project_id);

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: tokens, error: errTokens } = await supabase
    .from("device_tokens")
    .select("token")
    .eq("usuario_id", body.usuario_id);
  if (errTokens || !tokens || tokens.length === 0) {
    return new Response(JSON.stringify({ enviados: 0, motivo: "sin_tokens" }), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  }

  const jwt = await firmarJwtOauth(serviceAccount);
  let enviados = 0;
  const errores: string[] = [];

  for (const fila of tokens) {
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${jwt}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token: fila.token,
            notification: {
              title: body.titulo ?? "Flumi",
              body: body.cuerpo ?? "",
            },
            data: {
              categoria: body.categoria ?? "mensajes",
              titulo: body.titulo ?? "Flumi",
              cuerpo: body.cuerpo ?? "",
            },
            android: {
              priority: "HIGH",
              notification: {
                channel_id: "flumi",
                // FCM HTTP v1 no tiene campo "priority" aquí: es
                // notification_priority con valores PRIORITY_*. Un nombre
                // desconocido hace que FCM rechace el mensaje (400).
                notification_priority: "PRIORITY_HIGH",
                visibility: "PRIVATE",
              },
            },
            apns: {
              payload: {
                aps: {
                  sound: "default",
                  badge: 1,
                },
              },
            },
          },
        }),
      },
    );

    if (res.ok) {
      enviados++;
      continue;
    }

    const respuesta = await res.text();
    // 404 = token dado de baja (app desinstalada): limpiar la fila local.
    if (res.status === 404 || res.status === 410) {
      await supabase.from("device_tokens").delete().eq("token", fila.token);
    }
    errores.push(respuesta.slice(0, 200));
  }

  return new Response(
    JSON.stringify({ enviados, errores: errores.length }),
    { status: 200, headers: { "content-type": "application/json" } },
  );
});
