import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';

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

  bool _carregando = true;
  bool _erro = false;
  String _mensagemErro = '';
  
  String? _terminalId;
  String? _terminalNome;
  bool _carregandoTerminal = true;

  List<Map<String, dynamic>> _movs = [];
  List<Map<String, dynamic>> _movsOrdenadas = [];

  Map<String, num?> _estoqueInicial = {'amb': 0, 'vinte': 0};
  Map<String, num?> _estoqueFinal = {'amb': null, 'vinte': null};

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
    _carregarTerminalDoUsuario();
  }

  Future<void> _carregarTerminalDoUsuario() async {
    try {
      final usuario = UsuarioAtual.instance;
      if (usuario == null) throw Exception('Usuário não logado');

      if (usuario.nivel < 3) {
        // Níveis 1 e 2: terminal vem do login
        _terminalId = usuario.terminalId;
        _terminalNome = usuario.terminalNome;
      } else {
        // Nível 3: terminal vem por parâmetro da página anterior
        _terminalId = widget.terminalId;
        if (_terminalId != null && _terminalId!.isNotEmpty) {
          final response = await _supabase
              .from('terminais')
              .select('id, nome')
              .eq('id', _terminalId!)
              .maybeSingle();
          _terminalNome = response?['nome']?.toString();
        }
      }

      await _carregar();
    } catch (e) {
      setState(() {
        _erro = true;
        _mensagemErro = 'Erro ao carregar terminal: $e';
        _carregandoTerminal = false;
        _carregando = false;
      });
    }
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

  Future<void> _carregarEstoqueInicialDoBanco() async {
    try {
      final dataStr = _dataFiltro.toIso8601String().split('T')[0];

      final response = await _supabase.rpc(
        'calcular_estoque_inicial_produto',
        params: {
          'p_produto_id': widget.produtoId,
          'p_data': dataStr,
        },
      );

      final num saldo = (response ?? 0) as num;

      _estoqueInicial = {
        'amb': saldo,
        'vinte': saldo,
      };
    } catch (e) {
      debugPrint('Erro ao buscar estoque inicial via função: $e');
      _estoqueInicial = {'amb': 0, 'vinte': 0};
    }
  }

  Future<void> _carregar() async {
    final terminalId = _terminalId;
    if (terminalId == null || terminalId.isEmpty) {
      setState(() {
        _erro = true;
        _mensagemErro = 'Terminal não identificado';
        _carregando = false;
        _carregandoTerminal = false;
      });
      return;
    }

    setState(() {
      _carregando = true;
      _erro = false;
      _carregandoTerminal = false;
    });

    try {
      await _carregarEstoqueInicialDoBanco();

      final dataStr = _dataFiltro.toIso8601String().split('T')[0];

      // Buscar movimentações do produto no terminal
      final dados = await _supabase
          .from('movimentacoes_tanque')
          .select('''
            id,
            movimentacao_id,
            data_mov,
            cliente,
            descricao,
            entrada_amb,
            entrada_vinte,
            saida_amb,
            saida_vinte,
            tanques!inner (
              id_produto,
              terminais!inner (
                id
              )
            )
          ''')
          .eq('tanques.id_produto', widget.produtoId)
          .eq('tanques.terminais.id', terminalId)
          .gte('data_mov', '$dataStr 00:00:00')
          .lte('data_mov', '$dataStr 23:59:59')
          .order('data_mov', ascending: true);

      final List<Map<String, dynamic>> listaOrdenadaParaUI =
          List<Map<String, dynamic>>.from(dados);

      num saldoAmb = _estoqueInicial['amb'] ?? 0;
      num saldoVinte = _estoqueInicial['vinte'] ?? 0;

      final List<Map<String, dynamic>> listaComSaldo = [];

      for (final m in listaOrdenadaParaUI) {
        final num entradaAmb = (m['entrada_amb'] ?? 0) as num;
        final num entradaVinte = (m['entrada_vinte'] ?? 0) as num;
        final num saidaAmb = (m['saida_amb'] ?? 0) as num;
        final num saidaVinte = (m['saida_vinte'] ?? 0) as num;

        final String cliente = (m['cliente']?.toString().trim() ?? '');
        final String desc = (m['descricao']?.toString().trim() ?? '');
        final String descricao = cliente.isNotEmpty ? cliente : desc;

        saldoAmb += entradaAmb - saidaAmb;
        saldoVinte += entradaVinte - saidaVinte;

        listaComSaldo.add({
          'id': m['id'],
          'movimentacao_id': m['movimentacao_id'],
          'data_mov': m['data_mov'],
          'descricao': descricao,
          'entrada_amb': entradaAmb,
          'entrada_vinte': entradaVinte,
          'saida_amb': saidaAmb,
          'saida_vinte': saidaVinte,
          'saldo_amb': saldoAmb,
          'saldo_vinte': saldoVinte,
        });
      }

      _movs = List<Map<String, dynamic>>.from(listaComSaldo);
      _movsOrdenadas = List<Map<String, dynamic>>.from(listaComSaldo);

      _estoqueFinal = {
        'amb': _movs.isEmpty ? null : _movs.last['saldo_amb'],
        'vinte': _movs.isEmpty ? null : _movs.last['saldo_vinte'],
      };

      setState(() => _carregando = false);
    } catch (e) {
      setState(() {
        _carregando = false;
        _erro = true;
        _mensagemErro = e.toString();
      });
    }
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
              '${widget.nomeFilial}${_terminalNome != null ? ' - ${_terminalNome!}' : ''} | ${_fmtData(_dataFiltro.toIso8601String())}',
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
            onPressed: _carregar,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _carregandoTerminal || _carregando
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
          _carregar();
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildCampoResumo(
            'Estoque final (20ºC):',
            estoqueFinalCalculado,
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