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
    // 1. Borrar el usuario de Auth PRIMERO. profiles.id referencia
    // auth.users(id) ON DELETE CASCADE, así que esto elimina también el
    // perfil, matches, likes, mensajes, etc. Si falla, NO se toca nada más y
    // se informa el error (antes se borraba el perfil y se respondía
    // success: true aunque la cuenta de Auth siguiera viva).
    const { error: deleteError } = await supabase.auth.admin.deleteUser(usuarioId);
    if (deleteError) {
      console.error('Error borrando usuario auth:', deleteError);
      return new Response(
        JSON.stringify({ success: false, error: 'No se pudo eliminar la cuenta' }),
        { status: 500, headers: { "content-type": "application/json" } }
      );
    }

    // 2. Tokens de dispositivo (por si la tabla no tuviera cascada).
    const { error: tokensError } = await supabase
      .from('device_tokens').delete().eq('usuario_id', usuarioId);
    if (tokensError) console.error('Error borrando device_tokens:', tokensError);

    // 3. Archivos de storage. La cuenta ya no existe: si algo falla aquí se
    // registra y se avisa en la respuesta, pero no se revierte nada.
    // - fotos de perfil:      '{usuarioId}_{timestamp}.jpg' en la RAÍZ
    // - selfies verificación: 'verificacion/{usuarioId}_{timestamp}.jpg'
    //   (dato sensible: antes NO se borraban)
    // `search` + prefijo exacto para no atrapar archivos de otro usuario.
    let almacenamientoOk = true;
    try {
      const bucket = supabase.storage.from('profile-photos');
      const rutas: string[] = [];
      for (const carpeta of ['', 'verificacion']) {
        const { data: files, error: listError } = await bucket.list(carpeta, {
          limit: 1000,
          search: usuarioId,
        });
        if (listError) throw listError;
        for (const f of files ?? []) {
          if (f.name.startsWith(`${usuarioId}_`)) {
            rutas.push(carpeta ? `${carpeta}/${f.name}` : f.name);
          }
        }
      }
      if (rutas.length > 0) {
        const { error: removeError } = await bucket.remove(rutas);
        if (removeError) throw removeError;
      }
    } catch (e) {
      almacenamientoOk = false;
      console.error('Error borrando storage:', e);
    }

    return new Response(JSON.stringify({ success: true, almacenamiento_ok: almacenamientoOk }), {
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