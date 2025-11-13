import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Função para gerar senha aleatória
function gerarSenhaAleatoria(tamanho = 10) {
  const caracteres = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%&*";
  let senha = "";
  for (let i = 0; i < tamanho; i++) {
    senha += caracteres.charAt(Math.floor(Math.random() * caracteres.length));
  }
  return senha;
}

serve(async (req: Request): Promise<Response> => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  };

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    console.log("🚀 Iniciando redefinir-senha (reset + e-mail + flag)...");

    // 1️⃣ Pegar o email enviado pelo Flutter
    const { email } = await req.json();
    console.log("📩 E-mail recebido:", email || "(vazio)");
    if (!email) throw new Error("E-mail é obrigatório.");

    // 2️⃣ Variáveis de ambiente
    const supabaseUrl = Deno.env.get("PROJECT_URL");
    const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY");
    const resendApiKey = Deno.env.get("RESEND_API_KEY");

    if (!supabaseUrl || !serviceRoleKey || !resendApiKey) {
      throw new Error("Variáveis de ambiente ausentes. Verifique Supabase Config.");
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // 3️⃣ Buscar usuário no auth
    console.log("👤 Buscando usuário...");
    const { data: users, error: listError } = await supabase.auth.admin.listUsers();
    if (listError) throw listError;

    const user = users.users.find((u: any) => u.email === email);
    if (!user) throw new Error("Usuário não encontrado.");

    // 4️⃣ Gerar nova senha aleatória
    const novaSenha = gerarSenhaAleatoria(10);
    console.log("🔐 Nova senha gerada:", novaSenha);

    // 5️⃣ Atualizar senha no auth
    const { error: resetError } = await supabase.auth.admin.updateUserById(user.id, {
      password: novaSenha,
    });
    if (resetError) throw resetError;

    // 6️⃣ Atualizar flag no banco
    console.log("🧾 Atualizando senha_temporaria = TRUE...");
    const { error: updateError } = await supabase
      .from("usuarios")
      .update({ senha_temporaria: true })
      .eq("email", email);

    if (updateError) throw new Error("Erro ao atualizar flag no banco: " + updateError.message);

    // 7️⃣ Montar e enviar email com a senha nova
    const html = `
      <h2>🔑 Sua senha foi redefinida</h2>
      <p>Olá,</p>
      <p>Sua senha do <strong>CloudTrack</strong> foi redefinida pelo administrador.</p>
      <p>Nova senha temporária:</p>
      <p style="font-size:18px;"><b>${novaSenha}</b></p>
      <p>Você deverá alterá-la assim que acessar o sistema.</p>

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

    const resendPayload = {
      from: "CloudTrack Suporte <suporte@cortexac.com.br>",
      to: [email],
      subject: "🔐 Sua senha foi redefinida - CloudTrack",
      html,
    };

    console.log("📩 Enviando e-mail via Resend...");
    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(resendPayload),
    });

    const resendText = await resendResponse.text();
    console.log("📊 Resend Status:", resendResponse.status);
    console.log("📨 Resend Resposta:", resendText || "(vazio)");

    if (!resendResponse.ok) {
      throw new Error(`Erro ao enviar e-mail: ${resendText}`);
    }

    // 8️⃣ Final
    return new Response(
      JSON.stringify({
        success: true,
        message: "Senha redefinida com sucesso e enviada por e-mail.",
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );

  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("❌ ERRO:", message);

    return new Response(
      JSON.stringify({ success: false, error: message }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
