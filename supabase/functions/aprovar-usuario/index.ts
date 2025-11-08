import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req: Request) => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
  };

  if (req.method === "OPTIONS")
    return new Response("ok", { headers: corsHeaders });

  try {
    // 🔹 Dados que vêm do app Flutter
    const { nome, email, celular, funcao, id_filial, nivel, senha_inicial } =
      await req.json();

    // 🔐 Conexão com Supabase (Service Role)
    const supabaseUrl = Deno.env.get("PROJECT_URL")!;
    const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // 1️⃣ Cria o usuário no Auth com a senha do admin
    const { data: createdUser, error: createError } =
      await supabase.auth.admin.createUser({
        email,
        password: senha_inicial,
        email_confirm: true,
      });

    if (createError || !createdUser?.user)
      throw new Error(createError?.message || "Erro ao criar usuário");

    const userId = createdUser.user.id;

    // 2️⃣ Adiciona o usuário na tabela pública
    const { error: insertError } = await supabase.from("usuarios").insert({
      id: userId,
      nome,
      email,
      celular,
      funcao,
      id_filial,
      nivel,
      status: "ativo",
      senha_temporaria: true,
    });
    if (insertError) throw new Error(insertError.message);

    // 3️⃣ Apaga o registro pendente
    await supabase.from("cadastros_pendentes").delete().eq("email", email);

    // 4️⃣ Envia e-mail com senha
    const emailHtml = `
      <h2>👋 Bem-vindo(a) ao CloudTrack!</h2>
      <p>Olá ${nome || email},</p>
      <p>Você foi aprovado(a) para acessar o sistema <strong>CloudTrack</strong>.</p>
      <p>Acesse a página de login e entre com seu e-mail e a senha provisória:</p>
      <p>🔗 <a href="https://cloudtrack.app/login">Acessar o CloudTrack</a></p>
      <p>Senha provisória: <strong>${senha_inicial}</strong></p>
      <p>Por segurança, você precisará alterá-la no primeiro acesso.</p>
      <hr>
      <p style="font-size:12px;color:#888;">© 2025 CloudTrack • Powered by AwaySoftwares LLC</p>
    `;

    // Usa o serviço interno do Supabase para enviar e-mail
    await supabase.functions.invoke("email", {
      body: {
        to: email,
        subject: "Acesso ao CloudTrack - senha provisória",
        html: emailHtml,
      },
    });

    // ✅ Retorno final
    return new Response(
      JSON.stringify({
        success: true,
        message: `Usuário ${email} criado e e-mail enviado.`,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({
        success: false,
        error: err instanceof Error ? err.message : String(err),
      }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
