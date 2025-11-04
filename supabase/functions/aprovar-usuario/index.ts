import { serve } from "https://deno.land/std/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

serve(async (req: Request) => {
  // 🔹 Permite requisições do navegador
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  }

  // 🔹 Lida com o pré-flight (requisição OPTIONS)
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const { nome, email, celular, funcao, id_filial, nivel } = await req.json()

    const supabaseUrl = Deno.env.get("PROJECT_URL")!
    const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY")!
    const supabase = createClient(supabaseUrl, serviceRoleKey)

    const { error: authError } = await supabase.auth.admin.inviteUserByEmail(email)
    if (authError) throw new Error(authError.message)

    const { error: insertError } = await supabase
      .from("usuarios")
      .insert({ nome, email, celular, funcao, id_filial, nivel })
    if (insertError) throw new Error(insertError.message)

    return new Response(
      JSON.stringify({ success: true, message: "Usuário criado com sucesso." }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  } catch (err) {
    const errorMessage = err instanceof Error ? err.message : String(err)
    return new Response(
      JSON.stringify({ success: false, error: errorMessage }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  }
})
