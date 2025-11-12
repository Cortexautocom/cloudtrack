import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req: Request): Promise<Response> => {
  // ===== CORS =====
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  };

  // ===== OPTIONS (pré-flight) =====
  if (req.method === "OPTIONS") {
    console.log("🟢 Pré-flight OPTIONS recebido.");
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    console.log("🚀 Iniciando função redefinir-senha...");

    // === 1️⃣ Valida o corpo ===
    const { email } = await req.json();
    console.log("📩 E-mail recebido:", email || "(vazio)");
    if (!email) throw new Error("E-mail é obrigatório.");

    // === 2️⃣ Valida autorização do Flutter ===
    const authHeader = req.headers.get("authorization");
    if (!authHeader) throw new Error("Requisição sem token de autorização.");
    const anonKey = Deno.env.get("PUBLIC_ANON_KEY");
    if (!anonKey) throw new Error("Chave pública (anon) não configurada.");
    if (authHeader !== `Bearer ${anonKey}`) {
      throw new Error("Token de autorização inválido ou não reconhecido.");
    }

    // === 3️⃣ Variáveis de ambiente ===
    const supabaseUrl = Deno.env.get("PROJECT_URL");
    const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY");
    const resendApiKey = Deno.env.get("RESEND_API_KEY");
    const redirectUrl = "https://cloudtrack-app.web.app/redefinir-senha#recovery=true";

    console.log("🔧 Variáveis carregadas:");
    console.log({
      hasProjectUrl: !!supabaseUrl,
      hasServiceRoleKey: !!serviceRoleKey,
      hasResendApiKey: !!resendApiKey,
    });

    if (!supabaseUrl || !serviceRoleKey || !resendApiKey) {
      throw new Error("❌ Variáveis de ambiente ausentes ou incorretas.");
    }

    // === 4️⃣ Criação do cliente Supabase ===
    console.log("⚙️ Criando cliente Supabase...");
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // === 5️⃣ Gerar link de redefinição ===
    console.log("🧩 Gerando link de redefinição...");
    const { data, error } = await supabase.auth.admin.generateLink({
      type: "recovery",
      email,
      options: { redirectTo: redirectUrl },
    });

    if (error) {
      console.error("❌ Erro Supabase.generateLink:", error);
      throw new Error("Erro ao gerar link de redefinição: " + error.message);
    }

    const recoveryLink = data?.properties?.action_link || data?.action_link;
    console.log("🔗 Link de redefinição gerado:", recoveryLink || "(nenhum)");
    if (!recoveryLink) {
      throw new Error("Não foi possível gerar o link de redefinição.");
    }

    // === 6️⃣ Montagem do e-mail ===
    const html = `
      <h2>🔑 Redefinição de senha</h2>
      <p>Olá,</p>
      <p>Você solicitou redefinir sua senha no <strong>CloudTrack</strong>.</p>
      <p>Clique no botão abaixo para criar uma nova senha:</p>
      <p style="margin: 24px 0;">
        <a href="${recoveryLink}"
          style="background-color:#0A4B78;color:#fff;padding:12px 20px;
                 border-radius:8px;text-decoration:none;font-weight:bold;">
          Redefinir senha
        </a>
      </p>
      <p>Se você não fez esta solicitação, basta ignorar este e-mail.</p>
      <hr>
      <p style="font-size:12px;color:#888;">
        © 2025 CloudTrack • Powered by AwaySoftwares LLC
      </p>
    `;
    console.log("🧱 HTML do e-mail montado com sucesso.");

    // === 7️⃣ Envio via Resend ===
    const resendPayload = {
      from: "CloudTrack Suporte <suporte@cortexac.com.br>",
      to: [email],
      subject: "Redefinição de senha - CloudTrack",
      html,
    };

    console.log("📦 Enviando e-mail via Resend...");
    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(resendPayload),
    });

    const resendText = await resendResponse.text();
    console.log("📊 Status HTTP Resend:", resendResponse.status);
    console.log("📩 Corpo da resposta Resend:", resendText || "(sem resposta)");

    if (!resendResponse.ok) {
      throw new Error(`Erro ao enviar e-mail via Resend: ${resendText}`);
    }

    console.log("✅ E-mail enviado com sucesso!");
    return new Response(
      JSON.stringify({ success: true, message: "E-mail enviado com sucesso!" }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("❌ ERRO DETECTADO:", message);

    return new Response(
      JSON.stringify({ success: false, error: message }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
