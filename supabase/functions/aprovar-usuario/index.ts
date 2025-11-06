import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req: Request) => {
  // 🌍 Permite chamadas diretas do Flutter
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
  };

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 📥 Dados enviados pelo app
    const { nome, email, celular, funcao, id_filial, nivel } = await req.json();

    // 🔐 Inicializa o cliente administrativo
    const supabaseUrl = Deno.env.get("PROJECT_URL")!;
    const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // 1️⃣ Cria o usuário no Auth (sem senha, modo “convite”)
    const { data: createdUser, error: createError } =
      await supabase.auth.admin.inviteUserByEmail(email);

    if (createError || !createdUser?.user) {
      throw new Error(createError?.message || "Erro ao criar usuário no Auth");
    }

    const userId = createdUser.user.id;

    // 2️⃣ Insere o registro sincronizado na tabela `usuarios`
    const { error: insertError } = await supabase.from("usuarios").insert({
      id: userId,
      nome,
      email,
      celular,
      funcao,
      id_filial,
      nivel,
      status: "ativo",
    });
    if (insertError) throw new Error(insertError.message);

    // 3️⃣ Remove o cadastro pendente
    const { error: deleteError } = await supabase
      .from("cadastros_pendentes")
      .delete()
      .eq("email", email);
    if (deleteError) throw new Error(deleteError.message);

    // 4️⃣ Retorno final
    return new Response(
      JSON.stringify({
        success: true,
        message:
          `Usuário ${email} aprovado e convite enviado com sucesso via Supabase.`,
        user_id: userId,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    const errorMessage = err instanceof Error ? err.message : String(err);
    console.error("❌ Erro em aprovar-usuario:", errorMessage);

    return new Response(
      JSON.stringify({ success: false, error: errorMessage }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
