import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'nova_venda.dart';
import 'dart:async';

// ==============================================================
//                PÁGINA DE PROGRAMAÇÃO DE VENDAS
// ==============================================================

class ProgramacaoPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const ProgramacaoPage({super.key, required this.onVoltar});

  @override
  State<ProgramacaoPage> createState() => _ProgramacaoPageState();
}

class _ProgramacaoPageState extends State<ProgramacaoPage> {
  bool carregando = true;
  List<Map<String, dynamic>> movimentacoes = [];
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalHeaderController = ScrollController();
  final ScrollController _horizontalBodyController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  int grupoAtual = 0;

  @override
  void initState() {
    super.initState();
    carregar();

    _horizontalHeaderController.addListener(() {
      if (_horizontalBodyController.hasClients &&
          _horizontalBodyController.offset != _horizontalHeaderController.offset) {
        _horizontalBodyController.jumpTo(_horizontalHeaderController.offset);
      }
    });

    _horizontalBodyController.addListener(() {
      if (_horizontalHeaderController.hasClients &&
          _horizontalHeaderController.offset != _horizontalBodyController.offset) {
        _horizontalHeaderController.jumpTo(_horizontalBodyController.offset);
      }
    });
  }

  @override
  void dispose() {
    _horizontalHeaderController.dispose();
    _horizontalBodyController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  Future<void> carregar() async {
    setState(() => carregando = true);

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from("movimentacoes")
          .select("*")
          .eq("tipo_op", "venda")
          .order("created_at", ascending: true);

      setState(() {
        movimentacoes = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint("Erro ao carregar movimentacoes: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar movimentações: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => carregando = false);
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

  List<Map<String, dynamic>> get _movimentacoesFiltradas {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) return _obterDadosFiltrados(grupoAtual);

    return _obterDadosFiltrados(grupoAtual).where((t) {
      return (t['cliente']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['placa']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['forma_pagamento']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['codigo']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['uf']?.toString().toLowerCase() ?? '').contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> _obterDadosFiltrados(int grupo) {
    return movimentacoes.where((l) {
      if (grupo == 0) {
        return ['g_comum', 'g_aditivada', 'd_s10', 'd_s500', 'etanol', 'anidro']
            .any((k) => (double.tryParse(l[k]?.toString() ?? '0') ?? 0) > 0);
      } else {
        return ['b100', 'gasolina_a', 's500_a', 's10_a']
            .any((k) => (double.tryParse(l[k]?.toString() ?? '0') ?? 0) > 0);
      }
    }).toList();
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
      case 1: return Colors.blue;
      case 2: return Colors.orange;
      case 3: return Colors.green;
      case 4: return Colors.purple;
      case 5: return Colors.grey;
      default: return Colors.blue;
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
          Container(
            width: 300,
            margin: const EdgeInsets.only(right: 16),
            child: _buildSearchField(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: carregar,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : _buildBodyContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarDialogNovaVenda,
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
        child: const Icon(Icons.add_box, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildBodyContent() {
    return Scrollbar(
      controller: _verticalScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalScrollController,
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          child: Column(
            children: [
              // Menu de navegação de grupos - SEMPRE VISÍVEL
              Container(
                height: 40,
                color: Colors.grey.shade100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildGrupoButton("Grupo 1", 0),
                    const SizedBox(width: 16),
                    _buildGrupoButton("Grupo 2", 1),
                  ],
                ),
              ),
              
              // Contador de registros - SEMPRE VISÍVEL
              Container(
                height: 32,
                color: Colors.grey.shade50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_movimentacoesFiltradas.length} venda(s)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              
              // Conteúdo da tabela ou mensagem vazia
              if (_movimentacoesFiltradas.isEmpty)
                _buildEmptyState()
              else
                _buildTabelaConteudo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Nenhuma venda encontrada',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            if (_searchController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Tente alterar os termos da pesquisa',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.search, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Pesquisar...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear, color: Colors.grey.shade600, size: 20),
              onPressed: () {
                _searchController.clear();
                setState(() {});
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36),
            ),
        ],
      ),
    );
  }

  Widget _buildTabelaConteudo() {
    return Column(
      children: [
        // Cabeçalho da tabela com rolagem horizontal
        _buildHeader(),
        
        // Conteúdo da tabela com rolagem horizontal
        _buildBody(),
      ],
    );
  }

  Widget _buildGrupoButton(String texto, int grupo) {
    final bool selecionado = grupoAtual == grupo;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          grupoAtual = grupo;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: selecionado ? Colors.blue.shade700 : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selecionado ? Colors.blue.shade700 : Colors.grey.shade400,
            width: 1,
          ),
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: selecionado ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final larguraTabela = _obterLarguraTabela();
    
    return Scrollbar(
      controller: _horizontalHeaderController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontalHeaderController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: larguraTabela,
          child: Container(
            height: 40,
            color: const Color(0xFF0D47A1),
            child: Row(
              children: _obterColunasCabecalho(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final larguraTabela = _obterLarguraTabela();

    return Scrollbar(
      controller: _horizontalBodyController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontalBodyController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: larguraTabela,
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _movimentacoesFiltradas.length,
            itemBuilder: (context, index) {
              final t = _movimentacoesFiltradas[index];
              final statusCircuito = t['status_circuito'];
              final statusTexto = _obterTextoStatus(statusCircuito);
              final corStatus = _obterCorStatus(statusCircuito);
              
              // Verificar se há valores nos produtos do grupo atual
              bool temProduto = false;
              String codigo = "";
              String uf = "";
              String prazo = "";
              
              if (grupoAtual == 0) {
                temProduto = [
                  'g_comum', 'g_aditivada', 'd_s10', 'd_s500', 'etanol', 'anidro'
                ].any((k) => (double.tryParse(t[k]?.toString() ?? '0') ?? 0) > 0);
              } else {
                temProduto = [
                  'b100', 'gasolina_a', 's500_a', 's10_a'
                ].any((k) => (double.tryParse(t[k]?.toString() ?? '0') ?? 0) > 0);
              }
              
              if (temProduto) {
                codigo = t["codigo"]?.toString() ?? "";
                uf = t["uf"]?.toString() ?? "";
                prazo = t["forma_pagamento"]?.toString() ?? "";
              }
              
              return Container(
                height: 50,
                decoration: BoxDecoration(
                  color: index % 2 == 0 ? Colors.grey.shade50 : Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
                  ),
                ),
                child: Row(
                  children: _obterCelulasLinha(t, statusTexto, corStatus, codigo, uf, prazo),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  double _obterLarguraTabela() {
    double larguraFixa = 120 + 100 + 220 + 80 + 60 + 100;
    
    if (grupoAtual == 0) {
      return larguraFixa + (90 * 6); // 6 colunas do Grupo 1
    } else {
      return larguraFixa + (90 * 4); // 4 colunas do Grupo 2
    }
  }

  List<Widget> _obterColunasCabecalho() {
    final colunasFixas = [
      _th("Placa", 120),
      _th("Status", 100),
      _th("Cliente", 220),
      _th("Cód.", 80),
      _th("UF", 60),
      _th("Prazo", 100),
    ];

    if (grupoAtual == 0) {
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
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  List<Widget> _obterCelulasLinha(
    Map<String, dynamic> t,
    String statusTexto,
    Color corStatus,
    String codigo,
    String uf,
    String prazo,
  ) {
    final placas = t["placa"];
    final placaText = placas is List && placas.isNotEmpty 
        ? placas.first.toString() 
        : placas?.toString() ?? "";

    final celulasFixas = [
      _cell(placaText, 120),
      _statusCell(statusTexto, corStatus),
      _cell(t["cliente"]?.toString() ?? "", 220),
      _cell(codigo, 80),
      _cell(uf, 60),
      _cell(prazo, 100),
    ];

    if (grupoAtual == 0) {
      return [
        ...celulasFixas,
        _cell(_formatarQuantidade(t["g_comum"].toString()), 90, isNumber: true),
        _cell(_formatarQuantidade(t["g_aditivada"].toString()), 90, isNumber: true),
        _cell(_formatarQuantidade(t["d_s10"].toString()), 90, isNumber: true),
        _cell(_formatarQuantidade(t["d_s500"].toString()), 90, isNumber: true),
        _cell(_formatarQuantidade(t["etanol"].toString()), 90, isNumber: true),
        _cell(_formatarQuantidade(t["anidro"].toString()), 90, isNumber: true),
      ];
    } else {
      return [
        ...celulasFixas,
        _cell(_formatarQuantidade(t["b100"].toString()), 90, isNumber: true),
        _cell(_formatarQuantidade(t["gasolina_a"].toString()), 90, isNumber: true),
        _cell(_formatarQuantidade(t["s500_a"].toString()), 90, isNumber: true),
        _cell(_formatarQuantidade(t["s10_a"].toString()), 90, isNumber: true),
      ];
    }
  }

  Widget _cell(String texto, double largura, {bool isNumber = false}) {
    return Container(
      width: largura,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      child: Text(
        texto.isNotEmpty ? texto : '-',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade700,
          fontWeight: isNumber ? FontWeight.w600 : FontWeight.normal,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _statusCell(String statusTexto, Color corStatus) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: corStatus.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: corStatus.withOpacity(0.3), width: 1),
        ),
        child: Text(
          statusTexto,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: corStatus,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  String _formatarQuantidade(String quantidade) {
    try {
      final apenasNumeros = quantidade.replaceAll(RegExp(r'[^\d]'), '');
      if (apenasNumeros.isEmpty || apenasNumeros == '0') return '';
      
      final valor = int.parse(apenasNumeros);
      if (valor == 0) return '';
      
      if (valor > 999) {
        final parteMilhar = (valor ~/ 1000).toString();
        final parteCentena = (valor % 1000).toString().padLeft(3, '0');
        return '$parteMilhar.$parteCentena';
      }
      
      return valor.toString();
    } catch (e) {
      return quantidade;
    }
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
                  overflow: TextOverflow.ellipsis,
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