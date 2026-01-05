import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'nova_venda.dart';

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
    setState(() => carregando = true);

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from("vendas")
          .select("*")
          .order("data_criacao", ascending: false);

      setState(() {
        vendas = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint("Erro ao carregar vendas: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar vendas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => carregando = false);
    }
  }

  Future<void> atualizarCampo(String id, String campo, dynamic valor) async {
    final supabase = Supabase.instance.client;

    try {
      await supabase.from("vendas").update({campo: valor}).eq("id", id);
      
      // Atualiza localmente
      setState(() {
        final index = vendas.indexWhere((v) => v['id'] == id);
        if (index != -1) {
          vendas[index][campo] = valor;
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Campo atualizado com sucesso!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint("Erro ao atualizar: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _mostrarDialogNovaVenda() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => NovaVendaDialog(
        onSalvar: (sucesso) {
          if (sucesso) {
            // Recarrega os dados quando uma nova venda é salva
            carregar();
          }
        },
      ),
    );

    if (result == true) {
      // Recarrega os dados após salvar
      await carregar();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: carregar,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : vendas.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.list, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Nenhuma venda encontrada',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ExcelTabela(
                  dados: vendas,
                  onEdit: atualizarCampo,
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarDialogNovaVenda,
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
        child: const Icon(Icons.add_box, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
    final horizontalScrollController = ScrollController();
    final verticalScrollController = ScrollController();

    return Column(
      children: [
        _cabecalho(),
        Expanded(
          child: Scrollbar(
            controller: horizontalScrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: horizontalScrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 1900,
                child: Scrollbar(
                  controller: verticalScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: verticalScrollController,
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
      height: 50,
      color: cor,
      child: Row(
        children: [
          _cell(l["id"], "placa", l["placa"]?.toString() ?? "", largura: 120),
          _cell(l["id"], "cliente", l["cliente"]?.toString() ?? "", largura: 220),
          _cell(l["id"], "codigo", l["codigo"]?.toString() ?? "", largura: 80),
          _cell(l["id"], "uf", l["uf"]?.toString() ?? "", largura: 60),
          _cell(l["id"], "forma_pagamento", l["forma_pagamento"]?.toString() ?? "", largura: 100),

          // Colunas numéricas com formatação
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

  // Formata o valor para exibição (apenas para campos numéricos)
  String _formatarValorParaExibicao(String valor) {
    if (widget.numero && valor.isNotEmpty) {
      // Remove qualquer formatação existente
      String apenasNumeros = valor.replaceAll(RegExp(r'\D'), '');
      
      if (apenasNumeros.isEmpty) return "";
      
      // Converte para inteiro para remover zeros à esquerda
      try {
        int valorNumerico = int.parse(apenasNumeros);
        if (valorNumerico == 0) return "";
        
        // Aplica formatação 999.999
        String valorString = valorNumerico.toString();
        if (valorString.length > 3) {
          return "${valorString.substring(0, valorString.length - 3)}.${valorString.substring(valorString.length - 3)}";
        }
        return valorString;
      } catch (e) {
        return valor;
      }
    }
    return valor;
  }

  // Prepara o valor para salvar no banco de dados
  String _prepararParaSalvar(String valor) {
    if (widget.numero) {
      // Para campos numéricos, remove a formatação e mantém apenas números
      String semFormatacao = valor.replaceAll(RegExp(r'\D'), '');
      if (semFormatacao.isEmpty) return "0";
      
      try {
        // Converte para inteiro para remover zeros à esquerda
        int valorNumerico = int.parse(semFormatacao);
        return valorNumerico.toString();
      } catch (e) {
        return "0";
      }
    } else {
      // Para campos de texto, retorna o valor exatamente como foi digitado
      return valor.trim();
    }
  }

  // Formata em tempo real enquanto o usuário digita (apenas para campos numéricos)
  String _aplicarMascaraNumerica(String valor) {
    if (!widget.numero) return valor; // Não aplica máscara para campos não numéricos
    
    String apenasNumeros = valor.replaceAll(RegExp(r'\D'), '');
    
    if (apenasNumeros.isEmpty) return "";
    
    // Remove zeros à esquerda
    try {
      int valorNumerico = int.tryParse(apenasNumeros) ?? 0;
      if (valorNumerico == 0) return "";
      
      String valorString = valorNumerico.toString();
      
      if (valorString.length > 3) {
        return "${valorString.substring(0, valorString.length - 3)}.${valorString.substring(valorString.length - 3)}";
      }
      return valorString;
    } catch (e) {
      return apenasNumeros;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Para campos não numéricos, usamos o valor original
    // Para campos numéricos, aplicamos a formatação na exibição
    final valorExibicao = widget.numero 
        ? _formatarValorParaExibicao(widget.valorInicial)
        : widget.valorInicial;

    if (controller.text != valorExibicao) {
      controller.text = valorExibicao;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: () {
        setState(() {
          editando = true;
        });
      },
      child: Container(
        width: widget.largura,
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        child: editando
            ? Focus(
                onFocusChange: (focus) {
                  if (!focus) {
                    // Salva o valor preparado
                    widget.onSubmit(_prepararParaSalvar(controller.text));
                    setState(() => editando = false);
                  }
                },
                child: TextField(
                  autofocus: true,
                  controller: controller,
                  textAlign: TextAlign.center,
                  keyboardType: widget.numero ? TextInputType.number : TextInputType.text,
                  onChanged: (v) {
                    if (widget.numero) {
                      // Aplica a máscara em tempo real apenas para campos numéricos
                      String novaFormatacao = _aplicarMascaraNumerica(v);
                      if (controller.text != novaFormatacao) {
                        controller.text = novaFormatacao;
                        controller.selection = TextSelection.fromPosition(
                          TextPosition(offset: controller.text.length),
                        );
                      }
                    }
                  },
                  onSubmitted: (v) {
                    widget.onSubmit(_prepararParaSalvar(v));
                    setState(() => editando = false);
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Text(
                  valorExibicao,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: widget.numero ? FontWeight.w500 : FontWeight.normal,
                    color: valorExibicao.isEmpty ? Colors.grey : Colors.black,
                  ),
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}