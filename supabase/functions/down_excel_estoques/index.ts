import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as XLSX from "https://esm.sh/xlsx@0.18.5";

serve(async (req: Request) => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 📥 Lê dados enviados pelo app
    const { filialId, nomeFilial, empresaId, mesFiltro, produtoFiltro } = await req.json();

    // 🔐 Validação dos parâmetros
    if (!filialId || !mesFiltro) {
      throw new Error("ID da filial e mês são obrigatórios");
    }

    const supabaseUrl = Deno.env.get("PROJECT_URL")!;
    const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // 🔹 Validação do usuário
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      throw new Error("Token de autenticação não encontrado");
    }

    const token = authHeader.replace("Bearer ", "");
    const { data: { user } } = await supabase.auth.getUser(token);
    
    if (!user) {
      throw new Error("Usuário não autenticado");
    }

    // 🔍 Buscar empresaId se não fornecido
    let empresaIdFinal = empresaId;
    if (!empresaIdFinal) {
      const { data: filialData } = await supabase
        .from("filiais")
        .select("empresa_id")
        .eq("id", filialId)
        .single();
      
      if (!filialData?.empresa_id) {
        throw new Error("Filial não possui empresa associada");
      }
      empresaIdFinal = filialData.empresa_id;
    }

    // 📅 Preparar datas para filtro
    const mes = new Date(mesFiltro);
    const primeiroDia = new Date(mes.getFullYear(), mes.getMonth(), 1);
    const ultimoDia = new Date(mes.getFullYear(), mes.getMonth() + 1, 0);
    
    // 🔍 Construir query
    let query = supabase
      .from("estoques")
      .select(`
        data_mov,
        descricao,
        entrada_amb,
        entrada_vinte,
        saida_amb,
        saida_vinte,
        produtos!inner(nome)
      `)
      .eq("filial_id", filialId)
      .eq("empresa_id", empresaIdFinal)
      .gte("data_mov", primeiroDia.toISOString())
      .lte("data_mov", ultimoDia.toISOString())
      .order("data_mov", { ascending: true });

    // 🔍 Aplicar filtro de produto
    if (produtoFiltro && produtoFiltro !== "todos") {
      query = query.eq("produto_id", produtoFiltro);
    }

    // 📊 Executar consulta
    const { data: estoques, error } = await query;
    if (error) throw error;
    if (!estoques || estoques.length === 0) {
      throw new Error("Nenhum registro encontrado");
    }

    // 🧮 Calcular saldos acumulados
    let saldoAmbAcumulado = 0;
    let saldoVinteAcumulado = 0;
    
    const dadosProcessados = estoques.map((item: any) => {
      const entradaAmb = Number(item.entrada_amb) || 0;
      const entradaVinte = Number(item.entrada_vinte) || 0;
      const saidaAmb = Number(item.saida_amb) || 0;
      const saidaVinte = Number(item.saida_vinte) || 0;
      
      saldoAmbAcumulado += entradaAmb - saidaAmb;
      saldoVinteAcumulado += entradaVinte - saidaVinte;

      const produtoNome = item.produtos?.nome || "";

      return {
        "Data": new Date(item.data_mov).toLocaleDateString("pt-BR"),
        "Produto": produtoNome,
        "Descrição": item.descricao || "",
        "Entrada (Amb.)": entradaAmb,
        "Entrada (20ºC)": entradaVinte,
        "Saída (Amb.)": saidaAmb,
        "Saída (20ºC)": saidaVinte,
        "Saldo (Amb.)": saldoAmbAcumulado,
        "Saldo (20ºC)": saldoVinteAcumulado,
      };
    });

    // 📊 Criar planilha Excel
    const worksheet = XLSX.utils.json_to_sheet(dadosProcessados);
    
    // 🎨 Ajustar larguras das colunas (opcional)
    const colWidths = [
      { wch: 12 }, // Data
      { wch: 25 }, // Produto
      { wch: 30 }, // Descrição
      { wch: 15 }, // Entrada (Amb.)
      { wch: 15 }, // Entrada (20ºC)
      { wch: 15 }, // Saída (Amb.)
      { wch: 15 }, // Saída (20ºC)
      { wch: 15 }, // Saldo (Amb.)
      { wch: 15 }, // Saldo (20ºC)
    ];
    worksheet["!cols"] = colWidths;

    // 📄 Criar workbook
    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, "Estoque");

    // 🔧 Adicionar informações de cabeçalho
    const infoRows = [
      ["Relatório de Estoque"],
      [`Filial: ${nomeFilial}`],
      [`Mês: ${mes.getMonth() + 1}/${mes.getFullYear()}`],
      [`Produto: ${produtoFiltro === "todos" || !produtoFiltro ? "Todos" : "Específico"}`],
      [`Gerado em: ${new Date().toLocaleDateString("pt-BR")} ${new Date().toLocaleTimeString("pt-BR")}`],
      [], // Linha vazia
    ];

    // Inserir linhas de informação acima dos dados
    XLSX.utils.sheet_add_aoa(worksheet, infoRows, { origin: "A1" });

    // 📁 Gerar arquivo XLSX
    const excelBuffer = XLSX.write(workbook, { type: "array", bookType: "xlsx" });
    
    // 📝 Nome do arquivo
    const fileName = `estoque_${nomeFilial.replace(/\s+/g, "_")}_${mes.getMonth() + 1}_${mes.getFullYear()}.xlsx`;

    // ✅ Retornar arquivo XLSX
    return new Response(excelBuffer, {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "Content-Disposition": `attachment; filename="${fileName}"`,
      },
    });

  } catch (err) {
    const errorMessage = err instanceof Error ? err.message : String(err);
    console.error("❌ Erro em down_excel_estoques:", errorMessage);

    return new Response(
      JSON.stringify({ success: false, error: errorMessage }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});