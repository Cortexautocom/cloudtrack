import 'package:flutter/material.dart';

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
  // Flags de carregamento
  bool _carregandoDados = false;
  
  // Dados da tabela
  List<Map<String, dynamic>> _movimentacoes = [];
  List<Map<String, dynamic>> _movimentacoesOrdenadas = [];
  
  // Controles de scroll (igual ao EstoqueTanquePage)
  final ScrollController _vertical = ScrollController();
  final ScrollController _hHeader = ScrollController();
  final ScrollController _hBody = ScrollController();
  
  // Dimensões da tabela (igual ao EstoqueTanquePage)
  static const double _hCab = 40;
  static const double _hRow = 40;
  
  static const double _wData = 120;
  static const double _wPlaca = 180;
  static const double _wNum = 130;
  
  double get _wTable => _wData + _wPlaca + (_wNum * 3);
  
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
    _carregarDadosMock();
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

  void _carregarDadosMock() {
    // Dados fictícios para teste de layout
    final List<Map<String, dynamic>> mock = [
      {'data': '2026-03-01', 'placa': 'ABC-1234', 'entradas': 10, 'saidas': 3, 'saldo': 7},
      {'data': '2026-03-03', 'placa': 'DEF-5678', 'entradas': 5,  'saidas': 5, 'saldo': 7},
      {'data': '2026-03-05', 'placa': 'GHI-9012', 'entradas': 8,  'saidas': 2, 'saldo': 13},
      {'data': '2026-03-07', 'placa': 'ABC-1234', 'entradas': 0,  'saidas': 4, 'saldo': 9},
      {'data': '2026-03-10', 'placa': 'JKL-3456', 'entradas': 12, 'saidas': 6, 'saldo': 15},
      {'data': '2026-03-12', 'placa': 'MNO-7890', 'entradas': 4,  'saidas': 1, 'saldo': 18},
      {'data': '2026-03-14', 'placa': 'DEF-5678', 'entradas': 7,  'saidas': 7, 'saldo': 18},
      {'data': '2026-03-15', 'placa': 'PQR-2345', 'entradas': 6,  'saidas': 2, 'saldo': 22},
      {'data': '2026-03-17', 'placa': 'GHI-9012', 'entradas': 3,  'saidas': 3, 'saldo': 22},
      {'data': '2026-03-18', 'placa': 'STU-6789', 'entradas': 9,  'saidas': 4, 'saldo': 27},
    ];

    int totalEntradas = 0;
    int totalSaidas = 0;
    for (var item in mock) {
      totalEntradas += item['entradas'] as int;
      totalSaidas += item['saidas'] as int;
    }

    setState(() {
      _movimentacoes = mock;
      _movimentacoesOrdenadas = List.from(mock);
      _totalEntradas = totalEntradas;
      _totalSaidas = totalSaidas;
      _saldoFinal = mock.isNotEmpty ? mock.last['saldo'] as int : 0;
    });
  }

  void _ordenar(String col, bool asc) {
    final ord = List<Map<String, dynamic>>.from(_movimentacoes);
    ord.sort((a, b) {
      dynamic va, vb;
      switch (col) {
        case 'data':
          va = a['data'] as String;
          vb = b['data'] as String;
          break;
        case 'placa':
          va = (a['placa'] as String? ?? '').toLowerCase();
          vb = (b['placa'] as String? ?? '').toLowerCase();
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
    final partes = dataStr.split('-');
    if (partes.length == 3) {
      return '${partes[2]}/${partes[1]}/${partes[0]}';
    }
    return dataStr;
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Painel de filtros (somente leitura)
            Container(
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
            
            const SizedBox(height: 20),
            
            // Tabela
            Expanded(
              child: _carregandoDados
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)))
                  : _movimentacoes.isEmpty
                      ? Center(
                          child: Column(
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
                                'Selecione um terminal e empresa para consultar',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _buildTabela(),
            ),
            
            // Rodapé com resumo
            if (_movimentacoes.isNotEmpty) _buildRodape(),
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