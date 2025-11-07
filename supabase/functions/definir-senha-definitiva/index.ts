import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req: Request) => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
  };

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 📥 Lê dados enviados pelo app
    const { nova_senha } = await req.json();

    // 🔐 Validação da senha
    if (!nova_senha || nova_senha.length < 6) {
      throw new Error("A nova senha deve ter pelo menos 6 caracteres");
    }

    const supabaseUrl = Deno.env.get("PROJECT_URL")!;
    const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // 🔹 Obtém o usuário atual do token JWT
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      throw new Error("Token de autenticação não encontrado");
    }

    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: userError } = await supabase.auth.getUser(token);
    
    if (userError || !user) {
      throw new Error("Usuário não autenticado: " + (userError?.message || "Token inválido"));
    }

    const userId = user.id;

    // 1️⃣ Atualiza a senha no Auth
    const { error: updateError } = await supabase.auth.admin.updateUserById(
      userId,
      { password: nova_senha }
    );

    if (updateError) {
      throw new Error("Erro ao atualizar senha: " + updateError.message);
    }

    // 2️⃣ Atualiza a flag senha_temporaria para FALSE
    const { error: dbError } = await supabase
      .from("usuarios")
      .update({ senha_temporaria: false })
      .eq("id", userId);

    if (dbError) {
      throw new Error("Erro ao atualizar usuário: " + dbError.message);
    }

    // ✅ Retorna sucesso
    return new Response(
      JSON.stringify({
        success: true,
        message: "Senha definida com sucesso!",
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    const errorMessage = err instanceof Error ? err.message : String(err);
    console.error("❌ Erro em definir-senha-definitiva:", errorMessage);

    return new Response(
      JSON.stringify({ success: false, error: errorMessage }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});