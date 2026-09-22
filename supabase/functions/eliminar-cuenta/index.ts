// Elimina la cuenta del usuario autenticado: auth, datos y storage.
// Se identifica al usuario por su propio JWT (el que `functions.invoke`
// del cliente Flutter ya adjunta automáticamente como Authorization) —
// nunca por un usuario_id que mande el body, porque eso permitiría que
// cualquiera borrara la cuenta de otra persona con solo conocer su id.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { createClient } from "npm:@supabase/supabase-js@2";

Deno.serve(async (req) => {
  // Solo POST
  if (req.method !== "POST") {
    return new Response("Método no permitido", { status: 405 });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response("No autorizado", { status: 401 });
  }

  // Cliente con el JWT del usuario, solo para saber quién es.
  const supabaseUsuario = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } }
  );
  const { data: { user }, error: userError } =
    await supabaseUsuario.auth.getUser();
  if (userError || !user) {
    return new Response("No autorizado", { status: 401 });
  }
  const usuarioId = user.id;

  // Cliente con service_role para las operaciones admin (storage, auth).
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  try {
    // 1. Borrar archivos de storage del usuario.
    // Las fotos se guardan como '{usuarioId}_{timestamp}.jpg' en la RAÍZ
    // del bucket (ver perfil_foto_servicio.dart), no dentro de una carpeta
    // '{usuarioId}/' — por eso se busca con `search`, filtrando por
    // prefijo exacto para no atrapar nada de otro usuario por accidente.
    try {
      const { data: files, error: listError } = await supabase.storage
        .from('profile-photos')
        .list('', { limit: 100, search: usuarioId });

      const propios = (files ?? []).filter(f =>
        f.name.startsWith(`${usuarioId}_`)
      );
      if (!listError && propios.length > 0) {
        await supabase.storage.from('profile-photos').remove(
          propios.map(f => f.name)
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