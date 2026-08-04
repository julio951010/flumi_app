import "@supabase/functions-js/edge-runtime.d.ts";

interface HookPayload {
  user: { email: string };
  template: { subject: string; message: string; title: string };
  token?: string;
  email?: { template: string };
}

Deno.serve(async (req) => {
  const resendKey = Deno.env.get("RESEND_API_KEY");
  if (!resendKey) {
    return new Response("Missing RESEND_API_KEY", { status: 500 });
  }

  const { user, template, token, email: emailInfo }: HookPayload = await req.json();
  const templateType = emailInfo?.template ?? "confirm_signup";
  const otp = token ?? "------";

  const subject = templateType === "reset_password"
    ? "Restablecer contraseña - Flumi"
    : "Código de verificación - Flumi";

  const html = templateType === "reset_password"
    ? `<h2>Restablecer contraseña</h2>
       <p>Ingresa este código en la app:</p>
       <h1 style="letter-spacing:8px;color:#3AA5ED">${otp}</h1>
       <p>Expira en 10 minutos.</p>`
    : `<h2>Bienvenido a Flumi</h2>
       <p>Tu código de verificación es:</p>
       <h1 style="letter-spacing:8px;color:#3AA5ED">${otp}</h1>
       <p>Expira en 10 minutos.</p>`;

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${resendKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: "Flumi <onboarding@resend.dev>",
      to: [user.email],
      subject,
      html,
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    return new Response(body, { status: 500 });
  }

  return new Response("OK", { status: 200 });
});
