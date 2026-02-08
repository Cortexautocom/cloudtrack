import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'nova_venda.dart';
import 'dart:async';

// ==============================================================
//                PÁGINA DE PROGRAMAÇÃO DE VENDAS
// ==============================================================

class ProgramacaoPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final String? filialId;
  final String? filialNome;
  final String? filialNomeDois;

  const ProgramacaoPage({
    super.key, 
    required this.onVoltar,
    this.filialId,
    this.filialNome,
    this.filialNomeDois,
  });

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
  bool _hoverGrupo1 = false;
  bool _hoverGrupo2 = false;
  
  // Mapa para armazenar cores por ordem_id (cores fixas)
  Map<String, Color> _coresOrdens = {};
  
  // Mapa de UUID de produto -> coluna (grupo, índice)
  // Grupo 0: G. Comum, G. Aditivada, D. S10, D. S500, Etanol
  // Grupo 1: B100, G. A, S500 A, S10 A, Anidro
  static const Map<String, Map<String, dynamic>> _mapaProdutosColuna = {
    // Grupo 0 (Combustíveis derivados do petróleo)
    '82c348c8-efa1-4d1a-953a-ee384d5780fc': {'grupo': 0, 'coluna': 0}, // G. Comum
    '93686e9d-6ef5-4f7c-a97d-b058b3c2c693': {'grupo': 0, 'coluna': 1}, // G. Aditivada
    '3c26a7e5-8f3a-4429-a8c7-2e0e72f1b80a': {'grupo': 0, 'coluna': 2}, // Diesel A-S10 -> D. S10
    '58ce20cf-f252-4291-9ef6-f4821f22c29e': {'grupo': 0, 'coluna': 2}, // Diesel S10-B -> D. S10
    '4da89784-30f1-4abe-b97e-c48729969e3d': {'grupo': 0, 'coluna': 3}, // Diesel A-S500 -> D. S500
    'c77a6e31-52f0-4fe1-bdc8-685dff83f3a1': {'grupo': 0, 'coluna': 3}, // Diesel S500-B -> D. S500
    '66ca957a-5698-4a02-8c9e-987770b6a151': {'grupo': 0, 'coluna': 4}, // Hidratado -> Etanol
    'cecab8eb-297a-4640-8fae-e88335b88d8b': {'grupo': 0, 'coluna': 4}, // Anidro -> Etanol
    
    // Grupo 1 (Biocombustíveis)
    'ecd91066-e763-42e3-8a0e-d982ea6da535': {'grupo': 1, 'coluna': 0}, // B100
    'f8e95435-471a-424c-947f-def8809053a0': {'grupo': 1, 'coluna': 1}, // Gasolina A -> G. A
  };
  
  // Paleta fixa de 20 cores distintas para as ordens
  static const List<Color> _paletaCoresOrdens = [
    Color(0xFFE53935), // Vermelho vibrante
    Color(0xFF1E88E5), // Azul
    Color(0xFF43A047), // Verde
    Color(0xFFFB8C00), // Laranja
    Color(0xFF8E24AA), // Roxo
    Color(0xFF0097A7), // Ciano
    Color(0xFFF4511E), // Laranja escuro
    Color(0xFF3949AB), // Azul índigo
    Color(0xFF7CB342), // Verde claro
    Color(0xFFD81B60), // Rosa
    Color(0xFF5D4037), // Marrom
    Color(0xFF546E7A), // Azul cinza
    Color(0xFFC2185B), // Rosa escuro
    Color(0xFF00897B), // Verde água
    Color(0xFF5E35B1), // Roxo profundo
    Color(0xFF00ACC1), // Ciano claro
    Color(0xFFF57C00), // Laranja médio
    Color(0xFF303F9F), // Azul escuro
    Color(0xFF689F38), // Verde oliva
    Color(0xFFAD1457), // Magenta
  ];

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

      var query = supabase
          .from("movimentacoes")
          .select("*")
          .eq("tipo_op", "venda");

      if (widget.filialId != null && widget.filialId!.isNotEmpty) {
        query = query.eq("filial_id", widget.filialId!);
      }

      final response = await query.order('ts_mov', ascending: true);

      setState(() {
        movimentacoes = List<Map<String, dynamic>>.from(response);
        _gerarCoresParaOrdens(); // Gera cores fixas para cada ordem
      });
    } catch (e, stack) {
      debugPrint('Erro ao carregar movimentações: $e');
      debugPrint(stack.toString());

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

  // Gerar cores FIXAS para cada ordem_id
  void _gerarCoresParaOrdens() {
    _coresOrdens.clear();
    
    // Coletar todos os ordem_ids únicos
    final ordemIdsSet = <String>{};
    for (var mov in movimentacoes) {
      final ordemId = mov['ordem_id']?.toString();
      if (ordemId != null && ordemId.isNotEmpty) {
        ordemIdsSet.add(ordemId);
      }
    }
    
    // Converter para lista e ORDENAR para garantir consistência
    final listaOrdens = ordemIdsSet.toList()..sort();
    
    // Atribuir cores de forma FIXA baseada na posição ordenada
    for (var i = 0; i < listaOrdens.length; i++) {
      final ordemId = listaOrdens[i];
      // Usar índice modular para garantir cor consistente
      // Mesma ordem sempre pega a mesma cor da paleta
      final indiceCor = i % _paletaCoresOrdens.length;
      _coresOrdens[ordemId] = _paletaCoresOrdens[indiceCor];
    }
    
    debugPrint('Cores geradas para ${listaOrdens.length} ordens distintas');
  }

  // Obter cor FIXA para uma ordem específica
  Color? _obterCorParaOrdem(dynamic ordemId) {
    if (ordemId == null || ordemId.toString().isEmpty) {
      return null;
    }
    
    final idStr = ordemId.toString();
    
    // Se já temos a cor cacheada, retorna
    if (_coresOrdens.containsKey(idStr)) {
      return _coresOrdens[idStr];
    }
    
    // Se não tem (pode acontecer com filtros dinâmicos),
    // gera uma cor baseada no hash do ordem_id para consistência
    final hash = idStr.hashCode;
    final indiceCor = hash.abs() % _paletaCoresOrdens.length;
    final cor = _paletaCoresOrdens[indiceCor];
    
    // Cache para próximas vezes
    _coresOrdens[idStr] = cor;
    
    return cor;
  }

  void _mostrarDialogNovaVenda() async {
    // Verificar se filialId está definido
    if (widget.filialId == null || widget.filialId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Filial não definida. Não é possível criar nova venda.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => NovaVendaDialog(
        onSalvar: (sucesso, mensagem) {
          if (sucesso && mensagem != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(mensagem),
                backgroundColor: Colors.green,
              ),
            );
            carregar();
          } else if (mensagem != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(mensagem),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        filialId: widget.filialId!,
        filialNome: widget.filialNome,
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
      // Verifica campos de texto existentes
      if ((t['cliente']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['placa']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['forma_pagamento']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['codigo']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['uf']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['ordem_id']?.toString().toLowerCase() ?? '').contains(query)) {
        return true;
      }

      // Verifica quantidade em saida_amb
      final quantidadeFormatada = _formatarQuantidadeParaBusca(t['saida_amb']?.toString() ?? '');
      if (quantidadeFormatada.contains(query)) {
        return true;
      }
      
      final apenasNumeros = (t['saida_amb']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '');
      if (apenasNumeros.contains(query)) {
        return true;
      }

      return false;
    }).toList();
  }

  String _formatarQuantidadeParaBusca(String quantidade) {
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

  List<Map<String, dynamic>> _obterDadosFiltrados(int grupo) {
    return movimentacoes.where((l) {
      // Verifica se há quantidade em saida_amb
      final qtd = double.tryParse(l['saida_amb']?.toString() ?? '0') ?? 0;
      if (qtd <= 0) return false;
      
      // Verifica se o produto_id existe no mapa e pertence ao grupo
      final produtoId = l['produto_id']?.toString();
      if (produtoId == null) return false;
      
      final produtoInfo = _mapaProdutosColuna[produtoId];
      if (produtoInfo == null) return false;
      
      return produtoInfo['grupo'] == grupo;
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
    String tituloAppBar = "Programação de Vendas";
    if (widget.filialNomeDois != null && widget.filialNomeDois!.isNotEmpty) {
      tituloAppBar = "Programação ${widget.filialNomeDois}";
    } else if (widget.filialNome != null && widget.filialNome!.isNotEmpty) {
      tituloAppBar = "Programação ${widget.filialNome}";
    }
    
    return Scaffold(
      appBar: null,
      body: Column(
        children: [
          // AppBar personalizada FIXA
          Container(
            height: kToolbarHeight + MediaQuery.of(context).padding.top,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              left: 16, // Adiciona padding à esquerda
              right: 16, // Adiciona padding à direita
            ),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: widget.onVoltar,
                ),
                const SizedBox(width: 8), // Espaço entre botão e título
                // Título alinhado à esquerda
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft, // Alinha à esquerda
                    child: Text(
                      tituloAppBar,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis, // Trunca texto longo
                      maxLines: 1, // Mantém em uma linha
                    ),
                  ),
                ),
                // Campo de busca e botão de atualizar
                Container(
                  width: 250, // Reduzido para dar mais espaço
                  margin: const EdgeInsets.only(right: 12),
                  child: _buildSearchField(),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.black),
                  onPressed: carregar,
                  tooltip: 'Atualizar',
                ),
              ],
            ),
          ),
          // Linha divisória opcional
          Container(
            height: 1,
            color: Colors.grey.shade300,
          ),
          // Resto do conteúdo
          Expanded(
            child: carregando
                ? const Center(child: CircularProgressIndicator())
                : _buildBodyContent(),
          ),
        ],
      ),
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
    return Column(
      children: [
        // Painel fixo com controles e cabeçalho da tabela
        _buildFixedPanel(),
        
        // Corpo rolável da tabela
        Expanded(
          child: _buildScrollableTable(),
        ),
      ],
    );
  }

  Widget _buildFixedPanel() {
    return Column(
      children: [
        // Menu de navegação de grupos - FIXO
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
        
        // Contador de registros - FIXO
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
        
        // Cabeçalho da tabela - FIXO
        if (_movimentacoesFiltradas.isNotEmpty)
          _buildFixedHeader(),
      ],
    );
  }

  Widget _buildFixedHeader() {
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

  Widget _buildScrollableTable() {
    return _movimentacoesFiltradas.isEmpty
        ? _buildEmptyState()
        : Scrollbar(
            controller: _verticalScrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _verticalScrollController,
              child: Scrollbar(
                controller: _horizontalBodyController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontalBodyController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: _obterLarguraTabela(),
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
                            'g_comum', 'g_aditivada', 'd_s10', 'd_s500', 'etanol'
                          ].any((k) => (double.tryParse(t[k]?.toString() ?? '0') ?? 0) > 0);
                        } else {
                          temProduto = [
                            'b100', 'gasolina_a', 's500_a', 's10_a', 'anidro'
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

  Widget _buildGrupoButton(String texto, int grupo) {
    final bool selecionado = grupoAtual == grupo;
    bool isHovering = grupo == 0 ? _hoverGrupo1 : _hoverGrupo2;
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          if (grupo == 0) {
            _hoverGrupo1 = true;
          } else {
            _hoverGrupo2 = true;
          }
        });
      },
      onExit: (_) {
        setState(() {
          if (grupo == 0) {
            _hoverGrupo1 = false;
          } else {
            _hoverGrupo2 = false;
          }
        });
      },
      child: GestureDetector(
        onTap: () {
          setState(() {
            grupoAtual = grupo;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: selecionado 
                ? Colors.blue.shade700 
                : (isHovering ? Colors.blue.shade50 : Colors.white),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selecionado 
                  ? Colors.blue.shade700 
                  : Colors.grey.shade400,
              width: 1,
            ),
            boxShadow: isHovering && !selecionado
                ? [
                    BoxShadow(
                      color: Colors.grey.shade300,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
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
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, Map<String, dynamic> item) {
    return Container(
      width: 50,
      alignment: Alignment.center,
      child: PopupMenuButton<String>(
        itemBuilder: (BuildContext context) => [
          const PopupMenuItem<String>(
            value: 'editar_ordem',
            child: Row(
              children: [
                Icon(Icons.edit, size: 18),
                SizedBox(width: 8),
                Text('Editar ordem'),
              ],
            ),
          ),
        ],
        onSelected: (String value) {
          if (value == 'editar_ordem') {
            _editarOrdem(item);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.transparent,
          ),
          child: const Icon(
            Icons.more_vert,
            size: 20,
            color: Colors.grey,
          ),
        ),
        tooltip: 'Opções',
        offset: const Offset(0, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _editarOrdem(Map<String, dynamic> item) {
    print('Editar ordem para: ${item['id']}');
    // Aqui você pode abrir um diálogo ou navegar para outra tela
    // para editar a ordem da venda
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Editar ordem: ${item['id']}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  double _obterLarguraTabela() {
    // Adicionado 50px para a coluna do menu
    double larguraFixa = 50 + 120 + 100 + 220 + 80 + 60 + 100;
    
    if (grupoAtual == 0) {
      // Grupo 1: 5 colunas (G. Comum, G. Aditivada, D. S10, D. S500, Etanol)
      return larguraFixa + (90 * 5);
    } else {
      // Grupo 2: 5 colunas (B100, G. A, S500 A, S10 A, Anidro)
      return larguraFixa + (90 * 5);
    }
  }

  List<Widget> _obterColunasCabecalho() {
    // Adicionada coluna vazia para o menu
    final colunasFixas = [
      _th("", 50), // Coluna para o menu
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
      ];
    } else {
      return [
        ...colunasFixas,
        _th("B100", 90),
        _th("G. A", 90),
        _th("S500 A", 90),
        _th("S10 A", 90),
        _th("Anidro", 90),
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

    // Obter a cor FIXA para esta ordem
    final ordemId = t['ordem_id'];
    final corCliente = _obterCorParaOrdem(ordemId);

    // Obter informações do produto
    final produtoId = t['produto_id']?.toString();
    final produtoInfo = produtoId != null ? _mapaProdutosColuna[produtoId] : null;
    final quantidadeSaidaAmb = _formatarQuantidade(t["saida_amb"]?.toString() ?? "0");

    // Adicionado o menu como primeiro item
    final celulasFixas = [
      _buildMenuButton(context, t), // Menu de 3 pontos
      _cell(placaText, 120),
      _statusCell(statusTexto, corStatus),
      _cellCliente(t["cliente"]?.toString() ?? "", 220, corCliente), // Célula do cliente com cor FIXA
      _cell(codigo, 80),
      _cell(uf, 60),
      _cell(prazo, 100),
    ];

    // Criar lista de colunas de quantidade (5 para cada grupo)
    final List<Widget> colunasQuantidade = [];
    final numColunas = 5;
    
    for (int i = 0; i < numColunas; i++) {
      if (produtoInfo != null && produtoInfo['coluna'] == i) {
        // Esta é a coluna correta para este produto
        colunasQuantidade.add(_cell(quantidadeSaidaAmb, 90, isNumber: true));
      } else {
        // Coluna vazia
        colunasQuantidade.add(_cell("", 90, isNumber: true));
      }
    }

    return [...celulasFixas, ...colunasQuantidade];
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

  // Função específica para célula do cliente com cor FIXA
  Widget _cellCliente(String texto, double largura, Color? cor) {
    return Container(
      width: largura,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      child: Text(
        texto.isNotEmpty ? texto : '-',
        style: TextStyle(
          fontSize: 12,
          color: cor ?? Colors.grey.shade700, // Usa cor FIXA da ordem
          fontWeight: FontWeight.w600, // Deixa o nome do cliente em negrito
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