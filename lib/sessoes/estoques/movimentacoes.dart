import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MovimentacoesPage extends StatefulWidget {
  final String filialId; // 'todas' ou uuid
  final DateTime dataInicio;
  final DateTime dataFim;
  final String produtoId; // 'todos' ou uuid
  final String tipoMov;   // 'todos' | 'entrada' | 'saida'
  final String tipoOp;    // 'todos' | 'venda' | 'transf'

  const MovimentacoesPage({
    super.key,
    required this.filialId,
    required this.dataInicio,
    required this.dataFim,
    required this.produtoId,
    required this.tipoMov,
    required this.tipoOp,
  });

  @override
  State<MovimentacoesPage> createState() => _MovimentacoesPageState();
}

class _MovimentacoesPageState extends State<MovimentacoesPage> {
  bool carregando = true;
  List<Map<String, dynamic>> movimentacoes = [];
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalHeaderController = ScrollController();
  final ScrollController _horizontalBodyController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    carregar();

    _horizontalHeaderController.addListener(() {
      if (_horizontalBodyController.hasClients &&
          _horizontalBodyController.offset !=
              _horizontalHeaderController.offset) {
        _horizontalBodyController
            .jumpTo(_horizontalHeaderController.offset);
      }
    });

    _horizontalBodyController.addListener(() {
      if (_horizontalHeaderController.hasClients &&
          _horizontalHeaderController.offset !=
              _horizontalBodyController.offset) {
        _horizontalHeaderController
            .jumpTo(_horizontalBodyController.offset);
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

      // SOLUÇÃO SIMPLES: Usar 'dynamic' para evitar erros de tipo
      dynamic query = supabase
          .from("movimentacoes")
          .select('''
            *,
            produtos!produto_id(nome),
            origem_filial:filiais!filial_origem_id(nome_dois),
            destino_filial:filiais!filial_destino_id(nome_dois)
          ''')
          .gte("data_mov",
              widget.dataInicio.toIso8601String().split('T')[0])
          .lte("data_mov",
              widget.dataFim.toIso8601String().split('T')[0]);

      // Aplicar filtro por filial se necessário
      if (widget.filialId != 'todas') {
        // CORREÇÃO: Remover 'referencedTable' ou usar null
        query = query.or('filial_origem_id.eq.${widget.filialId},filial_destino_id.eq.${widget.filialId}');
      }

      // Aplicar filtros adicionais
      if (widget.produtoId != 'todos') {
        query = query.eq('produto_id', widget.produtoId);
      }

      if (widget.tipoOp != 'todos') {
        query = query.eq('tipo_op', widget.tipoOp);
      }

      // Ordenar por timestamp
      query = query.order("ts_mov", ascending: true);

      final response = await query;

      List<Map<String, dynamic>> lista =
          List<Map<String, dynamic>>.from(response);

      // Filtrar localmente por tipo de movimento (entrada/saída) se necessário
      if (widget.tipoMov != 'todos' && widget.filialId != 'todas') {
        lista = lista.where((m) {
          final filialUsuarioId = widget.filialId;
          
          // Determinar se para esta filial específica é entrada ou saída
          bool isEntradaParaFilial = false;
          bool isSaidaParaFilial = false;
          
          if (m['filial_origem_id'] == filialUsuarioId) {
            // A filial do usuário é a origem
            isSaidaParaFilial = m['tipo_mov_orig'] == 'saida';
          } else if (m['filial_destino_id'] == filialUsuarioId) {
            // A filial do usuário é o destino
            isEntradaParaFilial = m['tipo_mov_dest'] == 'entrada';
          }
          
          // Aplicar o filtro
          if (widget.tipoMov == 'entrada') return isEntradaParaFilial;
          if (widget.tipoMov == 'saida') return isSaidaParaFilial;
          return true;
        }).toList();
      }

      setState(() {
        movimentacoes = lista;
      });
    } catch (e) {
      debugPrint("Erro ao carregar movimentações: $e");
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

  // Função para obter a quantidade específica do produto
  int _obterQuantidadeProduto(Map<String, dynamic> movimentacao) {
    // Lista de colunas de produtos
    final colunasProduto = [
      'g_comum',
      'g_aditivada',
      'd_s10',
      'd_s500',
      'etanol',
      'anidro',
      'b100',
      'gasolina_a',
      's500_a',
      's10_a'
    ];
    
    // Buscar a coluna que tem valor diferente de 0
    for (final coluna in colunasProduto) {
      final valor = movimentacao[coluna];
      if (valor != null && valor != 0) {
        return (valor is int) ? valor : int.tryParse(valor.toString()) ?? 0;
      }
    }
    
    // Se não encontrar, usar a quantidade geral
    return movimentacao['quantidade'] is int 
        ? movimentacao['quantidade'] 
        : int.tryParse(movimentacao['quantidade']?.toString() ?? '0') ?? 0;
  }

  // Função para formatar quantidade para "999.999"
  String _formatarQuantidade(int quantidade) {
    return quantidade.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  // Função para determinar se é entrada ou saída para a filial específica
  String _obterTipoMovimentoParaFilial(Map<String, dynamic> movimentacao, String filialId) {
    if (movimentacao['filial_origem_id'] == filialId) {
      return 'Saída';
    } else if (movimentacao['filial_destino_id'] == filialId) {
      return 'Entrada';
    }
    return 'N/A';
  }

  // Função para obter a descrição formatada
  String _obterDescricaoFormatada(Map<String, dynamic> movimentacao, String filialId) {
    final origemNome = movimentacao['origem_filial']?['nome_dois']?.toString() ?? '';
    final destinoNome = movimentacao['destino_filial']?['nome_dois']?.toString() ?? '';
    final descricao = movimentacao['descricao']?.toString() ?? '';
    
    // Se for transferência
    if (movimentacao['tipo_op'] == 'Transf') {
      if (movimentacao['filial_origem_id'] == filialId) {
        return 'Transferência para $destinoNome';
      } else if (movimentacao['filial_destino_id'] == filialId) {
        return 'Transferência de $origemNome';
      }
    }
    
    // Para outros tipos (venda, etc.)
    return descricao;
  }

  // Função para obter o destino formatado
  String _obterDestinoFormatado(Map<String, dynamic> movimentacao) {
    final tipoOp = movimentacao['tipo_op']?.toString().toLowerCase() ?? '';
    
    // Se for venda, mostrar o nome do cliente
    if (tipoOp == 'venda' || tipoOp.contains('venda')) {
      final cliente = movimentacao['cliente']?.toString();
      if (cliente != null && cliente.isNotEmpty) {
        return cliente;
      }
    }
    
    // Para outros casos, mostrar o nome da filial destino
    final destinoNome = movimentacao['destino_filial']?['nome_dois']?.toString() ?? '';
    return destinoNome;
  }

  List<Map<String, dynamic>> get _movimentacoesFiltradas {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) return movimentacoes;

    return movimentacoes.where((m) {
      return (m['descricao']?.toString().toLowerCase() ?? '')
              .contains(query) ||
          (m['data_mov']?.toString().toLowerCase() ?? '')
              .contains(query) ||
          (m['quantidade']?.toString().toLowerCase() ?? '')
              .contains(query) ||
          (m['produtos']?['nome']?.toString().toLowerCase() ?? '')
              .contains(query) ||
          (m['origem_filial']?['nome_dois']?.toString().toLowerCase() ?? '')
              .contains(query) ||
          (m['destino_filial']?['nome_dois']?.toString().toLowerCase() ?? '')
              .contains(query) ||
          (m['cliente']?.toString().toLowerCase() ?? '').contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Movimentações"),
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
          : _movimentacoesFiltradas.isEmpty
              ? _buildVazio()
              : _buildTabelaConteudo(),
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
              icon: Icon(Icons.clear,
                  color: Colors.grey.shade600, size: 20),
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

  Widget _buildVazio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Nenhuma movimentação encontrada',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          if (widget.filialId != 'todas')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Filtro aplicado: ${widget.tipoMov != 'todos' ? widget.tipoMov : ''} '
                '${widget.tipoOp != 'todos' ? widget.tipoOp : ''}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabelaConteudo() {
    // Usar List<double> para evitar erro de tipo
    // REMOVIDA a coluna 'Tipo' (índice 1)
    final List<double> larguras = [
      90.0,   // Data
      90.0,   // Operação (antigo índice 2)
      130.0,  // Produto (antigo índice 3)
      350.0,  // Descrição (antigo índice 4)
      90.0,   // Quantidade (antigo índice 5)
      130.0,  // Origem (antigo índice 6)
      130.0,  // Destino (antigo índice 7)
    ];
    
    final larguraTotal = larguras.reduce((a, b) => a + b); // 830.0 pixels

    return Scrollbar(
      controller: _verticalScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalScrollController,
        child: Column(
          children: [
            // CABEÇALHO
            Scrollbar(
              controller: _horizontalHeaderController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _horizontalHeaderController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: larguraTotal,
                  child: Container(
                    height: 40,
                    color: const Color(0xFF0D47A1),
                    child: Row(
                      children: [
                        _th("Data", larguras[0]),
                        _th("Operação", larguras[1]),
                        _th("Produto", larguras[2]),
                        _th("Descrição", larguras[3]),
                        _th("Quantidade", larguras[4]),
                        _th("Origem", larguras[5]),
                        _th("Destino", larguras[6]),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // CORPO
            Scrollbar(
              controller: _horizontalBodyController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _horizontalBodyController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: larguraTotal,
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _movimentacoesFiltradas.length,
                    itemBuilder: (context, index) {
                      final m = _movimentacoesFiltradas[index];
                      final data = m['data_mov'] is String
                          ? DateTime.parse(m['data_mov'])
                          : m['data_mov'];
                      final produtoNome = m['produtos']?['nome']?.toString() ?? '';
                      final quantidade = _obterQuantidadeProduto(m);
                      final quantidadeFormatada = _formatarQuantidade(quantidade);
                      
                      String tipoMovimento = 'N/A';
                      if (widget.filialId != 'todas') {
                        tipoMovimento = _obterTipoMovimentoParaFilial(m, widget.filialId);
                      }
                      
                      final descricaoFormatada = _obterDescricaoFormatada(m, widget.filialId);
                      final origemNome = m['origem_filial']?['nome_dois']?.toString() ?? '';
                      final destinoFormatado = _obterDestinoFormatado(m);
                      
                      Color corFundo = Colors.white;
                      if (index % 2 == 0) {
                        corFundo = Colors.grey.shade50;
                      }
                      
                      if (tipoMovimento == 'Entrada') {
                        corFundo = Colors.green.shade50;
                      } else if (tipoMovimento == 'Saída') {
                        corFundo = Colors.red.shade50;
                      }

                      return Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: corFundo,
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.shade200,
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            _cell(
                              '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}',
                              larguras[0],
                            ),
                            _cell(m['tipo_op']?.toString() ?? '', larguras[1]),
                            _cell(produtoNome, larguras[2]),
                            _cell(descricaoFormatada, larguras[3]),
                            _cell(
                              quantidadeFormatada,
                              larguras[4],
                              isNumber: true,
                            ),
                            _cell(origemNome, larguras[5]),
                            _cell(destinoFormatado, larguras[6]),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // CONTADOR
            Container(
              height: 32,
              color: Colors.grey.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_movimentacoesFiltradas.length} movimentação(ões)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (widget.filialId != 'todas')
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            border: Border.all(color: Colors.green.shade300),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Text(
                          'Entrada',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            border: Border.all(color: Colors.red.shade300),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Text(
                          'Saída',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
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
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _cell(String texto, double largura,
      {bool isNumber = false, bool isEntrada = false, bool isSaida = false}) {
    Color corTexto = Colors.grey.shade700;
    FontWeight peso = isNumber ? FontWeight.w600 : FontWeight.normal;
    
    if (isEntrada) {
      corTexto = Colors.green.shade800;
      peso = FontWeight.w600;
    } else if (isSaida) {
      corTexto = Colors.red.shade800;
      peso = FontWeight.w600;
    }

    return Container(
      width: largura,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: isNumber ? Alignment.centerRight : Alignment.center,
      child: Text(
        texto.isNotEmpty ? texto : '-',
        style: TextStyle(
          fontSize: 12,
          color: corTexto,
          fontWeight: peso,
        ),
        textAlign: isNumber ? TextAlign.right : TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}