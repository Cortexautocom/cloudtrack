import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req: Request): Promise<Response> => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { email } = await req.json();
    if (!email) throw new Error("E-mail é obrigatório.");

    const supabase = createClient(
      Deno.env.get("PROJECT_URL")!,
      Deno.env.get("SERVICE_ROLE_KEY")!,
    );

    // 1️⃣ Buscar usuário pelo email
    const { data: usuario, error: usrErr } = await supabase
      .from("usuarios")
      .select("id, nome, email")
      .eq("email", email)
      .single();

    if (usrErr || !usuario) {
      throw new Error("Usuário não encontrado.");
    }

    // 2️⃣ Marcar pedido de redefinição
    const { error: updErr } = await supabase
      .from("usuarios")
      .update({ redefinicao_senha: true })
      .eq("email", email);

    if (updErr) {
      throw new Error("Erro ao registrar solicitação.");
    }

    // 3️⃣ Buscar administradores nível 3
    const { data: admins, error: adminErr } = await supabase
      .from("usuarios")
      .select("email")
      .eq("nivel", 3);

    if (adminErr) {
      throw new Error("Erro ao buscar administradores.");
    }

    const listaEmails = admins.map((a: any) => a.email);

    // 4️⃣ Enviar email aos admins
    const resendPayload = {
      from: "PowerTank Suporte <suporte@powertankapp.com.br>",
      to: listaEmails,
      subject: "🔔 Solicitação de redefinição de senha",
      html: `
        <h2>🔔 Solicitação de redefinição de senha</h2>
        <p>O usuário <strong>${usuario.nome}</strong> pediu redefinição de senha.</p>
        <p>E-mail: <b>${usuario.email}</b></p>
        <p style="margin: 24px 0;">
          <a href="https://powertankapp.com.br/"
            style="background-color:#0A4B78;
            color:#fff;
            padding:12px 20px;
            border-radius:8px;
            text-decoration:none;
            font-weight:bold;">
            Acessar o PowerTank
          </a>
        </p>
        <hr>
        <small>'PowerTank Terminais 2026, All rights reserved.',</small>
      `,
    };

    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${Deno.env.get("RESEND_API_KEY")}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(resendPayload),
    });

    const resendText = await resendResponse.text();
    if (!resendResponse.ok) {
      throw new Error(`Erro ao enviar e-mail: ${resendText}`);
    }

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );

  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    return new Response(
      JSON.stringify({ error: msg }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
