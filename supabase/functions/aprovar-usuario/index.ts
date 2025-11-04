import { serve } from "https://deno.land/std/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

serve(async (req: Request) => {
  // 🔹 Permite requisições do navegador (CORS)
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  }

  // 🔹 Lida com o pré-flight (requisição OPTIONS)
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    // ✅ Lê o corpo JSON enviado pelo app
    const { nome, email, celular, funcao, id_filial, nivel } = await req.json()

    // ✅ Conecta ao Supabase com a Service Role (permissões administrativas)
    const supabaseUrl = Deno.env.get("PROJECT_URL")!
    const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY")!
    const supabase = createClient(supabaseUrl, serviceRoleKey)

    // 1️⃣ Cria usuário no Auth e envia e-mail de convite
    const { error: authError } = await supabase.auth.admin.inviteUserByEmail(email)
    if (authError) throw new Error(authError.message)

    // 2️⃣ Insere o novo usuário na tabela 'usuarios' com status 'ativo'
    const { error: insertError } = await supabase
      .from("usuarios")
      .insert({
        nome,
        email,
        celular,
        funcao,
        id_filial,
        nivel,
        status: "ativo",
      })
    if (insertError) throw new Error(insertError.message)

    // 3️⃣ Remove o registro da tabela 'cadastros_pendentes'
    const { error: deleteError } = await supabase
      .from("cadastros_pendentes")
      .delete()
      .eq("email", email)
    if (deleteError) throw new Error(deleteError.message)

    // ✅ Tudo certo
    return new Response(
      JSON.stringify({
        success: true,
        message: "Usuário aprovado, ativado e removido dos cadastros pendentes.",
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  } catch (err) {
    // 🔹 Garante mensagem de erro segura e amigável
    const errorMessage = err instanceof Error ? err.message : String(err)
    return new Response(
      JSON.stringify({ success: false, error: errorMessage }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  }
})
