import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req: Request) => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
  };

  if (req.method === "OPTIONS") {
    console.log("🟢 Pré-flight OPTIONS recebido.");
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    console.log("🚀 Iniciando função redefinir-senha");

    // === 1️⃣ Leitura e validação do e-mail ===
    const { email } = await req.json();
    console.log("📩 E-mail recebido:", email || "(vazio)");
    if (!email) throw new Error("E-mail é obrigatório.");

    // === 2️⃣ Variáveis de ambiente ===
    const supabaseUrl = Deno.env.get("PROJECT_URL");
    const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY");
    const resendApiKey = Deno.env.get("RESEND_API_KEY");
    const redirectUrl = "https://cloudtrack.app/redefinir-senha";

    console.log("🔧 Variáveis carregadas:");
    console.log({
      hasProjectUrl: !!supabaseUrl,
      hasServiceRoleKey: !!serviceRoleKey,
      hasResendApiKey: !!resendApiKey,
      serviceRolePrefix: serviceRoleKey?.slice(0, 10),
    });

    if (!supabaseUrl || !serviceRoleKey || !resendApiKey) {
      throw new Error("❌ Variáveis de ambiente ausentes ou incorretas.");
    }

    // === 3️⃣ Criação do cliente Supabase ===
    console.log("⚙️ Criando cliente Supabase...");
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // Teste rápido de conexão ao banco
    console.log("🧠 Testando acesso ao banco...");
    const test = await supabase.from("usuarios").select("id").limit(1);
    console.log("🧩 Teste de conexão:", {
      error: test.error ? test.error.message : "ok",
      rowCount: test.data?.length,
    });

    // === 4️⃣ Gerar link de redefinição ===
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

    if (!recoveryLink)
      throw new Error("Não foi possível gerar o link de redefinição.");

    // === 5️⃣ Montagem do e-mail ===
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
    console.log("🧱 HTML montado com sucesso.");

    // === 6️⃣ Envio de e-mail via Resend ===
    const resendPayload = {
      from: "CloudTrack Suporte <suporte@cortexac.com.br>",
      to: [email],
      subject: "Redefinição de senha - CloudTrack",
      html,
    };

    console.log("📦 Payload de envio Resend:", resendPayload);

    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(resendPayload),
    });

    const resendText = await resendResponse.text();
    console.log("📩 Resposta do Resend:", resendText || "(sem resposta)");
    console.log("📊 Status HTTP:", resendResponse.status);

    if (!resendResponse.ok) {
      throw new Error(`Erro ao enviar e-mail via Resend: ${resendText}`);
    }

    // === ✅ Sucesso total ===
    console.log("✅ E-mail enviado com sucesso!");
    return new Response(
      JSON.stringify({ success: true, message: "E-mail enviado com sucesso!" }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );

  } catch (err: unknown) {
    // 🔍 Tratamento detalhado de erro
    const message =
      err instanceof Error ? err.message : String(err);
    const stack =
      err instanceof Error && err.stack ? err.stack : "(sem stack)";

    console.error("❌ ERRO DETECTADO:", message, "\nStack:", stack);

    return new Response(
      JSON.stringify({
        success: false,
        error: message,
        stack,
      }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
