import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EstoqueMesPage extends StatefulWidget {
  final String filialId;
  final String nomeFilial;
  final String? empresaId;
  final DateTime? mesFiltro;
  final String? produtoFiltro; // Agora recebe ID do produto ou 'todos'

  const EstoqueMesPage({
    super.key,
    required this.filialId,
    required this.nomeFilial,
    this.empresaId,
    this.mesFiltro,
    this.produtoFiltro,
  });

  @override
  State<EstoqueMesPage> createState() => _EstoqueMesPageState();
}

class _EstoqueMesPageState extends State<EstoqueMesPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _estoques = [];
  List<Map<String, dynamic>> _estoquesOrdenados = [];
  String? _empresaId;
  bool _carregando = true;
  bool _erro = false;
  String _mensagemErro = '';
  String? _nomeProdutoSelecionado;
  
  // Variáveis para ordenação
  String _colunaOrdenacao = 'data_mov';
  bool _ordenacaoAscendente = false; // false = mais recente primeiro

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() {
      _carregando = true;
      _erro = false;
    });

    try {
      // Se empresaId não foi passado, buscar da filial
      if (widget.empresaId == null) {
        final filialData = await _supabase
            .from('filiais')
            .select('empresa_id')
            .eq('id', widget.filialId)
            .single();

        _empresaId = filialData['empresa_id']?.toString();
      } else {
        _empresaId = widget.empresaId;
      }

      if (_empresaId == null || _empresaId!.isEmpty) {
        throw Exception('Não foi possível identificar a empresa da filial');
      }

      // Buscar nome do produto se não for "todos"
      if (widget.produtoFiltro != null && widget.produtoFiltro != 'todos') {
        final produtoData = await _supabase
            .from('produtos')
            .select('nome')
            .eq('id', widget.produtoFiltro!)
            .maybeSingle();
        
        _nomeProdutoSelecionado = produtoData?['nome']?.toString();
      }

      // CONSTRUIR QUERY COM FILTROS
      var query = _supabase
          .from('estoques')
          .select('''
            id,
            data_mov,
            descricao,
            entrada_amb,
            entrada_vinte,
            saida_amb,
            saida_vinte,
            created_at,
            produto_id,
            produtos!inner(
              id,
              nome
            )
          ''')
          .eq('filial_id', widget.filialId)
          .eq('empresa_id', _empresaId!);

      // APLICAR FILTRO DE MÊS
      if (widget.mesFiltro != null) {
        final primeiroDia = DateTime(widget.mesFiltro!.year, widget.mesFiltro!.month, 1);
        final ultimoDia = DateTime(widget.mesFiltro!.year, widget.mesFiltro!.month + 1, 0);
        
        query = query
            .gte('data_mov', primeiroDia.toIso8601String())
            .lte('data_mov', ultimoDia.toIso8601String());
      }

      // APLICAR FILTRO DE PRODUTO
      if (widget.produtoFiltro != null && widget.produtoFiltro != 'todos') {
        query = query.eq('produto_id', widget.produtoFiltro!);
      }

      // Ordenar por data_mov ASC para cálculo
      final dados = await query.order('data_mov', ascending: true);

      // Calcular saldos acumulados
      List<Map<String, dynamic>> estoquesComSaldo = [];
      num saldoAmbAcumulado = 0;
      num saldoVinteAcumulado = 0;

      for (var item in dados) {
        final entradaAmb = item['entrada_amb'] ?? 0;
        final entradaVinte = item['entrada_vinte'] ?? 0;
        final saidaAmb = item['saida_amb'] ?? 0;
        final saidaVinte = item['saida_vinte'] ?? 0;
        
        // Extrair nome do produto do relacionamento
        final produto = item['produtos'] as Map<String, dynamic>?;
        final produtoNome = produto?['nome']?.toString() ?? '';

        saldoAmbAcumulado += entradaAmb - saidaAmb;
        saldoVinteAcumulado += entradaVinte - saidaVinte;

        estoquesComSaldo.add({
          ...item,
          'produto_nome': produtoNome,
          'produto_id': item['produto_id'],
          'saldo_amb': saldoAmbAcumulado,
          'saldo_vinte': saldoVinteAcumulado,
        });
      }

      // Ordenar inicialmente pela data (mais recente primeiro)
      _ordenarDados(estoquesComSaldo, 'data_mov', false);
    } catch (e) {
      debugPrint('❌ Erro ao carregar estoques: $e');
      setState(() {
        _carregando = false;
        _erro = true;
        _mensagemErro = e.toString();
      });
    }
  }

  void _ordenarDados(
    List<Map<String, dynamic>> dados, 
    String coluna, 
    bool ascendente
  ) {
    List<Map<String, dynamic>> dadosOrdenados = List.from(dados);
    
    dadosOrdenados.sort((a, b) {
      dynamic valorA;
      dynamic valorB;
      
      switch (coluna) {
        case 'data_mov':
          valorA = DateTime.parse(a['data_mov']);
          valorB = DateTime.parse(b['data_mov']);
          break;
        case 'descricao':
          valorA = (a['descricao'] ?? '').toString().toLowerCase();
          valorB = (b['descricao'] ?? '').toString().toLowerCase();
          break;
        case 'produto_nome':
          valorA = (a['produto_nome'] ?? '').toString().toLowerCase();
          valorB = (b['produto_nome'] ?? '').toString().toLowerCase();
          break;
        case 'entrada_amb':
        case 'entrada_vinte':
        case 'saida_amb':
        case 'saida_vinte':
        case 'saldo_amb':
        case 'saldo_vinte':
          valorA = a[coluna] ?? 0;
          valorB = b[coluna] ?? 0;
          break;
        default:
          return 0;
      }
      
      // Comparação
      if (valorA is DateTime && valorB is DateTime) {
        return ascendente 
            ? valorA.compareTo(valorB)
            : valorB.compareTo(valorA);
      } else if (valorA is num && valorB is num) {
        return ascendente 
            ? (valorA - valorB).toInt()
            : (valorB - valorA).toInt();
      } else if (valorA is String && valorB is String) {
        return ascendente 
            ? valorA.compareTo(valorB)
            : valorB.compareTo(valorA);
      }
      
      return 0;
    });
    
    setState(() {
      _estoques = dados;
      _estoquesOrdenados = dadosOrdenados;
      _colunaOrdenacao = coluna;
      _ordenacaoAscendente = ascendente;
      _carregando = false;
    });
  }

  void _onSort(String coluna) {
    bool ascendente = true;
    
    if (_colunaOrdenacao == coluna) {
      ascendente = !_ordenacaoAscendente;
    } else {
      ascendente = coluna == 'data_mov' ? false : true; // Data: mais recente primeiro por padrão
    }
    
    _ordenarDados(_estoques, coluna, ascendente);
  }

  String _getSubtitleFiltros() {
    List<String> filtros = [];
    
    if (widget.mesFiltro != null) {
      filtros.add('Mês: ${widget.mesFiltro!.month.toString().padLeft(2, '0')}/${widget.mesFiltro!.year}');
    }
    
    if (widget.produtoFiltro != null && widget.produtoFiltro != 'todos') {
      filtros.add('Produto: ${_nomeProdutoSelecionado ?? widget.produtoFiltro}');
    } else if (widget.produtoFiltro == 'todos') {
      filtros.add('Produto: Todos os produtos');
    }
    
    return filtros.join(' | ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D47A1),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estoque mensal – ${widget.nomeFilial}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.mesFiltro != null || widget.produtoFiltro != null)
              Text(
                _getSubtitleFiltros(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Botão para alterar filtros
          if (!_carregando && (widget.mesFiltro != null || widget.produtoFiltro != null))
            IconButton(
              icon: const Icon(Icons.filter_alt),
              tooltip: 'Alterar filtros',
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          if (!_carregando && !_erro && _estoques.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              tooltip: 'Ordenar por',
              onSelected: (value) {
                _onSort(value);
              },
              itemBuilder: (context) {
                return [
                  PopupMenuItem<String>(
                    value: 'data_mov',
                    child: Text(_ordenacaoAscendente && _colunaOrdenacao == 'data_mov' 
                      ? 'Data (mais antigo primeiro)' 
                      : 'Data (mais recente primeiro)'),
                  ),
                  if (widget.produtoFiltro == null || widget.produtoFiltro == 'todos')
                    PopupMenuItem<String>(
                      value: 'produto_nome',
                      child: Text(_ordenacaoAscendente && _colunaOrdenacao == 'produto_nome'
                        ? 'Produto (Z-A)'
                        : 'Produto (A-Z)'),
                    ),
                  PopupMenuItem<String>(
                    value: 'entrada_amb',
                    child: Text(_ordenacaoAscendente && _colunaOrdenacao == 'entrada_amb'
                      ? 'Entrada Ambiente (menor-maior)'
                      : 'Entrada Ambiente (maior-menor)'),
                  ),
                  PopupMenuItem<String>(
                    value: 'saldo_amb',
                    child: Text(_ordenacaoAscendente && _colunaOrdenacao == 'saldo_amb'
                      ? 'Saldo Ambiente (menor-maior)'
                      : 'Saldo Ambiente (maior-menor)'),
                  ),
                ];
              },
            ),
          if (!_carregando && !_erro)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _carregarDados,
              tooltip: 'Atualizar dados',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _carregando
            ? _buildCarregando()
            : _erro
                ? _buildErro()
                : _estoques.isEmpty
                    ? _buildSemDados()
                    : Column(
                        children: [
                          // Indicador de filtros ativos
                          if (widget.mesFiltro != null || widget.produtoFiltro != null)
                            _buildIndicadorFiltros(),
                          const SizedBox(height: 16),
                          Expanded(child: _buildTabela()),
                        ],
                      ),
      ),
    );
  }

  Widget _buildIndicadorFiltros() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF0D47A1).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt, color: Color(0xFF0D47A1), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _getSubtitleFiltros(),
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF0D47A1),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Alterar',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF0D47A1),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarregando() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF0D47A1)),
          SizedBox(height: 20),
          Text(
            'Carregando dados do estoque...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 60,
          ),
          const SizedBox(height: 20),
          const Text(
            'Erro ao carregar dados',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _mensagemErro,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _carregarDados,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildSemDados() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            color: Colors.grey,
            size: 60,
          ),
          const SizedBox(height: 20),
          const Text(
            'Nenhum registro encontrado',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.mesFiltro != null || widget.produtoFiltro != null
                ? 'Não há movimentações de estoque para os filtros aplicados.'
                : 'Não há movimentações de estoque para esta filial.',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _carregarDados,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Atualizar'),
          ),
          // Botão para remover filtros se houver algum ativo
          if (widget.mesFiltro != null || widget.produtoFiltro != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'Alterar filtros',
                  style: TextStyle(color: Color(0xFF0D47A1)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabela() {
    // Adicionar coluna de produto se não estiver filtrado por produto específico
    bool mostrarColunaProduto = widget.produtoFiltro == null || widget.produtoFiltro == 'todos';
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(
          sortColumnIndex: _getSortColumnIndex(mostrarColunaProduto),
          sortAscending: _ordenacaoAscendente,
          headingRowHeight: 48,
          dataRowHeight: 44,
          columnSpacing: 24,
          headingRowColor: MaterialStateProperty.all(
            Colors.grey.shade100,
          ),
          columns: [
            DataColumn(
              label: const Text(
                'Data',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onSort: (columnIndex, ascending) {
                _onSort('data_mov');
              },
            ),
            if (mostrarColunaProduto)
              DataColumn(
                label: const Text(
                  'Produto',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onSort: (columnIndex, ascending) {
                  _onSort('produto_nome');
                },
              ),
            DataColumn(
              label: const Text(
                'Descrição',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onSort: (columnIndex, ascending) {
                _onSort('descricao');
              },
            ),
            DataColumn(
              label: const Text(
                'Entrada (Amb.)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              numeric: true,
              onSort: (columnIndex, ascending) {
                _onSort('entrada_amb');
              },
            ),
            DataColumn(
              label: const Text(
                'Entrada (20ºC)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              numeric: true,
              onSort: (columnIndex, ascending) {
                _onSort('entrada_vinte');
              },
            ),
            DataColumn(
              label: const Text(
                'Saída (Amb.)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              numeric: true,
              onSort: (columnIndex, ascending) {
                _onSort('saida_amb');
              },
            ),
            DataColumn(
              label: const Text(
                'Saída (20ºC)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              numeric: true,
              onSort: (columnIndex, ascending) {
                _onSort('saida_vinte');
              },
            ),
            DataColumn(
              label: const Text(
                'Saldo (Amb.)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              numeric: true,
              onSort: (columnIndex, ascending) {
                _onSort('saldo_amb');
              },
            ),
            DataColumn(
              label: const Text(
                'Saldo (20ºC)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              numeric: true,
              onSort: (columnIndex, ascending) {
                _onSort('saldo_vinte');
              },
            ),
          ],
          rows: _estoquesOrdenados.map((estoque) {
            final dataMov = estoque['data_mov']?.toString() ?? '';
            final produtoNome = estoque['produto_nome']?.toString() ?? '';
            final descricao = estoque['descricao']?.toString() ?? '';
            final entradaAmb = estoque['entrada_amb'] ?? 0;
            final entradaVinte = estoque['entrada_vinte'] ?? 0;
            final saidaAmb = estoque['saida_amb'] ?? 0;
            final saidaVinte = estoque['saida_vinte'] ?? 0;
            final saldoAmb = estoque['saldo_amb'] ?? 0;
            final saldoVinte = estoque['saldo_vinte'] ?? 0;

            return DataRow(
              cells: [
                DataCell(_buildCelulaSelecionavel(
                  _formatarData(dataMov),
                )),
                if (mostrarColunaProduto)
                  DataCell(_buildCelulaSelecionavel(
                    produtoNome.isNotEmpty ? produtoNome : '-',
                    maxLines: 1,
                  )),
                DataCell(_buildCelulaSelecionavel(
                  descricao.isNotEmpty ? descricao : '-',
                  maxLines: 2,
                )),
                DataCell(_buildCelulaSelecionavel(
                  entradaAmb.toStringAsFixed(0),
                  cor: Colors.black,
                  alinhamento: Alignment.centerRight,
                )),
                DataCell(_buildCelulaSelecionavel(
                  entradaVinte.toStringAsFixed(0),
                  cor: Colors.black,
                  alinhamento: Alignment.centerRight,
                )),
                DataCell(_buildCelulaSelecionavel(
                  saidaAmb.toStringAsFixed(0),
                  cor: Colors.black,
                  alinhamento: Alignment.centerRight,
                )),
                DataCell(_buildCelulaSelecionavel(
                  saidaVinte.toStringAsFixed(0),
                  cor: Colors.black,
                  alinhamento: Alignment.centerRight,
                )),
                DataCell(_buildCelulaSelecionavel(
                  saldoAmb.toStringAsFixed(0),
                  cor: saldoAmb >= 0 ? Colors.green : Colors.red,
                  alinhamento: Alignment.centerRight,
                  fontWeight: FontWeight.w600,
                )),
                DataCell(_buildCelulaSelecionavel(
                  saldoVinte.toStringAsFixed(0),
                  cor: saldoVinte >= 0 ? Colors.green : Colors.red,
                  alinhamento: Alignment.centerRight,
                  fontWeight: FontWeight.w600,
                )),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCelulaSelecionavel(
    String texto, {
    Color cor = Colors.black,
    AlignmentGeometry alinhamento = Alignment.centerLeft,
    FontWeight fontWeight = FontWeight.normal,
    int maxLines = 1,
  }) {
    return Align(
      alignment: alinhamento,
      child: SelectableText(
        texto,
        style: TextStyle(
          fontSize: 13,
          color: cor,
          fontWeight: fontWeight,
        ),
        maxLines: maxLines,
      ),
    );
  }

  int? _getSortColumnIndex(bool mostrarColunaProduto) {
    switch (_colunaOrdenacao) {
      case 'data_mov':
        return 0;
      case 'produto_nome':
        return mostrarColunaProduto ? 1 : null;
      case 'descricao':
        return mostrarColunaProduto ? 2 : 1;
      case 'entrada_amb':
        return mostrarColunaProduto ? 3 : 2;
      case 'entrada_vinte':
        return mostrarColunaProduto ? 4 : 3;
      case 'saida_amb':
        return mostrarColunaProduto ? 5 : 4;
      case 'saida_vinte':
        return mostrarColunaProduto ? 6 : 5;
      case 'saldo_amb':
        return mostrarColunaProduto ? 7 : 6;
      case 'saldo_vinte':
        return mostrarColunaProduto ? 8 : 7;
      default:
        return 0;
    }
  }
  
  String _formatarData(String dataString) {
    try {
      final data = DateTime.parse(dataString);
      return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
    } catch (e) {
      return dataString;
    }
  }
}