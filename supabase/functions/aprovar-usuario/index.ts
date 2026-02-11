// aprovar-usuario/index.ts
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// -----------------------------------------------------------------------------
// Função para gerar senha aleatória segura
// -----------------------------------------------------------------------------
function gerarSenhaAleatoria(tamanho = 10): string {
  const caracteres =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%&*";
  let senha = "";
  for (let i = 0; i < tamanho; i++) {
    senha += caracteres.charAt(Math.floor(Math.random() * caracteres.length));
  }
  return senha;
}

// -----------------------------------------------------------------------------
// Função auxiliar para validar UUID
// -----------------------------------------------------------------------------
function isUUID(value: string): boolean {
  const uuidRegex =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  return uuidRegex.test(value);
}

// -----------------------------------------------------------------------------
// SERVIDOR EDGE
// -----------------------------------------------------------------------------
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
    // -------------------------------------------------------------------------
    // 1. Ler o corpo da requisição
    // -------------------------------------------------------------------------
    const dados = await req.json();
    const { nome, email, celular, funcao, id_filial, nivel } = dados;

    console.log("📥 Dados recebidos:", dados);

    // -------------------------------------------------------------------------
    // 2. Validações iniciais
    // -------------------------------------------------------------------------
    if (!nome || !email) {
      throw new Error("Nome e e-mail são obrigatórios.");
    }

    if (id_filial && !isUUID(id_filial)) {
      throw new Error(`id_filial inválido: "${id_filial}". Deve ser UUID.`);
    }

    if (![1, 2, 3].includes(Number(nivel))) {
      throw new Error(`Nível inválido: ${nivel}.`);
    }

    // -------------------------------------------------------------------------
    // 3. Carregar envs
    // -------------------------------------------------------------------------
    const supabaseUrl = Deno.env.get("PROJECT_URL");
    const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY");
    const resendApiKey = Deno.env.get("RESEND_API_KEY");

    if (!supabaseUrl || !serviceRoleKey || !resendApiKey) {
      throw new Error(
        "Variáveis de ambiente ausentes (PROJECT_URL, SERVICE_ROLE_KEY ou RESEND_API_KEY).",
      );
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // -------------------------------------------------------------------------
    // 4. Criar usuário no Auth
    // -------------------------------------------------------------------------
    const senhaGerada = gerarSenhaAleatoria(10);

    console.log("🔑 Criando usuário no Auth...");

    const { data: createdUser, error: createError } =
      await supabase.auth.admin.createUser({
        email,
        password: senhaGerada,
        email_confirm: true,
      });

    if (createError) {
      console.error("❌ Erro Auth:", createError.message);
      throw new Error("Erro ao criar usuário no Auth: " + createError.message);
    }

    if (!createdUser?.user) {
      throw new Error("Erro inesperado: Auth não retornou usuário.");
    }

    const userId = createdUser.user.id;
    console.log("✅ Usuário Auth criado:", userId);

    // -------------------------------------------------------------------------
    // 5. Inserir na tabela usuarios (UUID precisa ser STRING válida)
    // -------------------------------------------------------------------------
    const usuarioData = {
      id: userId,
      nome,
      email,
      celular,
      funcao,
      id_filial: id_filial || null,
      nivel,
      status: "ativo",
      senha_temporaria: true,
    };

    console.log("📦 Inserindo na tabela usuarios:", usuarioData);

    const { error: insertError } = await supabase.from("usuarios").insert(
      usuarioData,
    );

    if (insertError) {
      console.error("❌ Erro insert:", insertError);
      throw new Error(
        `Erro ao inserir usuário na tabela usuarios: ${insertError.message}`,
      );
    }

    console.log("✅ Usuário inserido na tabela usuarios.");

    // -------------------------------------------------------------------------
    // 6. Excluir cadastro pendente
    // -------------------------------------------------------------------------
    console.log("🗑 Removendo cadastro pendente...");

    await supabase.from("cadastros_pendentes").delete().eq("email", email);

    console.log("✅ Cadastro pendente removido.");

    // -------------------------------------------------------------------------
    // 7. Enviar e-mail via Resend
    // -------------------------------------------------------------------------
    console.log("📧 Enviando e-mail via Resend...");

    const html = `
      <h2>Bem-vindo(a) ao PowerTank!</h2>
      <p>Olá ${nome},</p>
      <p>Sua conta foi aprovada com sucesso e já está ativa!</p>
      <p>Use os dados abaixo para acessar o sistema:</p>
      <p><strong>E-mail:</strong> ${email}</p>
      <p><strong>Senha temporária:</strong> <b style="font-size:18px;">${senhaGerada}</b></p>
      <p>Você será solicitado a alterar essa senha no primeiro login.</p>

      <p style="margin: 30px 0;">
        <a href="https://powertankapp.com.br/"
           style="background-color:#0A4B78; color:#fff; padding:14px 28px; border-radius:8px; text-decoration:none; font-weight:bold;">
          Acessar o PowerTank
        </a>
      </p>

      <hr>
      <p style="font-size:12px; color:#888;">
        'PowerTank Terminais 2026, All rights reserved.',
      </p>
    `;

    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "PowerTank Suporte <suporte@powertankapp.com.br>",
        to: [email],
        subject: "Acesso liberado - PowerTank",
        html,
      }),
    });

    if (!resendResponse.ok) {
      const errText = await resendResponse.text();
      console.error("❌ Erro ao enviar e-mail via Resend:", errText);
      throw new Error("Falha ao enviar e-mail de boas-vindas.");
    }

    console.log("✅ E-mail enviado com sucesso!");

    // -------------------------------------------------------------------------
    // RESPOSTA FINAL PARA O FLUTTER
    // -------------------------------------------------------------------------
    return new Response(
      JSON.stringify({
        success: true,
        message:
          "Usuário aprovado! Senha temporária gerada e enviada por e-mail.",
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("🔥 ERRO FINAL:", message);

    return new Response(JSON.stringify({ success: false, error: message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
