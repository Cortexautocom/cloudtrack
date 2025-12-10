import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ==============================================================
//                    PÁGINA PRINCIPAL
// ==============================================================

class ProgramacaoPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const ProgramacaoPage({super.key, required this.onVoltar});

  @override
  State<ProgramacaoPage> createState() => _ProgramacaoPageState();
}

class _ProgramacaoPageState extends State<ProgramacaoPage> {
  bool carregando = true;
  List<Map<String, dynamic>> vendas = [];

  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    final supabase = Supabase.instance.client;

    setState(() => carregando = true);

    try {
      final response = await supabase
          .from("vendas")
          .select("*")
          .order("data_criacao", ascending: false);

      setState(() {
        vendas = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint("Erro: $e");
    }

    setState(() => carregando = false);
  }

  Future<void> atualizarCampo(String id, String campo, dynamic valor) async {
    final supabase = Supabase.instance.client;

    try {
      await supabase.from("vendas").update({campo: valor}).eq("id", id);
    } catch (e) {
      debugPrint("Erro ao atualizar: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Programação de Vendas"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onVoltar,
        ),
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : ExcelTabela(
              dados: vendas,
              onEdit: atualizarCampo,
            ),
    );
  }
}

// ==============================================================
//                        TABELA EXCEL
// ==============================================================

class ExcelTabela extends StatelessWidget {
  final List<Map<String, dynamic>> dados;
  final Function(String id, String campo, dynamic valor) onEdit;

  const ExcelTabela({
    super.key,
    required this.dados,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _cabecalho(),
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 1900,
                child: SingleChildScrollView(
                  child: Column(
                    children: List.generate(
                      dados.length,
                      (i) => _linha(dados[i], i, context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------
  // CABEÇALHO
  // ----------------------------------------------------------
  Widget _cabecalho() {
    return Container(
      height: 40,
      color: Colors.blue.shade700,
      child: Row(
        children: [
          _th("Placa", 120),
          _th("Cliente", 220),
          _th("Cód.", 80),
          _th("UF", 60),
          _th("Prazo", 100),

          _th("G. Com.", 90),
          _th("G. Aditiv.", 90),

          _th("D. S10", 90),
          _th("D. S500", 90),

          _th("Etanol", 90),
          _th("Anidro", 90),
          _th("B100", 90),

          _th("G. A", 90),
          _th("S500 A", 90),
          _th("S10 A", 90),
        ],
      ),
    );
  }

  Widget _th(String texto, double largura) {
    return Container(
      width: largura,
      alignment: Alignment.center,
      child: Text(
        texto,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // LINHA
  // ----------------------------------------------------------
  Widget _linha(Map<String, dynamic> l, int i, BuildContext context) {
    final cor = i % 2 == 0 ? Colors.grey.shade200 : Colors.grey.shade300;

    return Container(
      color: cor,
      child: Row(
        children: [
          _cell(l["id"], "placa", l["placa"], largura: 120),
          _cell(l["id"], "cliente", l["cliente"], largura: 220),
          _cell(l["id"], "codigo", l["codigo"]?.toString() ?? "", largura: 80),
          _cell(l["id"], "uf", l["uf"] ?? "", largura: 60),
          _cell(l["id"], "forma_pagamento", l["forma_pagamento"] ?? "", largura: 100),

          _cell(l["id"], "g_comum", l["g_comum"].toString(), largura: 90, numero: true),
          _cell(l["id"], "g_aditivada", l["g_aditivada"].toString(), largura: 90, numero: true),

          _cell(l["id"], "d_s10", l["d_s10"].toString(), largura: 90, numero: true),
          _cell(l["id"], "d_s500", l["d_s500"].toString(), largura: 90, numero: true),

          _cell(l["id"], "etanol", l["etanol"].toString(), largura: 90, numero: true),
          _cell(l["id"], "anidro", l["anidro"].toString(), largura: 90, numero: true),
          _cell(l["id"], "b100", l["b100"].toString(), largura: 90, numero: true),

          _cell(l["id"], "gasolina_a", l["gasolina_a"].toString(), largura: 90, numero: true),
          _cell(l["id"], "s500_a", l["s500_a"].toString(), largura: 90, numero: true),
          _cell(l["id"], "s10_a", l["s10_a"].toString(), largura: 90, numero: true),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // CÉLULA
  // ----------------------------------------------------------
  Widget _cell(String id, String campo, String valor,
      {double largura = 100, bool numero = false}) {
    return EditableCell(
      largura: largura,
      valorInicial: valor,
      numero: numero,
      onSubmit: (v) => onEdit(id, campo, v),
    );
  }
}

// ==============================================================
//          COMPONENTE: CÉLULA EDITÁVEL (DUPO CLIQUE)
// ==============================================================

class EditableCell extends StatefulWidget {
  final String valorInicial;
  final Function(String) onSubmit;
  final double largura;
  final bool numero;

  const EditableCell({
    super.key,
    required this.valorInicial,
    required this.onSubmit,
    this.largura = 100,
    this.numero = false,
  });

  @override
  State<EditableCell> createState() => _EditableCellState();
}

class _EditableCellState extends State<EditableCell> {
  bool editando = false;
  late TextEditingController controller;

  @override
  void initState() {
    controller = TextEditingController(text: widget.valorInicial);
    super.initState();
  }

  String aplicarMascara(String v) {
    v = v.replaceAll(RegExp(r'\D'), ""); // mantém só números
    if (v.isEmpty) return "";

    if (v.length > 3) {
      return "${v.substring(0, v.length - 3)}.${v.substring(v.length - 3)}";
    }
    return v;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: () => setState(() => editando = true),
      child: Container(
        width: widget.largura,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: editando
            ? Focus(
                onFocusChange: (focus) {
                  if (!focus) {
                    widget.onSubmit(controller.text);
                    setState(() => editando = false);
                  }
                },
                child: TextField(
                  autofocus: true,
                  controller: controller,
                  onChanged: (v) {
                    if (widget.numero) {
                      controller.text = aplicarMascara(v);
                      controller.selection = TextSelection.fromPosition(
                        TextPosition(offset: controller.text.length),
                      );
                    }
                  },
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(4),
                  ),
                ),
              )
            : Text(controller.text),
      ),
    );
  }
}
