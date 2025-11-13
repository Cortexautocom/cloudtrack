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

  // ===== OPTIONS =====
  if (req.method === "OPTIONS") {
    console.log("🟢 Pré-flight OPTIONS recebido.");
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    console.log("🚀 Iniciando redefinir-senha (reset + e-mail + flag)...");

    // === 1️⃣ Corpo da requisição ===
    const { email } = await req.json();
    console.log("📩 E-mail recebido:", email || "(vazio)");
    if (!email) throw new Error("E-mail é obrigatório.");

    // === 2️⃣ Variáveis de ambiente ===
    const supabaseUrl = Deno.env.get("PROJECT_URL");
    const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY");
    const resendApiKey = Deno.env.get("RESEND_API_KEY");

    if (!supabaseUrl || !serviceRoleKey || !resendApiKey) {
      throw new Error("Variáveis de ambiente ausentes. Verifique Supabase Config.");
    }

    // === 3️⃣ Cria cliente Supabase com service role ===
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // === 4️⃣ Busca usuário e redefine senha ===
    console.log("👤 Buscando usuário...");
    const { data: users, error: listError } = await supabase.auth.admin.listUsers();
    if (listError) throw listError;

    const user = users.users.find((u: any) => u.email === email);
    if (!user) throw new Error("Usuário não encontrado.");

    console.log("🔐 Redefinindo senha...");
    const { error: resetError } = await supabase.auth.admin.updateUserById(user.id, {
      password: "123456",
    });
    if (resetError) throw resetError;

    // === 5️⃣ Atualiza flag 'senha_temporaria' na tabela 'usuarios' ===
    console.log("🧾 Marcando senha_temporaria = TRUE no banco...");
    const { error: updateError } = await supabase
      .from("usuarios")
      .update({ senha_temporaria: true })
      .eq("email", email);

    if (updateError) throw new Error("Erro ao atualizar flag no banco: " + updateError.message);

    // === 6️⃣ Monta o e-mail com botão de acesso ===
    const html = `
      <h2>🔑 Senha redefinida</h2>
      <p>Olá,</p>
      <p>Sua senha no <strong>CloudTrack</strong> foi redefinida pelo administrador.</p>
      <p>Nova senha temporária: <b>123456</b></p>
      <p>Você fará a alteração assim que acessar o app.</p>
      <p style="margin: 24px 0;">
        <a href="https://cloudtrack-app.web.app/"
           style="background-color:#0A4B78;
                  color:#fff;
                  padding:12px 20px;
                  border-radius:8px;
                  text-decoration:none;
                  font-weight:bold;">
          Acessar o CloudTrack
        </a>
      </p>
      <hr>
      <p style="font-size:12px;color:#888;">
        © 2025 CloudTrack • Powered by AwaySoftwares LLC
      </p>
    `;

    // === 7️⃣ Envia o e-mail via Resend ===
    const resendPayload = {
      from: "CloudTrack Suporte <suporte@cortexac.com.br>",
      to: [email],
      subject: "🔐 Sua senha foi redefinida - CloudTrack",
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

    console.log("✅ Senha redefinida, flag atualizada e e-mail enviado com sucesso!");
    return new Response(
      JSON.stringify({
        success: true,
        message: "Senha redefinida, flag atualizada e e-mail enviado.",
      }),
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
