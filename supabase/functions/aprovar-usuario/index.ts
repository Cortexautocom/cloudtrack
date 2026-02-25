import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// -----------------------------------------------------------------------------
// Função auxiliar para validar UUID
// -----------------------------------------------------------------------------
function isUUID(value: string): boolean {
  const uuidRegex =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  return uuidRegex.test(value);
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
    const dados = await req.json();
    const { nome, email, celular, funcao, id_filial, nivel } = dados;

    if (!nome || !email) {
      throw new Error("Nome e e-mail são obrigatórios.");
    }

    if (id_filial && !isUUID(id_filial)) {
      throw new Error(`id_filial inválido: "${id_filial}". Deve ser UUID.`);
    }

    if (![1, 2, 3].includes(Number(nivel))) {
      throw new Error(`Nível inválido: ${nivel}.`);
    }

    const supabaseUrl = Deno.env.get("PROJECT_URL");
    const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
      throw new Error("Variáveis de ambiente ausentes (PROJECT_URL, SERVICE_ROLE_KEY).");
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // 1️⃣ Criar usuário no Auth (sem senha)
    const { data: createdUser, error: createError } =
      await supabase.auth.admin.createUser({
        email,
        email_confirm: true,
      });

    if (createError || !createdUser?.user) {
      throw new Error("Erro ao criar usuário no Auth: " + (createError?.message || "desconhecido"));
    }

    const userId = createdUser.user.id;

    // 2️⃣ Inserir na tabela usuarios
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

    const { error: insertError } = await supabase.from("usuarios").insert(usuarioData);
    if (insertError) {
      throw new Error(`Erro ao inserir usuário na tabela usuarios: ${insertError.message}`);
    }

    // 3️⃣ Remover cadastro pendente
    await supabase.from("cadastros_pendentes").delete().eq("email", email);

    // 4️⃣ Enviar link de definição de senha pelo Supabase (SMTP configurado)
    const { error: linkErr } = await supabase.auth.admin.generateLink({
      type: "invite",
      email,
      options: {
        redirectTo: "https://powertankapp.com.br/",
      },
    });

    if (linkErr) {
      throw new Error("Falha ao enviar e-mail de boas-vindas com link de definição de senha.");
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Usuário aprovado! Link para definir a senha enviado por e-mail.",
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );

  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});