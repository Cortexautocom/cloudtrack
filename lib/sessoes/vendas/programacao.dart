import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'nova_venda.dart';
import 'dart:convert';

class ProgramacaoPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const ProgramacaoPage({super.key, required this.onVoltar});

  @override
  State<ProgramacaoPage> createState() => _ProgramacaoPageState();
}

class _ProgramacaoPageState extends State<ProgramacaoPage> {
  bool carregando = true;
  List<Map<String, dynamic>> movimentacoes = [];

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
          .from("movimentacoes")
          .select("*")
          .eq("tipo_op", "venda")
          .order("created_at", ascending: false);

      setState(() {
        movimentacoes = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint("Erro ao carregar movimentacoes: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar movimentacoes: $e'),
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
      await supabase.from("movimentacoes").update({campo: valor}).eq("id", id);
      
      setState(() {
        final index = movimentacoes.indexWhere((v) => v['id'] == id);
        if (index != -1) {
          movimentacoes[index][campo] = valor;
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
            carregar();
          }
        },
      ),
    );

    if (result == true) {
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
          : movimentacoes.isEmpty
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
              : ExcelTabelaDividida(
                  dados: movimentacoes,
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
//                TABELA EXCEL DIVIDIDA EM GRUPOS
// ==============================================================

class ExcelTabelaDividida extends StatefulWidget {
  final List<Map<String, dynamic>> dados;
  final Function(String id, String campo, dynamic valor) onEdit;

  const ExcelTabelaDividida({
    super.key,
    required this.dados,
    required this.onEdit,
  });

  @override
  State<ExcelTabelaDividida> createState() => _ExcelTabelaDivididaState();
}

class _ExcelTabelaDivididaState extends State<ExcelTabelaDividida> {
  int grupoAtual = 0; // 0 para Grupo 1, 1 para Grupo 2
  final horizontalScrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Menu de navegação compacto
        Container(
          height: 32, // Altura mínima
          color: Colors.grey.shade100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _botaoGrupo("Grupo 1", 0),
              const SizedBox(width: 8),
              _botaoGrupo("Grupo 2", 1),
            ],
          ),
        ),
        
        // Cabeçalho e conteúdo da tabela
        Expanded(
          child: _construirTabela(grupoAtual),
        ),
      ],
    );
  }

  Widget _botaoGrupo(String texto, int grupo) {
    final bool selecionado = grupoAtual == grupo;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          grupoAtual = grupo;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: selecionado ? Colors.blue.shade700 : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selecionado ? Colors.blue.shade700 : Colors.grey.shade400,
            width: 1,
          ),
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selecionado ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _construirTabela(int grupo) {
    final verticalScrollController = ScrollController();

    // 1. Filtrar os dados para o grupo atual
    final dadosFiltrados = widget.dados.where((l) {
      if (grupo == 0) {
        return ['g_comum', 'g_aditivada', 'd_s10', 'd_s500', 'etanol', 'anidro']
            .any((k) => (double.tryParse(l[k]?.toString() ?? '0') ?? 0) > 0);
      } else {
        return ['b100', 'gasolina_a', 's500_a', 's10_a']
            .any((k) => (double.tryParse(l[k]?.toString() ?? '0') ?? 0) > 0);
      }
    }).toList();

    return Column(
      children: [
        // Cabeçalho (Aqui é onde chamamos a função que estava 'sem uso')
        Container(
          height: 40,
          color: Colors.blue.shade700,
          child: SingleChildScrollView(
            controller: horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _obterColunasCabecalho(grupo), // Chamada restaurada
            ),
          ),
        ),
        
        // Conteúdo filtrado
        Expanded(
          child: Scrollbar(
            controller: horizontalScrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: horizontalScrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: _obterLarguraTabela(grupo), // Chamada restaurada
                child: Scrollbar(
                  controller: verticalScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: verticalScrollController,
                    child: Column(
                      children: List.generate(
                        dadosFiltrados.length,
                        (i) => _linha(dadosFiltrados[i], i, grupo),
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

  double _obterLarguraTabela(int grupo) {
    // Largura total base das colunas fixas
    double larguraFixa = 120 + 100 + 220 + 80 + 60 + 100; // Placa, Status, Cliente, Cód., UF, Prazo
    
    if (grupo == 0) {
      return larguraFixa + (90 * 6); // 6 colunas do Grupo 1
    } else {
      return larguraFixa + (90 * 4); // 4 colunas do Grupo 2
    }
  }

  // ----------------------------------------------------------
  // CABEÇALHO
  // ----------------------------------------------------------
  List<Widget> _obterColunasCabecalho(int grupo) {
    final colunasFixas = [
      _th("Placa", 120),
      _th("Status", 100),
      _th("Cliente", 220),
      _th("Cód.", 80),
      _th("UF", 60),
      _th("Prazo", 100),
    ];

    if (grupo == 0) {
      // Grupo 1: G. Com. até Etanol
      return [
        ...colunasFixas,
        _th("G. Com.", 90),
        _th("G. Aditiv.", 90),
        _th("D. S10", 90),
        _th("D. S500", 90),
        _th("Etanol", 90),
        _th("Anidro", 90),
      ];
    } else {
      // Grupo 2: B100 até S10 A (sem G. Com. e G. Aditiv.)
      return [
        ...colunasFixas,
        _th("B100", 90),
        _th("G. A", 90),
        _th("S500 A", 90),
        _th("S10 A", 90),
      ];
    }
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
  Widget _linha(Map<String, dynamic> l, int i, int grupo) {
    final cor = i % 2 == 0 ? Colors.grey.shade200 : Colors.grey.shade300;

    return Container(
      height: 50,
      color: cor,
      child: Row(
        children: _obterCelulasLinha(l, grupo),
      ),
    );
  }

  List<Widget> _obterCelulasLinha(Map<String, dynamic> l, int grupo) {
    // 1. Verificar se há valores nos produtos do grupo atual
    bool temProduto = false;
    if (grupo == 0) {
      // Grupo 1
      temProduto = [
        'g_comum', 'g_aditivada', 'd_s10', 'd_s500', 'etanol', 'anidro'
      ].any((k) => (double.tryParse(l[k]?.toString() ?? '0') ?? 0) > 0);
    } else {
      // Grupo 2
      temProduto = [
        'b100', 'gasolina_a', 's500_a', 's10_a'
      ].any((k) => (double.tryParse(l[k]?.toString() ?? '0') ?? 0) > 0);
    }

    // 2. Definir o que exibir nas colunas condicionais
    String codigo = temProduto ? (l["codigo"]?.toString() ?? "") : "";
    String uf = temProduto ? (l["uf"]?.toString() ?? "") : "";
    String prazo = temProduto ? (l["forma_pagamento"]?.toString() ?? "") : "";

    // 3. Montar as células fixas com os valores condicionados
    final celulasFixas = [
      _cell(l["id"], "placa", _obterPrimeiraPlaca(l["placa"]), largura: 120),
      _statusCell(l["status_circuito"]),
      _cell(l["id"], "cliente", l["cliente"]?.toString() ?? "", largura: 220),
      _cell(l["id"], "codigo", codigo, largura: 80), // Valor condicionado
      _cell(l["id"], "uf", uf, largura: 60),         // Valor condicionado
      _cell(l["id"], "forma_pagamento", prazo, largura: 100), // Valor condicionado
    ];

    // Retorno dos grupos (permanece igual, apenas usando as novas celulasFixas)
    if (grupo == 0) {
      return [
        ...celulasFixas,
        _cell(l["id"], "g_comum", l["g_comum"].toString(), largura: 90, numero: true),
        _cell(l["id"], "g_aditivada", l["g_aditivada"].toString(), largura: 90, numero: true),
        _cell(l["id"], "d_s10", l["d_s10"].toString(), largura: 90, numero: true),
        _cell(l["id"], "d_s500", l["d_s500"].toString(), largura: 90, numero: true),
        _cell(l["id"], "etanol", l["etanol"].toString(), largura: 90, numero: true),
        _cell(l["id"], "anidro", l["anidro"].toString(), largura: 90, numero: true),
      ];
    } else {
      return [
        ...celulasFixas,
        _cell(l["id"], "b100", l["b100"].toString(), largura: 90, numero: true),
        _cell(l["id"], "gasolina_a", l["gasolina_a"].toString(), largura: 90, numero: true),
        _cell(l["id"], "s500_a", l["s500_a"].toString(), largura: 90, numero: true),
        _cell(l["id"], "s10_a", l["s10_a"].toString(), largura: 90, numero: true),
      ];
    }
  }

  // ----------------------------------------------------------
  // CÉLULA DE STATUS
  // ----------------------------------------------------------
  Widget _statusCell(dynamic statusCircuito) {
    final status = _obterTextoStatus(statusCircuito);
    final corStatus = _obterCorStatus(statusCircuito);
    
    return Container(
      width: 100,
      height: 50,
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: corStatus.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: corStatus.withOpacity(0.3), width: 1),
        ),
        child: Text(
          status,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: corStatus,
          ),
        ),
      ),
    );
  }

  String _obterTextoStatus(dynamic statusCircuito) {
    if (statusCircuito == null) return "Programado";
    
    final statusNum = int.tryParse(statusCircuito.toString()) ?? 1;
    
    switch (statusNum) {
      case 1: return "Programado";
      case 2: return "Em check-list";
      case 3: return "Em operação";
      case 4: return "Aguardando NF";
      case 5: return "Expedido";
      default: return "Programado";
    }
  }

  Color _obterCorStatus(dynamic statusCircuito) {
    if (statusCircuito == null) return Colors.blue;
    
    final statusNum = int.tryParse(statusCircuito.toString()) ?? 1;
    
    switch (statusNum) {
      case 1: return Colors.blue; // Programado
      case 2: return Colors.orange; // Em check-list
      case 3: return Colors.green; // Em operação
      case 4: return Colors.purple; // Aguardando NF
      case 5: return Colors.grey; // Expedido
      default: return Colors.blue;
    }
  }

  // ----------------------------------------------------------
  // CÉLULA EDITÁVEL
  // ----------------------------------------------------------
  Widget _cell(String id, String campo, String valor,
      {double largura = 100, bool numero = false}) {
    return EditableCell(
      largura: largura,
      valorInicial: valor,
      numero: numero,
      onSubmit: (v) => widget.onEdit(id, campo, v),
    );
  }

  // Função para obter apenas o primeiro item do array de placas
  String _obterPrimeiraPlaca(dynamic placaData) {
    if (placaData == null) return "";
    
    if (placaData is String) {
      try {
        final parsed = jsonDecode(placaData);
        if (parsed is List && parsed.isNotEmpty) {
          return parsed.first.toString();
        }
      } catch (e) {
        return placaData.toString();
      }
    }
    
    if (placaData is List && placaData.isNotEmpty) {
      return placaData.first.toString();
    }
    
    return placaData.toString();
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

  String _formatarValorParaExibicao(String valor) {
    if (widget.numero && valor.isNotEmpty) {
      String apenasNumeros = valor.replaceAll(RegExp(r'\D'), '');
      
      if (apenasNumeros.isEmpty) return "";
      
      try {
        int valorNumerico = int.parse(apenasNumeros);
        if (valorNumerico == 0) return "";
        
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

  String _prepararParaSalvar(String valor) {
    if (widget.numero) {
      String semFormatacao = valor.replaceAll(RegExp(r'\D'), '');
      if (semFormatacao.isEmpty) return "0";
      
      try {
        int valorNumerico = int.parse(semFormatacao);
        return valorNumerico.toString();
      } catch (e) {
        return "0";
      }
    } else {
      return valor.trim();
    }
  }

  String _aplicarMascaraNumerica(String valor) {
    if (!widget.numero) return valor;
    
    String apenasNumeros = valor.replaceAll(RegExp(r'\D'), '');
    
    if (apenasNumeros.isEmpty) return "";
    
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