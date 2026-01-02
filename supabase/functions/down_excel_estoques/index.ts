import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as XLSX from "https://esm.sh/xlsx@0.18.5";

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
    const { filialId, nomeFilial, empresaId, mesFiltro, produtoFiltro } =
      await req.json();

    if (!filialId || !mesFiltro) {
      throw new Error("ID da filial e mês são obrigatórios");
    }

    const supabase = createClient(
      Deno.env.get("PROJECT_URL")!,
      Deno.env.get("SERVICE_ROLE_KEY")!,
    );

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) throw new Error("Token não informado");

    const token = authHeader.replace("Bearer ", "");
    const { data: { user } } = await supabase.auth.getUser(token);
    if (!user) throw new Error("Usuário não autenticado");

    let empresaIdFinal = empresaId;
    if (!empresaIdFinal) {
      const { data } = await supabase
        .from("filiais")
        .select("empresa_id")
        .eq("id", filialId)
        .single();

      empresaIdFinal = data?.empresa_id;
    }

    const mes = new Date(mesFiltro);
    const primeiroDia = new Date(mes.getFullYear(), mes.getMonth(), 1);
    const ultimoDia = new Date(mes.getFullYear(), mes.getMonth() + 1, 0);

    let query = supabase
      .from("movimentacoes")
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

    if (produtoFiltro && produtoFiltro !== "todos") {
      query = query.eq("produto_id", produtoFiltro);
    }

    const { data: movimentacoes } = await query;
    if (!movimentacoes?.length) throw new Error("Sem dados");

    let saldoAmb = 0;
    let saldoVinte = 0;

    const dados = movimentacoes.map((i: any) => {
      const ea = Number(i.entrada_amb) || 0;
      const ev = Number(i.entrada_vinte) || 0;
      const sa = Number(i.saida_amb) || 0;
      const sv = Number(i.saida_vinte) || 0;

      saldoAmb += ea - sa;
      saldoVinte += ev - sv;

      return [
        new Date(i.data_mov).toLocaleDateString("pt-BR"),
        i.produtos?.nome || "",
        i.descricao || "",
        ea,
        ev,
        sa,
        sv,
        saldoAmb,
        saldoVinte,
      ];
    });

    const worksheet = XLSX.utils.aoa_to_sheet([
      ["RELATÓRIO DE ESTOQUE"],
      [`Filial: ${nomeFilial}`],
      [`Mês: ${mes.getMonth() + 1}/${mes.getFullYear()}`],
      [
        `Produto: ${
          !produtoFiltro || produtoFiltro === "todos"
            ? "Todos"
            : "Específico"
        }`,
      ],
      [
        `Gerado em: ${new Date().toLocaleDateString("pt-BR")} ${new Date().toLocaleTimeString("pt-BR")}`,
      ],
      [],
      [
        "Data",
        "Produto",
        "Descrição",
        "Entrada (Amb.)",
        "Entrada (20ºC)",
        "Saída (Amb.)",
        "Saída (20ºC)",
        "Saldo (Amb.)",
        "Saldo (20ºC)",
      ],
      ...dados,
    ]);

    const colNumericas = [3, 4, 5, 6, 7, 8];
    const range = XLSX.utils.decode_range(worksheet["!ref"]!);

    for (let r = 7; r <= range.e.r; r++) {
      for (const c of colNumericas) {
        const cellRef = XLSX.utils.encode_cell({ r, c });
        const cell = worksheet[cellRef];
        if (!cell) continue;

        cell.t = "n";
        cell.z = "#,##0";
        cell.s = {
          alignment: { horizontal: "center" },
        };
      }
    }

    worksheet["!cols"] = [
      { wch: 12 },
      { wch: 25 },
      { wch: 30 },
      { wch: 15 },
      { wch: 15 },
      { wch: 15 },
      { wch: 15 },
      { wch: 15 },
      { wch: 15 },
    ];

    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, worksheet, "Estoque");

    const buffer = XLSX.write(wb, { type: "array", bookType: "xlsx" });

    return new Response(buffer, {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type":
          "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "Content-Disposition": `attachment; filename="estoque.xlsx"`,
      },
    });
  } catch (e) {
    return new Response(
      JSON.stringify({ error: e instanceof Error ? e.message : e }),
      { status: 400, headers: corsHeaders },
    );
  }
});
