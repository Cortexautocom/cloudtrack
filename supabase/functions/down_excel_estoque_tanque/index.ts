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
    const {
      tanqueId,
      referenciaTanque,
      filialId,
      nomeFilial,
      data,
      estoqueInicial,
      estoqueFinal,
      estoqueCACL,
      possuiCACL,
      valorSobraPerda,
      ehSobra,
    } = await req.json();

    if (!tanqueId || !filialId || !data) {
      throw new Error("tanqueId, filialId e data são obrigatórios");
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

    const dia = new Date(data);
    const inicio = new Date(dia.getFullYear(), dia.getMonth(), dia.getDate(), 0, 0, 0);
    const fim = new Date(dia.getFullYear(), dia.getMonth(), dia.getDate(), 23, 59, 59);

    const { data: movs, error } = await supabase
      .from("movimentacoes_tanque")
      .select(`
        data_mov,
        cliente,
        descricao,
        entrada_amb,
        entrada_vinte,
        saida_amb,
        saida_vinte
      `)
      .eq("tanque_id", tanqueId)
      .gte("data_mov", inicio.toISOString())
      .lte("data_mov", fim.toISOString())
      .order("data_mov", { ascending: true });

    if (error) throw error;
    if (!movs || !movs.length) throw new Error("Sem dados para o período");

    let saldoAmb = Number(estoqueInicial?.amb) || 0;
    let saldoVinte = Number(estoqueInicial?.vinte) || 0;

    const dados = movs.map((i: any) => {
      const ea = Number(i.entrada_amb) || 0;
      const ev = Number(i.entrada_vinte) || 0;
      const sa = Number(i.saida_amb) || 0;
      const sv = Number(i.saida_vinte) || 0;

      saldoAmb += ea - sa;
      saldoVinte += ev - sv;

      const descFinal = (i.cliente && i.cliente.trim()) ? i.cliente : (i.descricao || "");

      return [
        new Date(i.data_mov).toLocaleDateString("pt-BR"),
        descFinal,
        ea,
        ev,
        sa,
        sv,
        saldoAmb,
        saldoVinte,
      ];
    });

    const worksheet = XLSX.utils.aoa_to_sheet([
      ["RELATÓRIO DE ESTOQUE DO TANQUE"],
      [`Tanque: ${referenciaTanque}`],
      [`Filial: ${nomeFilial}`],
      [`Data: ${dia.toLocaleDateString("pt-BR")}`],
      [
        `Gerado em: ${new Date().toLocaleDateString("pt-BR")} ${new Date().toLocaleTimeString("pt-BR")}`,
      ],
      [],
      ["Data", "Descrição", "Entrada (Amb.)", "Entrada (20ºC)", "Saída (Amb.)", "Saída (20ºC)", "Saldo (Amb.)", "Saldo (20ºC)"],
      ...dados,
      [],
      ["Resumo"],
      ["Estoque Inicial (20ºC)", estoqueInicial?.vinte ?? 0],
      ["Estoque Final Calculado (20ºC)", estoqueFinal?.vinte ?? 0],
      ...(possuiCACL ? [["Saldo do CACL (20ºC)", estoqueCACL?.vinte ?? 0]] : []),
      ...(valorSobraPerda != null
        ? [[ehSobra ? "Sobra (20ºC)" : "Perda (20ºC)", valorSobraPerda]]
        : []),
    ]);

    const colNumericas = [2, 3, 4, 5, 6, 7];
    const range = XLSX.utils.decode_range(worksheet["!ref"]!);

    for (let r = 6; r <= range.e.r; r++) {
      for (const c of colNumericas) {
        const cellRef = XLSX.utils.encode_cell({ r, c });
        const cell = worksheet[cellRef];
        if (!cell) continue;

        cell.t = "n";
        cell.z = "#,##0";
      }
    }

    worksheet["!cols"] = [
      { wch: 12 },
      { wch: 40 },
      { wch: 16 },
      { wch: 16 },
      { wch: 16 },
      { wch: 16 },
      { wch: 16 },
      { wch: 16 },
    ];

    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, worksheet, "Estoque Tanque");

    const buffer = XLSX.write(wb, { type: "array", bookType: "xlsx" });

    return new Response(buffer, {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type":
          "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "Content-Disposition": `attachment; filename="estoque_tanque_${referenciaTanque}.xlsx"`,
      },
    });
  } catch (e) {
    return new Response(
      JSON.stringify({ error: e instanceof Error ? e.message : e }),
      { status: 400, headers: corsHeaders },
    );
  }
});
