import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EstoqueProdutoPage extends StatefulWidget {
  final String? filialId;
  final String? terminalId;
  final String nomeFilial;
  final String? empresaId;
  final DateTime? dataFiltro;
  final String produtoId;
  final String produtoNome;
  final bool isIntraday;

  const EstoqueProdutoPage({
    super.key,
    this.filialId,
    this.terminalId,
    required this.nomeFilial,
    this.empresaId,
    this.dataFiltro,
    required this.produtoId,
    required this.produtoNome,
    this.isIntraday = true,
  });

  @override
  State<EstoqueProdutoPage> createState() => _EstoqueProdutoPageState();
}

class _EstoqueProdutoPageState extends State<EstoqueProdutoPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _movimentacoes = [];
  List<Map<String, dynamic>> _movimentacoesOrdenadas = [];
  String? _filialIdUsar;
  String? _empresaId;
  bool _carregando = true;
  bool _erro = false;
  String _mensagemErro = '';

  // Estoque na data selecionada
  Map<String, dynamic> _estoqueAtual = {
    'ambiente': 0,
    'vinte_graus': 0,
  };

  // ScrollControllers
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalHeaderController = ScrollController();
  final ScrollController _horizontalBodyController = ScrollController();

  // Constantes de layout
  static const double _alturaCabecalho = 40;
  static const double _alturaLinha = 40;
  static const double _alturaRodape = 32;

  // Larguras das colunas
  static const double _larguraData = 120;
  static const double _larguraDescricao = 240;
  static const double _larguraClienteDestino = 160;
  static const double _larguraNumerica = 120;

  // Coluna de ordenação
  String _colunaOrdenacao = 'data_mov';
  bool _ordenacaoAscendente = true;

  // Getter para largura total
  double get _larguraTabela {
    return _larguraData + 
           _larguraDescricao + 
           _larguraClienteDestino +
           (_larguraNumerica * 5); // Entrada Amb, Entrada 20ºC, Saída Amb, Saída 20ºC, Saldo
  }

  @override
  void initState() {
    super.initState();
    _setupScrollControllers();
    _carregarDados();
  }

  void _setupScrollControllers() {
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

  Future<void> _carregarDados() async {
    setState(() {
      _carregando = true;
      _erro = false;
    });

    try {
      // Resolver filial e empresa
      if (widget.filialId != null && widget.filialId!.isNotEmpty) {
        _filialIdUsar = widget.filialId;
        
        if (widget.empresaId != null && widget.empresaId!.isNotEmpty) {
          _empresaId = widget.empresaId;
        } else {
          final filialData = await _supabase
              .from('filiais')
              .select('empresa_id')
              .eq('id', _filialIdUsar!)
              .maybeSingle();
          _empresaId = filialData?['empresa_id']?.toString();
        }
      } else if (widget.terminalId != null) {
        final filialData = await _supabase
            .from('filiais')
            .select('id, empresa_id')
            .or('terminal_id_1.eq.${widget.terminalId!},terminal_id_2.eq.${widget.terminalId!}')
            .maybeSingle();

        if (filialData != null) {
          _filialIdUsar = filialData['id']?.toString();
          _empresaId = filialData['empresa_id']?.toString();
        }
      }

      if (_filialIdUsar == null || _filialIdUsar!.isEmpty) {
        throw Exception('Não foi possível identificar a filial');
      }

      if (_empresaId == null || _empresaId!.isEmpty) {
        throw Exception('Não foi possível identificar a empresa');
      }

      // Calcular estoque até a data selecionada
      await _calcularEstoqueAteData();

      // Carregar movimentações
      await _carregarMovimentacoes();

      setState(() {
        _carregando = false;
      });

    } catch (e) {
      debugPrint('❌ Erro ao carregar dados: $e');
      setState(() {
        _carregando = false;
        _erro = true;
        _mensagemErro = e.toString();
      });
    }
  }

  Future<void> _calcularEstoqueAteData() async {
    try {
      if (widget.dataFiltro == null) return;

      // Buscar todas as movimentações até a data selecionada (inclusive)
      final movimentacoes = await _supabase
          .from('movimentacoes')
          .select('''
            entrada_amb,
            entrada_vinte,
            saida_amb,
            saida_vinte,
            tipo_op,
            filial_destino_id,
            filial_origem_id,
            tipo_mov_dest,
            tipo_mov_orig
          ''')
          .or('filial_id.eq.$_filialIdUsar,filial_destino_id.eq.$_filialIdUsar,filial_origem_id.eq.$_filialIdUsar')
          .eq('empresa_id', _empresaId!)
          .eq('produto_id', widget.produtoId)
          .lte('data_mov', widget.dataFiltro!.toIso8601String().split('T')[0]);

      num saldoAmb = 0;
      num saldoVinte = 0;

      for (var mov in movimentacoes) {
        final normalizado = _normalizarMovimentacao(mov, _filialIdUsar!);
        saldoAmb += (normalizado['entrada_amb'] as num) - (normalizado['saida_amb'] as num);
        saldoVinte += (normalizado['entrada_vinte'] as num) - (normalizado['saida_vinte'] as num);
      }

      _estoqueAtual = {
        'ambiente': saldoAmb,
        'vinte_graus': saldoVinte,
      };

    } catch (e) {
      debugPrint('Erro ao calcular estoque: $e');
      _estoqueAtual = {'ambiente': 0, 'vinte_graus': 0};
    }
  }

  Map<String, dynamic> _normalizarMovimentacao(Map<String, dynamic> mov, String filialId) {
    num entradaAmb = 0;
    num entradaVinte = 0;
    num saidaAmb = 0;
    num saidaVinte = 0;

    final tipoOp = mov['tipo_op']?.toString() ?? '';
    final filialDestinoId = mov['filial_destino_id']?.toString();
    final filialOrigemId = mov['filial_origem_id']?.toString();
    final tipoMovDest = mov['tipo_mov_dest']?.toString();
    final tipoMovOrig = mov['tipo_mov_orig']?.toString();

    switch (tipoOp) {
      case 'transf':
        if (filialDestinoId == filialId && tipoMovDest == 'entrada') {
          entradaAmb += (mov['entrada_amb'] ?? 0) as num;
          entradaVinte += (mov['entrada_vinte'] ?? 0) as num;
        } else if (filialOrigemId == filialId && tipoMovOrig == 'saida') {
          saidaAmb += (mov['saida_amb'] ?? 0) as num;
          saidaVinte += (mov['saida_vinte'] ?? 0) as num;
        }
        break;

      case 'venda':
        saidaAmb += (mov['saida_amb'] ?? 0) as num;
        saidaVinte += (mov['saida_vinte'] ?? 0) as num;
        break;

      default:
        entradaAmb += (mov['entrada_amb'] ?? 0) as num;
        entradaVinte += (mov['entrada_vinte'] ?? 0) as num;
        saidaAmb += (mov['saida_amb'] ?? 0) as num;
        saidaVinte += (mov['saida_vinte'] ?? 0) as num;
        break;
    }

    return {
      'entrada_amb': entradaAmb,
      'entrada_vinte': entradaVinte,
      'saida_amb': saidaAmb,
      'saida_vinte': saidaVinte,
    };
  }

  Future<void> _carregarMovimentacoes() async {
    try {
      if (widget.dataFiltro == null) return;

      // Definir intervalo de datas
      final dataInicio = DateTime(
        widget.dataFiltro!.year,
        widget.dataFiltro!.month,
        widget.dataFiltro!.day,
        0, 0, 0, 0,
      );
      
      final dataFim = DateTime(
        widget.dataFiltro!.year,
        widget.dataFiltro!.month,
        widget.dataFiltro!.day,
        23, 59, 59, 999,
      );

      // Buscar movimentações do dia
      final dados = await _supabase
          .from('movimentacoes')
          .select('''
            id,
            data_mov,
            ts_mov,
            descricao,
            cliente,
            entrada_amb,
            entrada_vinte,
            saida_amb,
            saida_vinte,
            tipo_op,
            tipo_mov_orig,
            tipo_mov_dest,
            filial_id,
            filial_destino_id,
            filial_origem_id
          ''')
          .or('filial_id.eq.$_filialIdUsar,filial_destino_id.eq.$_filialIdUsar,filial_origem_id.eq.$_filialIdUsar')
          .eq('empresa_id', _empresaId!)
          .eq('produto_id', widget.produtoId)
          .gte('data_mov', dataInicio.toIso8601String())
          .lte('data_mov', dataFim.toIso8601String())
          .order('ts_mov', ascending: true);

      // Coletar IDs de filiais destino
      final Set<String> filialDestinoIds = {};
      for (var mov in dados) {
        if ((mov['tipo_op']?.toString() ?? '') == 'transf' && mov['filial_destino_id'] != null) {
          filialDestinoIds.add(mov['filial_destino_id'].toString());
        }
      }

      // Buscar nomes das filiais
      final Map<String, String> filialNomes = {};
      if (filialDestinoIds.isNotEmpty) {
        try {
          final orExpr = filialDestinoIds.map((id) => 'id.eq.$id').join(',');
          final filiaisRes = await _supabase
              .from('filiais')
              .select('id, nome_dois')
              .or(orExpr);

          for (var f in filiaisRes) {
            filialNomes[f['id'].toString()] = f['nome_dois']?.toString() ?? '';
          }
        } catch (e) {
          debugPrint('Erro ao buscar nomes das filiais: $e');
        }
      }

      // Processar movimentações
      final List<Map<String, dynamic>> processadas = [];
      
      // Começar com estoque acumulado até o início do dia
      num saldoAmbAcumulado = _estoqueAtual['ambiente'] as num;
      num saldoVinteAcumulado = _estoqueAtual['vinte_graus'] as num;

      for (var mov in dados) {
        final normalizado = _normalizarMovimentacao(mov, _filialIdUsar!);

        // Atualizar saldos
        saldoAmbAcumulado += (normalizado['entrada_amb'] as num) - (normalizado['saida_amb'] as num);
        saldoVinteAcumulado += (normalizado['entrada_vinte'] as num) - (normalizado['saida_vinte'] as num);

        processadas.add({
          ...normalizado,
          'id': mov['id'],
          'data_mov': mov['data_mov'],
          'descricao': mov['descricao'] ?? '',
          'cliente_destino': (() {
            final tipoOpMov = mov['tipo_op']?.toString() ?? '';
            if (tipoOpMov == 'venda') {
              return mov['cliente']?.toString() ?? '';
            } else if (tipoOpMov == 'transf') {
              final fd = mov['filial_destino_id']?.toString();
              return filialNomes[fd] ?? fd ?? '';
            }
            return mov['cliente']?.toString() ?? mov['filial_destino_id']?.toString() ?? '';
          })(),
          'saldo_amb': saldoAmbAcumulado,
          'saldo_vinte': saldoVinteAcumulado,
        });
      }

      setState(() {
        _movimentacoes = processadas;
        _movimentacoesOrdenadas = List.from(processadas);
      });

    } catch (e) {
      debugPrint('Erro ao carregar movimentações: $e');
      rethrow;
    }
  }

  void _ordenarDados(List<Map<String, dynamic>> dados, String coluna, bool ascendente) {
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
        case 'cliente_destino':
          valorA = (a['cliente_destino'] ?? '').toString().toLowerCase();
          valorB = (b['cliente_destino'] ?? '').toString().toLowerCase();
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
      
      if (valorA is DateTime && valorB is DateTime) {
        return ascendente ? valorA.compareTo(valorB) : valorB.compareTo(valorA);
      } else if (valorA is num && valorB is num) {
        return ascendente ? (valorA - valorB).toInt() : (valorB - valorA).toInt();
      } else if (valorA is String && valorB is String) {
        return ascendente ? valorA.compareTo(valorB) : valorB.compareTo(valorA);
      }
      
      return 0;
    });
    
    setState(() {
      _movimentacoes = dados;
      _movimentacoesOrdenadas = dadosOrdenados;
      _colunaOrdenacao = coluna;
      _ordenacaoAscendente = ascendente;
    });
  }

  void _onSort(String coluna) {
    bool ascendente = true;
    if (_colunaOrdenacao == coluna) {
      ascendente = !_ordenacaoAscendente;
    }
    _ordenarDados(_movimentacoes, coluna, ascendente);
  }

  String _formatarData(String dataString) {
    try {
      final data = DateTime.parse(dataString);
      return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
    } catch (e) {
      return dataString;
    }
  }

  String _formatarNumero(num? valor) {
    if (valor == null) return '0';
    if (valor == 0) return '0';
    
    bool isNegativo = valor < 0;
    String valorString = valor.abs().toStringAsFixed(0);
    
    String resultado = '';
    int contador = 0;
    
    for (int i = valorString.length - 1; i >= 0; i--) {
      contador++;
      resultado = valorString[i] + resultado;
      if (contador % 3 == 0 && i > 0) {
        resultado = '.$resultado';
      }
    }
    
    return isNegativo ? '-$resultado' : resultado;
  }

  Color _getCorFundoEntrada() => Colors.green.shade50.withOpacity(0.3);
  Color _getCorFundoSaida() => Colors.red.shade50.withOpacity(0.3);

  String _getSubtitle() {
    if (widget.dataFiltro != null) {
      final dia = widget.dataFiltro!.day.toString().padLeft(2, '0');
      final mes = widget.dataFiltro!.month.toString().padLeft(2, '0');
      final ano = widget.dataFiltro!.year;
      return 'Produto: ${widget.produtoNome} | Data: $dia/$mes/$ano';
    }
    return 'Produto: ${widget.produtoNome}';
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
              'Estoque – ${widget.nomeFilial}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              _getSubtitle(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_carregando && !_erro)
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              tooltip: 'Ordenar por',
              onSelected: _onSort,
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'data_mov',
                  child: Text(_ordenacaoAscendente && _colunaOrdenacao == 'data_mov' 
                    ? 'Data (mais antigo primeiro)' 
                    : 'Data (mais recente primeiro)'),
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
              ],
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
                : _movimentacoes.isEmpty
                    ? _buildSemDados()
                    : _buildTabelaComEstoque(),
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
          Text('Carregando dados do produto...', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 60),
          const SizedBox(height: 20),
          const Text('Erro ao carregar dados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(_mensagemErro, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _carregarDados,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white),
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
          const Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 60),
          const SizedBox(height: 20),
          const Text('Nenhuma movimentação encontrada', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          Text('Não há movimentações para o produto na data selecionada.', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white),
            child: const Text('Voltar aos filtros'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabelaComEstoque() {
    return Scrollbar(
      controller: _verticalScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalScrollController,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              _buildTabelaCabecalho(),
              _buildTabelaCorpo(),
              _buildContadorResultados(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabelaCabecalho() {
    return Scrollbar(
      controller: _horizontalHeaderController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontalHeaderController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _larguraTabela,
          child: Container(
            height: _alturaCabecalho,
            color: const Color(0xFF0D47A1),
            child: Row(
              children: [
                _th('Data', _larguraData, onTap: () => _onSort('data_mov')),
                _th('Descrição', _larguraDescricao, onTap: () => _onSort('descricao')),
                _th('Cliente/Destino', _larguraClienteDestino, onTap: () => _onSort('cliente_destino')),
                _th('Entrada (Amb)', _larguraNumerica, onTap: () => _onSort('entrada_amb')),
                _th('Entrada (20ºC)', _larguraNumerica, onTap: () => _onSort('entrada_vinte')),
                _th('Saída (Amb)', _larguraNumerica, onTap: () => _onSort('saida_amb')),
                _th('Saída (20ºC)', _larguraNumerica, onTap: () => _onSort('saida_vinte')),
                _th('Saldo (Amb)', _larguraNumerica, onTap: () => _onSort('saldo_amb')),
                _th('Saldo (20ºC)', _larguraNumerica, onTap: () => _onSort('saldo_vinte')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _th(String texto, double largura, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: largura,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        child: Text(
          texto,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildTabelaCorpo() {
    return Scrollbar(
      controller: _horizontalBodyController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontalBodyController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _larguraTabela,
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _movimentacoesOrdenadas.length,
            itemBuilder: (context, index) {
              final e = _movimentacoesOrdenadas[index];
              final saldoAmb = e['saldo_amb'] ?? 0;
              final saldoVinte = e['saldo_vinte'] ?? 0;

              return Container(
                height: _alturaLinha,
                decoration: BoxDecoration(
                  color: index % 2 == 0 ? Colors.grey.shade50 : Colors.white,
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.5)),
                ),
                child: Row(
                  children: [
                    _cell(_formatarData(e['data_mov']), _larguraData),
                    _cell(e['descricao'] ?? '-', _larguraDescricao),
                    _cell(e['cliente_destino'] ?? '-', _larguraClienteDestino),
                    _cell(_formatarNumero(e['entrada_amb']), _larguraNumerica, 
                          fundo: _getCorFundoEntrada(), isNumber: true),
                    _cell(_formatarNumero(e['entrada_vinte']), _larguraNumerica, 
                          fundo: _getCorFundoEntrada(), isNumber: true),
                    _cell(_formatarNumero(e['saida_amb']), _larguraNumerica, 
                          fundo: _getCorFundoSaida(), isNumber: true),
                    _cell(_formatarNumero(e['saida_vinte']), _larguraNumerica, 
                          fundo: _getCorFundoSaida(), isNumber: true),
                    _cell(_formatarNumero(saldoAmb), _larguraNumerica,
                          cor: saldoAmb < 0 ? Colors.red : Colors.black, isNumber: true),
                    _cell(_formatarNumero(saldoVinte), _larguraNumerica,
                          cor: saldoVinte < 0 ? Colors.red : Colors.black, isNumber: true),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _cell(
    String texto,
    double largura, {
    Color? fundo,
    Color? cor,
    FontWeight? fontWeight,
    bool isNumber = false,
  }) {
    return Container(
      width: largura,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      color: fundo,
      child: Text(
        texto.isNotEmpty ? texto : '-',
        style: TextStyle(
          fontSize: 12,
          color: cor ?? Colors.grey.shade700,
          fontWeight: fontWeight ?? (isNumber ? FontWeight.w600 : FontWeight.normal),
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildContadorResultados() {
    return Container(
      height: _alturaRodape,
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Text(
        '${_movimentacoesOrdenadas.length} movimentação(ões)',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
      ),
    );
  }
}