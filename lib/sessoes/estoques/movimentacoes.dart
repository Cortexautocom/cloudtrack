import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MovimentacoesPage extends StatefulWidget {
  final String filialId; // 'todas' ou uuid
  final DateTime dataInicio;
  final DateTime dataFim;
  final String produtoId; // 'todos' ou uuid
  final String tipoMov; // 'todos' | 'entrada' | 'saida'
  final String tipoOp; // 'todos' | 'venda' | 'transf'

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
  String? _produtoFiltradoNome;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalHeaderController = ScrollController();
  final ScrollController _horizontalBodyController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  
  // Dados para estoque inicial e final (sempre inicializados, mesmo zerados)
  Map<String, dynamic> _estoqueInicial = {
    'quantidade': 0,
  };
  
  Map<String, dynamic> _estoqueFinal = {
    'quantidade': 0,
  };
  
  static const Map<String, String> _produtoParaColuna = {
    // Gasolinas
    '82c348c8-efa1-4d1a-953a-ee384d5780fc': 'g_comum',       // Gasolina Comum
    '93686e9d-6ef5-4f7c-a97d-b058b3c2c693': 'g_aditivada',   // Gasolina Aditivada
    'f8e95435-471a-424c-947f-def8809053a0': 'gasolina_a',    // Gasolina A (Álcool)
    
    // Diesel
    '58ce20cf-f252-4291-9ef6-f4821f22c29e': 'd_s10',         // Diesel S10
    'c77a6e31-52f0-4fe1-bdc8-685dff83f3a1': 'd_s500',        // Diesel S500
    '3c26a7e5-8f3a-4429-a8c7-2e0e72f1b80a': 's10_a',         // S10 A
    '4da89784-301f-4abe-b97e-c48729969e3d': 's500_a',        // S500 A
    
    // Etanol
    '66ca957a-5698-4a02-8c9e-987770b6a151': 'etanol',        // Etanol
    'cecab8eb-297a-4640-81ae-e88335b88d8b': 'anidro',        // Etanol Anidro
    
    // Biodiesel
    'ecd91066-e763-42e3-8a0e-d982ea6da535': 'b100',          // Biodiesel B100
  };

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
      
      // ✅ Buscar nome do produto se houver filtro
      if (widget.produtoId != 'todos') {
        try {
          final produtoResult = await supabase
              .from('produtos')
              .select('nome')
              .eq('id', widget.produtoId)
              .maybeSingle();
              
          if (produtoResult != null && produtoResult['nome'] != null) {
            _produtoFiltradoNome = produtoResult['nome']?.toString();
          } else {
            _produtoFiltradoNome = 'Produto não encontrado';
          }
        } catch (e) {
          _produtoFiltradoNome = null;
        }
      } else {
        _produtoFiltradoNome = null;
      }

      // Carregar estoque inicial (do período anterior)
      await _carregarEstoqueInicial();

      // ✅ Incluir todos os campos específicos de produto
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

      // Calcular estoque final
      _calcularEstoqueFinal();

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

  Future<void> _carregarEstoqueInicial() async {
    try {
      if (widget.filialId == 'todas') {
        _estoqueInicial = {'quantidade': 0};
        return;
      }

      final supabase = Supabase.instance.client;
      
      // Buscar saldo anterior à data de início
      final dataAnterior = widget.dataInicio.subtract(const Duration(days: 1));
      
      var query = supabase
          .from('movimentacoes')
          .select('''
            quantidade,
            produto_id,
            tipo_op,
            filial_origem_id,
            filial_destino_id,
            tipo_mov_orig,
            tipo_mov_dest
          ''')
          .or('filial_origem_id.eq.${widget.filialId},filial_destino_id.eq.${widget.filialId}')
          .lte('data_mov', dataAnterior.toIso8601String().split('T')[0]);

      if (widget.produtoId != 'todos') {
        query = query.eq('produto_id', widget.produtoId);
      }

      final movimentacoesAnteriores = await query;

      num saldoTotal = 0;

      for (var mov in movimentacoesAnteriores) {
        if (widget.filialId != 'todas') {
          final filialUsuarioId = widget.filialId;
          final tipoOp = mov['tipo_op']?.toString().toLowerCase() ?? '';
          
          // Lógica para determinar se é entrada ou saída
          if (tipoOp == 'cacl') {
            // CACL sempre é entrada para a filial
            saldoTotal += mov['quantidade'] as num;
          } else if (mov['filial_origem_id'] == filialUsuarioId) {
            // A filial do usuário é a origem
            if (mov['tipo_mov_orig'] == 'saida') {
              saldoTotal -= mov['quantidade'] as num;
            }
          } else if (mov['filial_destino_id'] == filialUsuarioId) {
            // A filial do usuário é o destino
            if (mov['tipo_mov_dest'] == 'entrada') {
              saldoTotal += mov['quantidade'] as num;
            }
          }
        } else {
          // Para filial "todas", usar lógica simples
          saldoTotal += mov['quantidade'] as num;
        }
      }

      _estoqueInicial = {
        'quantidade': saldoTotal,
      };

    } catch (e) {
      debugPrint('Erro ao carregar estoque inicial: $e');
      _estoqueInicial = {
        'quantidade': 0,
      };
    }
  }

  void _calcularEstoqueFinal() {
    // Sempre inicia com o estoque inicial
    num saldoFinal = _estoqueInicial['quantidade'] as num;
    
    // Adiciona ou subtrai as movimentações
    for (var mov in movimentacoes) {
      if (widget.filialId != 'todas') {
        final filialUsuarioId = widget.filialId;
        final tipoOp = mov['tipo_op']?.toString().toLowerCase() ?? '';
        final quantidade = _obterQuantidadeProduto(mov) as num;
        
        // Lógica para determinar se é entrada ou saída
        if (tipoOp == 'cacl') {
          // CACL sempre é entrada para a filial
          saldoFinal += quantidade;
        } else if (mov['filial_origem_id'] == filialUsuarioId) {
          // A filial do usuário é a origem
          if (mov['tipo_mov_orig'] == 'saida') {
            saldoFinal -= quantidade;
          }
        } else if (mov['filial_destino_id'] == filialUsuarioId) {
          // A filial do usuário é o destino
          if (mov['tipo_mov_dest'] == 'entrada') {
            saldoFinal += quantidade;
          }
        }
      } else {
        // Para filial "todas", usar lógica simples
        final quantidade = _obterQuantidadeProduto(mov) as num;
        saldoFinal += quantidade;
      }
    }

    _estoqueFinal = {
      'quantidade': saldoFinal,
    };
  }

  // ✅ MODIFICADO: Função para obter a quantidade específica do produto
  int _obterQuantidadeProduto(Map<String, dynamic> movimentacao) {
    final tipoOp = movimentacao['tipo_op']?.toString().toLowerCase() ?? '';
    
    // ✅ ALTERAÇÃO PRINCIPAL: Lógica para CACL
    if (tipoOp == 'cacl') {
      // 1. Obter o produto_id da movimentação
      final produtoId = movimentacao['produto_id']?.toString() ?? '';
      
      // 2. Buscar a coluna correspondente no mapeamento
      final colunaEspecifica = _produtoParaColuna[produtoId];
      
      if (colunaEspecifica != null) {
        // 3. Ler o valor da coluna específica
        final valor = movimentacao[colunaEspecifica];
        
        // 4. Converter para int de forma segura
        if (valor != null) {
          return (valor is int) 
              ? valor 
              : int.tryParse(valor.toString()) ?? 0;
        }
      }
      
      // 5. Fallback controlado: retornar 0 se não encontrado
      return 0;
    }
    
    // ✅ MANTER LÓGICA EXISTENTE para outros tipos (venda, transf)
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
  String _formatarQuantidade(num quantidade) {
    if (quantidade == 0) return '0';
    
    bool isNegativo = quantidade < 0;
    String valorString = quantidade.abs().toStringAsFixed(0);
    
    String resultado = '';
    int contador = 0;
    
    for (int i = valorString.length - 1; i >= 0; i--) {
      contador++;
      resultado = valorString[i] + resultado;
      
      if (contador % 3 == 0 && i > 0) {
        resultado = '.$resultado';
      }
    }
    
    if (isNegativo) {
      resultado = '-$resultado';
    }
    
    return resultado;
  }

  // Função para determinar se é entrada ou saída para a filial específica
  String _obterTipoMovimentoParaFilial(Map<String, dynamic> movimentacao, String filialId) {
    final tipoOp = movimentacao['tipo_op']?.toString().toLowerCase() ?? '';
    if (tipoOp == 'cacl') {
      return 'Entrada'; // CACL sempre é entrada para a filial
    }
    
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

  // ✅ NOVA FUNÇÃO: Formatar tipo_op para exibição
  String _formatarTipoOp(String tipoOp) {
    final tipoLower = tipoOp.toLowerCase().trim();
    
    switch (tipoLower) {
      case 'transf':
        return 'Transf.';
      case 'venda':
        return 'Venda';
      case 'cacl':
        return 'CACL';
      default:
        // Se for algo não mapeado, capitaliza a primeira letra
        if (tipoOp.isNotEmpty) {
          return tipoOp[0].toUpperCase() + tipoOp.substring(1).toLowerCase();
        }
        return tipoOp;
    }
  }

  // ✅ NOVA FUNÇÃO: Título da página com produto filtrado
  String get _tituloPagina {
    if (_produtoFiltradoNome != null) {
      return 'Movimentações - $_produtoFiltradoNome';
    }
    return 'Movimentações';
  }

  // ✅ NOVA PROPRIEDADE: Larguras dinâmicas (oculta coluna Produto quando filtrado)
  List<double> get _larguras {
    if (widget.produtoId == 'todos') {
      // MOSTRA coluna Produto (7 colunas)
      return [
        90.0,   // Data
        90.0,   // Operação
        130.0,  // Produto
        350.0,  // Descrição
        90.0,   // Quantidade
        130.0,  // Origem
        130.0,  // Destino
      ];
    } else {
      // OCULTA coluna Produto (6 colunas)
      return [
        90.0,   // Data
        90.0,   // Operação
        // Produto REMOVIDO ← Índice 2 não existe
        350.0,  // Descrição (antigo índice 3 vira 2)
        90.0,   // Quantidade (antigo índice 4 vira 3)
        130.0,  // Origem (antigo índice 5 vira 4)
        130.0,  // Destino (antigo índice 6 vira 5)
      ];
    }
  }

  // ✅ NOVO MÉTODO: Calcular largura total dinamicamente
  double get _larguraTotal {
    return _larguras.reduce((a, b) => a + b);
  }

  // ✅ NOVO MÉTODO: Construir cabeçalho dinâmico
  List<Widget> _construirCabecalho() {
    final cabecalhos = <Widget>[
      _th("Data", _larguras[0]),
      _th("Operação", _larguras[1]),
    ];
    
    // Condição: Só adiciona "Produto" se estiver mostrando todos
    if (widget.produtoId == 'todos') {
      cabecalhos.add(_th("Produto", _larguras[2]));
    }
    
    // Ajustar índices: se ocultou Produto, as outras vêm uma posição antes
    final indiceBase = widget.produtoId == 'todos' ? 3 : 2;
    
    cabecalhos.addAll([
      _th("Descrição", _larguras[indiceBase]),
      _th("Quantidade", _larguras[indiceBase + 1]),
      _th("Origem", _larguras[indiceBase + 2]),
      _th("Destino", _larguras[indiceBase + 3]),
    ]);
    
    return cabecalhos;
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
        title: Text(_tituloPagina),
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

  Widget _buildTabelaConteudo() {
    final movimentacoesParaExibir = _movimentacoesFiltradas;

    return Scrollbar(
      controller: _verticalScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalScrollController,
        child: Column(
          children: [
            // CABEÇALHO (FIXO)
            Scrollbar(
              controller: _horizontalHeaderController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _horizontalHeaderController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _larguraTotal,
                  child: Container(
                    height: 40,
                    color: const Color(0xFF0D47A1),
                    child: Row(
                      children: _construirCabecalho(),
                    ),
                  ),
                ),
              ),
            ),

            // CORPO DA TABELA (SEMPRE com estoque inicial e final)
            Scrollbar(
              controller: _horizontalBodyController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _horizontalBodyController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _larguraTotal,
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: movimentacoesParaExibir.length + 2, // +2 para estoque inicial e final (SEMPRE)
                    itemBuilder: (context, index) {
                      // LINHA 1: ESTOQUE INICIAL (SEMPRE)
                      if (index == 0) {
                        final quantidadeInicial = _estoqueInicial['quantidade'] as num;
                        final quantidadeFormatada = _formatarQuantidade(quantidadeInicial);
                        
                        return Container(
                          height: 40,
                          color: Colors.blue.shade50, // Cor diferenciada
                          child: Row(
                            children: _construirLinhaEstoque(
                              data: '',
                              tipoOp: '',
                              produtoNome: '',
                              descricao: 'Estoque Inicial',
                              quantidade: quantidadeFormatada,
                              origem: '',
                              destino: '',
                              isInicial: true,
                            ),
                          ),
                        );
                      }
                      
                      // ÚLTIMA LINHA: ESTOQUE FINAL (SEMPRE)
                      if (index == movimentacoesParaExibir.length + 1) {
                        final quantidadeFinal = _estoqueFinal['quantidade'] as num;
                        final quantidadeFormatada = _formatarQuantidade(quantidadeFinal);
                        
                        return Container(
                          height: 40,
                          color: Colors.grey.shade100, // Cor diferenciada
                          child: Row(
                            children: _construirLinhaEstoque(
                              data: '',
                              tipoOp: '',
                              produtoNome: '',
                              descricao: 'Estoque Final',
                              quantidade: quantidadeFormatada,
                              origem: '',
                              destino: '',
                              isInicial: false,
                            ),
                          ),
                        );
                      }
                      
                      // LINHAS NORMAIS DAS MOVIMENTAÇÕES
                      final movIndex = index - 1; // -1 porque a primeira linha é o estoque inicial
                      final m = movimentacoesParaExibir[movIndex];
                      
                      // Obter dados da movimentação
                      final dataObj = m['data_mov'] is String
                          ? DateTime.parse(m['data_mov'])
                          : m['data_mov'];
                      final dataFormatada = '${dataObj.day.toString().padLeft(2, '0')}/${dataObj.month.toString().padLeft(2, '0')}';
                      
                      final produtoNome = m['produtos']?['nome']?.toString() ?? '';
                      final quantidade = _obterQuantidadeProduto(m);
                      final quantidadeFormatada = _formatarQuantidade(quantidade.toDouble());
                      
                      String tipoMovimento = 'N/A';
                      if (widget.filialId != 'todas') {
                        tipoMovimento = _obterTipoMovimentoParaFilial(m, widget.filialId);
                      }
                      
                      final descricaoFormatada = _obterDescricaoFormatada(m, widget.filialId);
                      final origemNome = m['origem_filial']?['nome_dois']?.toString() ?? '';
                      final destinoFormatado = _obterDestinoFormatado(m);
                      
                      Color corFundo = Colors.white;
                      if (movIndex % 2 == 0) {
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
                          children: _construirLinhaNormal(
                            data: dataFormatada,
                            tipoOp: _formatarTipoOp(m['tipo_op']?.toString() ?? ''),
                            produtoNome: produtoNome,
                            descricao: descricaoFormatada,
                            quantidade: quantidadeFormatada,
                            origem: origemNome,
                            destino: destinoFormatado,
                          ),
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
                    '${movimentacoesParaExibir.length} movimentação(ões)',
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

  // MÉTODO PARA CONSTRUIR LINHA DE ESTOQUE (INICIAL OU FINAL)
  List<Widget> _construirLinhaEstoque({
    required String data,
    required String tipoOp,
    required String produtoNome,
    required String descricao,
    required String quantidade,
    required String origem,
    required String destino,
    required bool isInicial,
  }) {
    final celulas = <Widget>[
      _cell(data, _larguras[0], isEstoque: true, isInicial: isInicial),
      _cell(tipoOp, _larguras[1], isEstoque: true, isInicial: isInicial),
    ];
    
    // Condição: Só adiciona célula "Produto" se estiver mostrando todos
    if (widget.produtoId == 'todos') {
      celulas.add(_cell(produtoNome, _larguras[2], isEstoque: true, isInicial: isInicial));
    }
    
    // Ajustar índices das colunas restantes
    final indiceBase = widget.produtoId == 'todos' ? 3 : 2;
    
    celulas.addAll([
      _cell(descricao, _larguras[indiceBase], isEstoque: true, isInicial: isInicial),
      _cell(
        quantidade,
        _larguras[indiceBase + 1],
        isEstoque: true,
        isInicial: isInicial,
        isNumber: true,
      ),
      _cell(origem, _larguras[indiceBase + 2], isEstoque: true, isInicial: isInicial),
      _cell(destino, _larguras[indiceBase + 3], isEstoque: true, isInicial: isInicial),
    ]);
    
    return celulas;
  }

  // MÉTODO PARA CONSTRUIR LINHA NORMAL (MOVIMENTAÇÕES)
  List<Widget> _construirLinhaNormal({
    required String data,
    required String tipoOp,
    required String produtoNome,
    required String descricao,
    required String quantidade,
    required String origem,
    required String destino,
  }) {
    final celulas = <Widget>[
      _cell(data, _larguras[0]),
      _cell(tipoOp, _larguras[1]),
    ];
    
    // Condição: Só adiciona célula "Produto" se estiver mostrando todos
    if (widget.produtoId == 'todos') {
      celulas.add(_cell(produtoNome, _larguras[2]));
    }
    
    // Ajustar índices das colunas restantes
    final indiceBase = widget.produtoId == 'todos' ? 3 : 2;
    
    celulas.addAll([
      _cell(descricao, _larguras[indiceBase]),
      _cell(
        quantidade,
        _larguras[indiceBase + 1],
        isNumber: true,
      ),
      _cell(origem, _larguras[indiceBase + 2]),
      _cell(destino, _larguras[indiceBase + 3]),
    ]);
    
    return celulas;
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

  Widget _cell(String texto, double largura, {
    bool isNumber = false,
    bool isEstoque = false,
    bool isInicial = false,
  }) {
    Color corTexto = Colors.grey.shade700;
    FontWeight peso = isNumber ? FontWeight.w600 : FontWeight.normal;
    
    if (isEstoque) {
      if (isInicial) {
        corTexto = Colors.blue;
      } else {
        // Para estoque final, verificar se é negativo
        if (texto.startsWith('-')) {
          corTexto = Colors.red;
        } else {
          corTexto = Colors.black;
        }
      }
      peso = FontWeight.bold;
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