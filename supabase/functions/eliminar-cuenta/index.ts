// Elimina cuenta completa: auth, datos, storage
// Requiere: PUSH_SECRET (para triggers), FIREBASE_SERVICE_ACCOUNT
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { createClient } from "npm:@supabase/supabase-js@2";

Deno.serve(async (req) => {
  // Solo POST
  if (req.method !== "POST") {
    return new Response("Método no permitido", { status: 405 });
  }

  // Verificar secreto compartido
  const secret = req.headers.get("x-flumi-secret");
  if (secret !== Deno.env.get("PUSH_SECRET")) {
    return new Response("No autorizado", { status: 401 });
  }

  // Parsear body
  let body: { usuario_id?: string } = { usuario_id: "" };
  try {
    const bodyText = await req.text();
    if (bodyText) body = JSON.parse(bodyText);
  } catch {
    return new Response("JSON inválido", { status: 400 });
  }

  const usuarioId = body.usuario_id;
  if (!usuarioId) {
    return new Response("Falta usuario_id", { status: 400 });
  }

  // Cliente Supabase con service_role para operaciones admin
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  try {
    // 1. Borrar archivos de storage del usuario
    try {
      const { data: files, error: listError } = await supabase.storage
        .from('profile-photos')
        .list(`${usuarioId}/`, { limit: 100 });

      if (!listError && files && files.length > 0) {
        const paths = files.map(f => `${usuarioId}/${f.name}`);
        await supabase.storage.from('profile-photos').remove(
          paths.map(f => `${usuarioId}/${f.name}`)
        );
      }
    } catch (e) {
      console.error('Error borrando storage:', e);
    }

    // 2. Borrar datos de la app (cascada elimina matches, likes, mensajes, etc)
    // El trigger ON DELETE CASCADE en profiles se encarga de casi todo
    await supabase.from('profiles').delete().eq('id', usuarioId);

    // 3. Borrar usuario de Auth (requiere service_role)
    const { error: deleteError } = await supabase.auth.admin.deleteUser(usuarioId);
    if (deleteError) {
      console.error('Error borrando usuario auth:', deleteError);
      // No lanzar error, intentamos continuar
    }

    // 4. Borrar tokens de dispositivo
    await supabase.from('device_tokens').delete().eq('usuario_id', usuarioId);

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  } catch (e) {
    console.error('Error eliminando cuenta:', e);
    return new Response(
      JSON.stringify({ error: String(e) }),
      { status: 500, headers: { "content-type": "application/json" } }
    );
  }
});