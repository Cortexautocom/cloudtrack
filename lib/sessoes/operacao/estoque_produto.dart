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
    required this.isIntraday,
  });

  @override
  State<EstoqueProdutoPage> createState() => _EstoqueProdutoPageState();
}

class _EstoqueProdutoPageState extends State<EstoqueProdutoPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _carregando = false;
  bool _erro = false;
  String _mensagemErro = '';

  // Dados fictícios para o layout
  List<Map<String, dynamic>> _movs = [];
  List<Map<String, dynamic>> _movsOrdenadas = [];

  Map<String, num?> _estoqueInicial = {'amb': 1500, 'vinte': 1500};
  Map<String, num?> _estoqueFinal = {'amb': 2300, 'vinte': 2300};
  Map<String, num?> _estoqueCACL = {'amb': null, 'vinte': null};
  bool _possuiCACL = false;

  num? _valorSobraPerda;
  bool? _ehSobra;
  String? _produtoNome;

  late DateTime _dataFiltro;

  final ScrollController _vertical = ScrollController();
  final ScrollController _hHeader = ScrollController();
  final ScrollController _hBody = ScrollController();

  static const double _hCab = 40;
  static const double _hRow = 40;
  static const double _hFoot = 32;

  static const double _wData = 120;
  static const double _wDesc = 240;
  static const double _wNum = 130;

  double get _wTable => _wData + _wDesc + (_wNum * 6);

  String _coluna = 'data_mov';
  bool _asc = true;

  @override
  void initState() {
    super.initState();
    _dataFiltro = widget.dataFiltro ?? DateTime.now();
    _syncScroll();
    _produtoNome = widget.produtoNome;
    
    // Carregar apenas o estoque inicial do banco
    _carregarEstoqueInicialDoBanco();
    
    // Dados fictícios para o layout
    _gerarDadosFicticios();
  }

  Future<void> _carregarEstoqueInicialDoBanco() async {
    try {
      setState(() {
        _carregando = true;
      });

      final dataStr = _dataFiltro.toIso8601String().split('T')[0];

      // Única busca real no banco - calcular_estoque_inicial_produto
      final response = await _supabase.rpc(
        'calcular_estoque_inicial_produto',
        params: {
          'p_tanque_id': widget.produtoId,
          'p_data': dataStr,
        },
      );

      final num saldo = (response ?? 0) as num;

      setState(() {
        _estoqueInicial = {
          'amb': saldo,
          'vinte': saldo,
        };
        _carregando = false;
      });
    } catch (e) {
      debugPrint('Erro ao buscar estoque inicial: $e');
      setState(() {
        _carregando = false;
        // Mantém os valores fictícios em caso de erro
      });
    }
  }

  void _gerarDadosFicticios() {
    // Dados de exemplo para o layout
    _movs = [
      {
        'id': '1',
        'data_mov': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'descricao': 'Entrada de produto',
        'entrada_amb': 500,
        'entrada_vinte': 500,
        'saida_amb': 0,
        'saida_vinte': 0,
        'saldo_amb': 2000,
        'saldo_vinte': 2000,
      },
      {
        'id': '2',
        'data_mov': DateTime.now().toIso8601String(),
        'descricao': 'Saída para produção',
        'entrada_amb': 0,
        'entrada_vinte': 0,
        'saida_amb': 200,
        'saida_vinte': 200,
        'saldo_amb': 1800,
        'saldo_vinte': 1800,
      },
      {
        'id': '3',
        'data_mov': DateTime.now().toIso8601String(),
        'descricao': 'Ajuste de estoque',
        'entrada_amb': 500,
        'entrada_vinte': 500,
        'saida_amb': 0,
        'saida_vinte': 0,
        'saldo_amb': 2300,
        'saldo_vinte': 2300,
      },
    ];

    _movsOrdenadas = List.from(_movs);
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

  void _ordenar(String col, bool asc) {
    final ord = List<Map<String, dynamic>>.from(_movs);
    ord.sort((a, b) {
      dynamic va, vb;
      switch (col) {
        case 'data_mov':
          va = DateTime.parse(a['data_mov']);
          vb = DateTime.parse(b['data_mov']);
          break;
        case 'descricao':
          va = (a['descricao'] ?? '').toString().toLowerCase();
          vb = (b['descricao'] ?? '').toString().toLowerCase();
          break;
        case 'entrada_amb':
        case 'entrada_vinte':
        case 'saida_amb':
        case 'saida_vinte':
        case 'saldo_amb':
        case 'saldo_vinte':
          va = a[col] ?? 0;
          vb = b[col] ?? 0;
          break;
        default:
          return 0;
      }
      if (va is DateTime && vb is DateTime) {
        return asc ? va.compareTo(vb) : vb.compareTo(va);
      }
      if (va is num && vb is num) {
        return asc ? va.compareTo(vb) : vb.compareTo(va);
      }
      if (va is String && vb is String) {
        return asc ? va.compareTo(vb) : vb.compareTo(va);
      }
      return 0;
    });

    setState(() {
      _movsOrdenadas = ord;
      _coluna = col;
      _asc = asc;
    });
  }

  void _onSort(String col) {
    final asc = _coluna == col ? !_asc : true;
    _ordenar(col, asc);
  }

  Color _bgEntrada() => Colors.green.shade50.withOpacity(0.3);
  Color _bgSaida() => Colors.red.shade50.withOpacity(0.3);

  String _fmtNum(num? v) {
    if (v == null) return '-';
    final s = v.abs().toStringAsFixed(0);
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final r = s.length - i;
      b.write(s[i]);
      if (r > 1 && r % 3 == 1) b.write('.');
    }
    return v < 0 ? '-${b.toString()}' : b.toString();
  }

  String _fmtData(String s) {
    final d = DateTime.parse(s);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
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
              "Movimentação do Produto – ${_produtoNome ?? widget.produtoNome}",
            ),
            Text(
              '${widget.nomeFilial} | ${_fmtData(_dataFiltro.toIso8601String())}',
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: _buildCampoDataFiltro(),
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () => _onSort('data_mov'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarEstoqueInicialDoBanco,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _carregando
            ? const Center(child: CircularProgressIndicator())
            : _erro
            ? Center(child: Text(_mensagemErro))
            : _buildConteudo(),
      ),
    );
  }

  Widget _buildCampoDataFiltro() {
    final String textoData =
        '${_dataFiltro.day.toString().padLeft(2, '0')}/${_dataFiltro.month.toString().padLeft(2, '0')}/${_dataFiltro.year}';

    return InkWell(
      onTap: () async {
        final dataSelecionada = await showDatePicker(
          context: context,
          initialDate: _dataFiltro,
          firstDate: DateTime(2020, 1, 1),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          helpText: 'Selecionar data',
          cancelText: 'Cancelar',
          confirmText: 'Confirmar',
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFF0D47A1),
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.black,
                ),
              ),
              child: child!,
            );
          },
        );

        if (dataSelecionada != null) {
          setState(() {
            _dataFiltro = DateTime(
              dataSelecionada.year,
              dataSelecionada.month,
              dataSelecionada.day,
            );
          });
          _carregarEstoqueInicialDoBanco();
        }
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF0D47A1).withOpacity(0.5)),
          borderRadius: BorderRadius.circular(4),
          color: Colors.white,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_today,
              size: 14,
              color: Color(0xFF0D47A1),
            ),
            const SizedBox(width: 4),
            Text(
              textoData,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF0D47A1),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConteudo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _buildTabela()),
        _buildBlocoResumo(),
      ],
    );
  }

  Widget _buildBlocoResumo() {
    final estoqueFinalCalculado = _estoqueFinal['vinte'] ?? 0;
    final estoqueCACL = _estoqueCACL['vinte'];

    return Container(
      width: _wTable,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildCampoResumo(
            'Estoque final calculado (20ºC):',
            estoqueFinalCalculado,
          ),

          if (_possuiCACL && estoqueCACL != null)
            _buildCampoResumo(
              'Saldo do CACL (20ºC):',
              estoqueCACL,
              cor: const Color(0xFF2E7D32),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: 220,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 3,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'FECHAR PRODUTO',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (_possuiCACL && _valorSobraPerda != null && _ehSobra != null)
            _buildCampoResumo(
              _ehSobra! ? 'Sobra (20ºC):' : 'Perda (20ºC):',
              _valorSobraPerda!,
              cor: _ehSobra! ? const Color(0xFF0D47A1) : Colors.red,
              negrito: true,
            )
          else
            _buildCampoResumo(
              'Disponível após fechamento',
              _estoqueFinal['vinte'] ?? 0,
              cor: Colors.grey,
            ),
        ],
      ),
    );
  }

  Widget _buildCampoResumo(
    String label,
    num valor, {
    Color? cor,
    bool negrito = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _fmtNum(valor),
          style: TextStyle(
            fontSize: negrito ? 18 : 16,
            fontWeight: FontWeight.bold,
            color: cor ?? const Color(0xFF0D47A1),
          ),
        ),
      ],
    );
  }

  Widget _buildTabela() {
    return Scrollbar(
      controller: _vertical,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _vertical,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(children: [_cabecalho(), _corpo(), _rodape()]),
        ),
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
                _th('Data', _wData, () => _onSort('data_mov')),
                _th('Descrição', _wDesc, () => _onSort('descricao')),
                _th('Entrada (Amb)', _wNum, () => _onSort('entrada_amb')),
                _th('Entrada (20ºC)', _wNum, () => _onSort('entrada_vinte')),
                _th('Saída (Amb)', _wNum, () => _onSort('saida_amb')),
                _th('Saída (20ºC)', _wNum, () => _onSort('saida_vinte')),
                _th('Saldo (Amb)', _wNum, () => _onSort('saldo_amb')),
                _th('Saldo (20ºC)', _wNum, () => _onSort('saldo_vinte')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _th(String t, double w, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: w,
        alignment: Alignment.center,
        child: Text(
          t,
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
            itemCount: _movsOrdenadas.length + 2,
            itemBuilder: (context, i) {
              if (i == 0) {
                return _linhaResumo(
                  'Estoque Inicial',
                  _estoqueInicial['amb'],
                  _estoqueInicial['vinte'],
                  cor: Colors.blue,
                );
              }
              if (i == _movsOrdenadas.length + 1) {
                return _linhaResumo(
                  'Estoque Final',
                  _estoqueFinal['amb'],
                  _estoqueFinal['vinte'],
                  cor: Colors.grey.shade700,
                );
              }

              final e = _movsOrdenadas[i - 1];
              return Container(
                height: _hRow,
                color: (i - 1) % 2 == 0 ? Colors.grey.shade50 : Colors.white,
                child: Row(
                  children: [
                    _cell(_fmtData(e['data_mov']), _wData),
                    _cell(e['descricao'] ?? '-', _wDesc),
                    _cell(_fmtNum(e['entrada_amb']), _wNum, bg: _bgEntrada()),
                    _cell(_fmtNum(e['entrada_vinte']), _wNum, bg: _bgEntrada()),
                    _cell(_fmtNum(e['saida_amb']), _wNum, bg: _bgSaida()),
                    _cell(_fmtNum(e['saida_vinte']), _wNum, bg: _bgSaida()),
                    _cell(
                      _fmtNum(e['saldo_amb']),
                      _wNum,
                      cor: (e['saldo_amb'] ?? 0) < 0 ? Colors.red : null,
                    ),
                    _cell(
                      _fmtNum(e['saldo_vinte']),
                      _wNum,
                      cor: (e['saldo_vinte'] ?? 0) < 0 ? Colors.red : null,
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

  Widget _linhaResumo(String label, num? amb, num? vinte, {Color? cor}) {
    return Container(
      height: _hRow,
      color: Colors.blue.shade50,
      child: Row(
        children: [
          _cell('', _wData),
          _cell(label, _wDesc, cor: cor, fw: FontWeight.bold),
          _cell('-', _wNum),
          _cell('-', _wNum),
          _cell('-', _wNum),
          _cell('-', _wNum),
          _cell(_fmtNum(amb), _wNum, cor: cor, fw: FontWeight.bold),
          _cell(_fmtNum(vinte), _wNum, cor: cor, fw: FontWeight.bold),
        ],
      ),
    );
  }

  Widget _cell(String t, double w, {Color? bg, Color? cor, FontWeight? fw}) {
    return Container(
      width: w,
      alignment: Alignment.center,
      color: bg,
      child: Text(
        t.isEmpty ? '-' : t,
        style: TextStyle(
          fontSize: 12,
          color: cor ?? Colors.grey.shade700,
          fontWeight: fw,
        ),
      ),
    );
  }

  Widget _rodape() {
    return Container(
      height: _hFoot,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      color: Colors.grey.shade100,
      child: Text(
        '${_movsOrdenadas.length} movimentação(ões)',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}