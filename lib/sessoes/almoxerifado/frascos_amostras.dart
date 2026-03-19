import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FrascosAmostraPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final String? terminalId;
  final String? empresaId;
  final String nomeTerminal;
  final String? empresaNome;
  final DateTime? mesFiltro;
  final String tipoRelatorio;
  final bool isIntraday;
  final DateTime? dataIntraday;

  const FrascosAmostraPage({
    super.key,
    required this.onVoltar,
    this.terminalId,
    this.empresaId,
    required this.nomeTerminal,
    this.empresaNome,
    this.mesFiltro,
    this.tipoRelatorio = 'sintetico',
    this.isIntraday = false,
    this.dataIntraday,
  });

  @override
  State<FrascosAmostraPage> createState() => _FrascosAmostraPageState();
}

class _FrascosAmostraPageState extends State<FrascosAmostraPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Flags de carregamento
  bool _carregandoDados = false;
  String? _erro;
  
  // Dados da tabela
  List<Map<String, dynamic>> _movimentacoes = [];
  List<Map<String, dynamic>> _movimentacoesOrdenadas = [];
  
  // Controles de scroll
  final ScrollController _vertical = ScrollController();
  final ScrollController _hHeader = ScrollController();
  final ScrollController _hBody = ScrollController();
  
  // Dimensões da tabela
  static const double _hCab = 40;
  static const double _hRow = 40;
  
  static const double _wData = 120;
  static const double _wPlaca = 180;
  static const double _wNum = 130;
  
  double get _wTable {
    if (widget.tipoRelatorio == 'sintetico') {
      return _wData + (_wNum * 4); // Data + entradas + saídas + saldo
    } else {
      return _wData + _wPlaca + (_wNum * 3); // Data + Placa + entradas + saídas + saldo
    }
  }
  
  // Ordenação
  String _coluna = 'data_mov';
  bool _asc = true;
  
  // Totais
  int _totalEntradas = 0;
  int _totalSaidas = 0;
  int _saldoFinal = 0;

  @override
  void initState() {
    super.initState();
    _syncScroll();
    _carregarDados();
  }

  void _syncScroll() {
    _hHeader.addListener(() {
      if (_hBody.hasClients && _hBody.offset != _hHeader.offset) {
        _hBody.jumpTo(_hHeader.offset);
      }
    });
    _hBody.addListener(() {
      if (_hHeader.hasClients && _hHeader.offset != _hBody.offset) {
        _hHeader.jumpTo(_hBody.offset);
      }
    });
  }

  @override
  void dispose() {
    _vertical.dispose();
    _hHeader.dispose();
    _hBody.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    if (widget.terminalId == null || widget.terminalId!.isEmpty ||
        widget.empresaId == null || widget.empresaId!.isEmpty) {
      setState(() {
        _erro = 'Terminal e empresa são obrigatórios';
      });
      return;
    }

    setState(() {
      _carregandoDados = true;
      _erro = null;
    });

    try {
      // Definir período da consulta
      final DateTime dataInicio;
      final DateTime dataFim;

      if (widget.isIntraday && widget.dataIntraday != null) {
        dataInicio = DateTime(
          widget.dataIntraday!.year,
          widget.dataIntraday!.month,
          widget.dataIntraday!.day,
        );
        dataFim = DateTime(
          widget.dataIntraday!.year,
          widget.dataIntraday!.month,
          widget.dataIntraday!.day,
          23, 59, 59,
        );
      } else if (widget.mesFiltro != null) {
        dataInicio = DateTime(
          widget.mesFiltro!.year,
          widget.mesFiltro!.month,
          1,
        );
        dataFim = DateTime(
          widget.mesFiltro!.year,
          widget.mesFiltro!.month + 1,
          0,
          23, 59, 59,
        );
      } else {
        setState(() {
          _erro = 'Período não definido';
          _carregandoDados = false;
        });
        return;
      }

      // Buscar movimentações do período
      final response = await _supabase
          .from('movimentacoes')
          .select('''
            id,
            data_mov,
            placa,
            entrada_amb,
            saida_amb,
            tipo_op
          ''')
          .eq('terminal_orig_id', widget.terminalId!)
          .eq('empresa_id', widget.empresaId!)
          .gte('data_mov', dataInicio.toIso8601String())
          .lte('data_mov', dataFim.toIso8601String())
          .order('data_mov', ascending: true);

      if (widget.tipoRelatorio == 'sintetico') {
        _processarDadosSintetico(response);
      } else {
        _processarDadosAnalitico(response);
      }

    } catch (e) {
      debugPrint('❌ Erro ao carregar dados: $e');
      setState(() {
        _erro = 'Erro ao carregar dados: ${e.toString()}';
        _carregandoDados = false;
      });
    }
  }

  void _processarDadosAnalitico(List<dynamic> response) {
    final List<Map<String, dynamic>> movimentacoes = [];
    int saldoAcumulado = 0;
    int totalEntradas = 0;
    int totalSaidas = 0;

    for (var item in response) {
      int entradas = 0;
      if (item['tipo_op'] == 'compra_frasco') {
        entradas = (item['entrada_amb'] as int?) ?? 0;
      }

      int saidas = 0;
      if (item['tipo_op'] == 'venda' || item['tipo_op'] == 'transf') {
        saidas = 1;
      }

      String placa = '';
      if (item['placa'] != null) {
        final placas = item['placa'] as List<dynamic>;
        placa = placas.join(' / ');
      }

      totalEntradas += entradas;
      totalSaidas += saidas;
      saldoAcumulado = saldoAcumulado + entradas - saidas;

      movimentacoes.add({
        'data': item['data_mov'],
        'placa': placa,
        'entradas': entradas,
        'saidas': saidas,
        'saldo': saldoAcumulado,
        'quantidade': 1, // Para ordenação
      });
    }

    setState(() {
      _movimentacoes = movimentacoes;
      _movimentacoesOrdenadas = List.from(movimentacoes);
      _totalEntradas = totalEntradas;
      _totalSaidas = totalSaidas;
      _saldoFinal = saldoAcumulado;
      _carregandoDados = false;
    });
  }

  void _processarDadosSintetico(List<dynamic> response) {
    // Agrupar por data
    final Map<String, Map<String, dynamic>> grupos = {};
    int saldoAcumulado = 0;
    int totalEntradas = 0;
    int totalSaidas = 0;

    for (var item in response) {
      final String data = item['data_mov'].split('T')[0]; // Pega apenas YYYY-MM-DD
      
      if (!grupos.containsKey(data)) {
        grupos[data] = {
          'data': item['data_mov'],
          'entradas': 0,
          'saidas': 0,
          'movimentacoes': 0,
          'placa': 'Múltiplas',
        };
      }

      int entradas = 0;
      if (item['tipo_op'] == 'compra_frasco') {
        entradas = (item['entrada_amb'] as int?) ?? 0;
      }

      int saidas = 0;
      if (item['tipo_op'] == 'venda' || item['tipo_op'] == 'transf') {
        saidas = 1;
      }

      grupos[data]!['entradas'] = (grupos[data]!['entradas'] as int) + entradas;
      grupos[data]!['saidas'] = (grupos[data]!['saidas'] as int) + saidas;
      grupos[data]!['movimentacoes'] = (grupos[data]!['movimentacoes'] as int) + 1;

      totalEntradas += entradas;
      totalSaidas += saidas;
    }

    // Calcular saldo acumulado por data
    final List<Map<String, dynamic>> movimentacoes = [];
    final datasOrdenadas = grupos.keys.toList()..sort();

    for (var data in datasOrdenadas) {
      final grupo = grupos[data]!;
      saldoAcumulado = saldoAcumulado + (grupo['entradas'] as int) - (grupo['saidas'] as int);
      
      movimentacoes.add({
        'data': grupo['data'],
        'placa': '${grupo['movimentacoes']} movimentações',
        'entradas': grupo['entradas'],
        'saidas': grupo['saidas'],
        'saldo': saldoAcumulado,
        'quantidade': grupo['movimentacoes'], // Para ordenação
      });
    }

    setState(() {
      _movimentacoes = movimentacoes;
      _movimentacoesOrdenadas = List.from(movimentacoes);
      _totalEntradas = totalEntradas;
      _totalSaidas = totalSaidas;
      _saldoFinal = saldoAcumulado;
      _carregandoDados = false;
    });
  }

  void _ordenar(String col, bool asc) {
    final ord = List<Map<String, dynamic>>.from(_movimentacoes);
    ord.sort((a, b) {
      dynamic va, vb;
      switch (col) {
        case 'data':
          va = DateTime.parse(a['data'] as String);
          vb = DateTime.parse(b['data'] as String);
          break;
        case 'placa':
          if (widget.tipoRelatorio == 'sintetico') {
            // Ordenar por quantidade de movimentações
            va = a['quantidade'] as int? ?? 0;
            vb = b['quantidade'] as int? ?? 0;
          } else {
            va = (a['placa'] as String? ?? '').toLowerCase();
            vb = (b['placa'] as String? ?? '').toLowerCase();
          }
          break;
        case 'entradas':
        case 'saidas':
        case 'saldo':
          va = a[col] as int? ?? 0;
          vb = b[col] as int? ?? 0;
          break;
        default:
          return 0;
      }
      if (va is DateTime && vb is DateTime) {
        return asc ? va.compareTo(vb) : vb.compareTo(va);
      }
      if (va is String && vb is String) {
        return asc ? va.compareTo(vb) : vb.compareTo(va);
      }
      if (va is int && vb is int) {
        return asc ? va.compareTo(vb) : vb.compareTo(va);
      }
      return 0;
    });

    setState(() {
      _movimentacoesOrdenadas = ord;
      _coluna = col;
      _asc = asc;
    });
  }

  void _onSort(String col) {
    final asc = _coluna == col ? !_asc : true;
    _ordenar(col, asc);
  }

  String _fmtNum(int? v) {
    if (v == null) return '-';
    return v.toString();
  }

  String _fmtData(String dataStr) {
    try {
      final date = DateTime.parse(dataStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dataStr;
    }
  }

  Color _bgEntrada() => Colors.green.shade50.withOpacity(0.3);
  Color _bgSaida() => Colors.red.shade50.withOpacity(0.3);

  String _fmtPeriodo() {
    if (widget.isIntraday && widget.dataIntraday != null) {
      final d = widget.dataIntraday!;
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }
    if (widget.mesFiltro != null) {
      return '${widget.mesFiltro!.month.toString().padLeft(2, '0')}/${widget.mesFiltro!.year}';
    }
    return '-';
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
            const Text(
              'Frascos de Amostra Testemunha',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              widget.nomeTerminal,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onVoltar,
        ),
        actions: [
          // Indicador do tipo de relatório
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0D47A1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  widget.tipoRelatorio == 'sintetico' 
                      ? Icons.view_week 
                      : Icons.view_list,
                  size: 16,
                  color: const Color(0xFF0D47A1),
                ),
                const SizedBox(width: 4),
                Text(
                  widget.tipoRelatorio == 'sintetico' ? 'Sintético' : 'Analítico',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0D47A1),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarDados,
            tooltip: 'Recarregar dados',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Painel de filtros
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Wrap(
                    spacing: 32,
                    runSpacing: 12,
                    children: [
                      _buildInfoFiltro(Icons.store, 'Terminal', widget.nomeTerminal),
                      _buildInfoFiltro(Icons.business, 'Empresa', widget.empresaNome ?? '-'),
                      _buildInfoFiltro(
                        Icons.calendar_today,
                        widget.isIntraday ? 'Data' : 'Mês',
                        _fmtPeriodo(),
                      ),
                      _buildInfoFiltro(
                        Icons.assessment,
                        'Tipo',
                        widget.tipoRelatorio == 'sintetico' ? 'Sintético' : 'Analítico',
                      ),
                      if (widget.isIntraday)
                        _buildInfoFiltro(Icons.access_time, 'Modo', 'Intraday'),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Tabela
            Expanded(
              child: _carregandoDados
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)))
                  : _erro != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                              const SizedBox(height: 16),
                              Text(
                                _erro!,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.red.shade700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _carregarDados,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D47A1),
                                ),
                                child: const Text('Tentar novamente'),
                              ),
                            ],
                          ),
                        )
                      : Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 900),
                            child: _movimentacoes.isEmpty
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Nenhuma movimentação encontrada',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Não há registros de frascos de amostra para o período selecionado',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade500,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  )
                                : _buildTabela(),
                          ),
                        ),
            ),
            
            // Rodapé com resumo
            if (_movimentacoes.isNotEmpty && _erro == null)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: _buildRodape(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabela() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          _cabecalho(),
          Expanded(
            child: Scrollbar(
              controller: _vertical,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _vertical,
                child: _corpo(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cabecalho() {
    return Scrollbar(
      controller: _hHeader,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _hHeader,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _wTable,
          child: Container(
            height: _hCab,
            color: const Color(0xFF0D47A1),
            child: Row(
              children: [
                _th('Data', _wData, () => _onSort('data')),
                if (widget.tipoRelatorio == 'sintetico')
                  _th('Movimentações', _wNum, () => _onSort('placa'))
                else
                  _th('Placa', _wPlaca, () => _onSort('placa')),
                _th('Qtd entrada', _wNum, () => _onSort('entradas')),
                _th('Qtd saída', _wNum, () => _onSort('saidas')),
                _th('Saldo', _wNum, () => _onSort('saldo')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _th(String titulo, double largura, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: largura,
        alignment: Alignment.center,
        child: Text(
          titulo,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _corpo() {
    return Scrollbar(
      controller: _hBody,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _hBody,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _wTable,
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _movimentacoesOrdenadas.length,
            itemBuilder: (context, index) {
              final item = _movimentacoesOrdenadas[index];
              return Container(
                height: _hRow,
                color: index % 2 == 0 ? Colors.grey.shade50 : Colors.white,
                child: Row(
                  children: [
                    _cell(_fmtData(item['data'] as String), _wData),
                    if (widget.tipoRelatorio == 'sintetico')
                      _cell(item['placa'] as String? ?? '-', _wNum)
                    else
                      _cell(item['placa'] as String? ?? '-', _wPlaca),
                    _cell(_fmtNum(item['entradas'] as int?), _wNum, bg: _bgEntrada()),
                    _cell(_fmtNum(item['saidas'] as int?), _wNum, bg: _bgSaida()),
                    _cell(
                      _fmtNum(item['saldo'] as int?),
                      _wNum,
                      cor: (item['saldo'] as int? ?? 0) < 0 ? Colors.red : null,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _cell(String texto, double largura, {Color? bg, Color? cor}) {
    return Container(
      width: largura,
      alignment: Alignment.center,
      color: bg,
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 12,
          color: cor ?? Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildInfoFiltro(IconData icon, String label, String valor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade500,
              ),
            ),
            Text(
              valor,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRodape() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildItemRodape(
            'Total de entradas',
            _fmtNum(_totalEntradas),
            Colors.green.shade700,
          ),
          _buildItemRodape(
            'Total de saídas',
            _fmtNum(_totalSaidas),
            Colors.red.shade700,
          ),
          _buildItemRodape(
            'Saldo atual',
            _fmtNum(_saldoFinal),
            const Color(0xFF0D47A1),
            negrito: true,
          ),
        ],
      ),
    );
  }

  Widget _buildItemRodape(String label, String valor, Color cor, {bool negrito = false}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          valor,
          style: TextStyle(
            fontSize: negrito ? 18 : 16,
            fontWeight: negrito ? FontWeight.bold : FontWeight.normal,
            color: cor,
          ),
        ),
      ],
    );
  }
}