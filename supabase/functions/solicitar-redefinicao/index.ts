import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req: Request): Promise<Response> => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { email } = await req.json();
    if (!email) throw new Error("E-mail é obrigatório.");

    const supabase = createClient(
      Deno.env.get("PROJECT_URL")!,
      Deno.env.get("SERVICE_ROLE_KEY")!,
    );

    // 1️⃣ Buscar usuário pelo email
    const { data: usuario, error: usrErr } = await supabase
      .from("usuarios")
      .select("id, nome, email")
      .eq("email", email)
      .single();

    if (usrErr || !usuario) {
      throw new Error("Usuário não encontrado.");
    }

    // 2️⃣ Marcar pedido de redefinição
    const { error: updErr } = await supabase
      .from("usuarios")
      .update({ redefinicao_senha: true })
      .eq("email", email);

    if (updErr) {
      throw new Error("Erro ao registrar solicitação.");
    }

    // 3️⃣ Buscar administradores nível 3
    const { data: admins, error: adminErr } = await supabase
      .from("usuarios")
      .select("email")
      .eq("nivel", 3);

    if (adminErr) {
      throw new Error("Erro ao buscar administradores.");
    }

    // 4️⃣ Disparar e-mail de recuperação pelo Supabase (usa o SMTP configurado)
    const { error: recoveryErr } = await supabase.auth.admin.generateLink({
      type: "recovery",
      email,
      options: {
        redirectTo: "https://powertankapp.com.br/",
      },
    });

    if (recoveryErr) {
      throw new Error("Falha ao gerar e-mail de recuperação.");
    }

    // 5️⃣ (Opcional) Registrar notificação interna para admins (sem envio de e-mail externo)
    // Aqui você pode salvar logs/notificações no banco se quiser.

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );

  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    return new Response(
      JSON.stringify({ error: msg }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});