import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'emitir_cacl.dart';

class EstoqueTanquePage extends StatefulWidget {
  final String tanqueId;
  final String referenciaTanque;
  final String filialId;
  final String nomeFilial;
  final DateTime data;
  final VoidCallback? onVoltar;

  const EstoqueTanquePage({
    super.key,
    required this.tanqueId,
    required this.referenciaTanque,
    required this.filialId,
    required this.nomeFilial,
    required this.data,
    this.onVoltar,
  });

  @override
  State<EstoqueTanquePage> createState() => _EstoqueTanquePageState();
}

class _EstoqueTanquePageState extends State<EstoqueTanquePage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _carregando = true;
  bool _erro = false;
  String _mensagemErro = '';

  List<Map<String, dynamic>> _movs = [];
  List<Map<String, dynamic>> _movsOrdenadas = [];

  Map<String, num?> _estoqueInicial = {'amb': 0, 'vinte': 0};
  Map<String, num?> _estoqueFinal = {'amb': null, 'vinte': null};
  Map<String, num?> _estoqueCACL = {'amb': null, 'vinte': null};
  bool _possuiCACL = false;

  final ScrollController _vertical = ScrollController();
  final ScrollController _hHeader = ScrollController();
  final ScrollController _hBody = ScrollController();

  static const double _hCab = 40;
  static const double _hRow = 40;
  static const double _hFoot = 32;

  static const double _wData = 120;
  static const double _wDesc = 260;
  static const double _wNum = 130;

  double get _wTable => _wData + _wDesc + (_wNum * 6);

  String _coluna = 'data_mov';
  bool _asc = true;

  @override
  void initState() {
    super.initState();
    _syncScroll();
    _carregar();
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
  
  Future<void> _carregarEstoqueInicialDoDiario() async {
    try {
      final dataAnterior = widget.data.subtract(const Duration(days: 1));
      final dataAnteriorStr = dataAnterior.toIso8601String().split('T')[0];
      final inicioDoDiaAnterior = '$dataAnteriorStr 00:00:00';
      final fimDoDiaAnterior = '$dataAnteriorStr 23:59:59';
      
      final response = await _supabase
          .from('saldo_tanque_diario')
          .select('saldo')
          .eq('tanque_id', widget.tanqueId)
          .gte('data_mov', inicioDoDiaAnterior)
          .lte('data_mov', fimDoDiaAnterior)
          .maybeSingle();

      if (response != null) {
        _estoqueInicial = {
          'amb': response['saldo'] ?? 0,
          'vinte': response['saldo'] ?? 0,
        };
      } else {
        _estoqueInicial = {'amb': 0, 'vinte': 0};
      }
    } catch (e) {
      _estoqueInicial = {'amb': 0, 'vinte': 0};
    }
  }

  Future<void> _verificarCACLExistente() async {
    try {
      final dataStr = widget.data.toIso8601String().split('T')[0];
      final inicioDoDia = '$dataStr 00:00:00';
      final fimDoDia = '$dataStr 23:59:59';
      
      final response = await _supabase
          .from('saldo_tanque_diario')
          .select('saldo')
          .eq('tanque_id', widget.tanqueId)
          .gte('data_mov', inicioDoDia)
          .lte('data_mov', fimDoDia)
          .maybeSingle();

      if (response != null) {
        _possuiCACL = true;
        _estoqueCACL = {
          'amb': response['saldo'] ?? 0,
          'vinte': response['saldo'] ?? 0,
        };
      } else {
        _possuiCACL = false;
        _estoqueCACL = {'amb': null, 'vinte': null};
      }
    } catch (e) {
      _possuiCACL = false;
      _estoqueCACL = {'amb': null, 'vinte': null};
    }
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = false;
    });

    try {
      await _carregarEstoqueInicialDoDiario();
      await _verificarCACLExistente();
      
      final dataStr = widget.data.toIso8601String().split('T')[0];

      // Consulta com as 4 colunas da tabela movimentacoes_tanque
      final dados = await _supabase
          .from('movimentacoes_tanque')
          .select('''
            id,
            data_mov,
            cliente,
            descricao,
            entrada_amb,
            entrada_vinte,
            saida_amb,
            saida_vinte
          ''')
          .eq('tanque_id', widget.tanqueId)
          .gte('data_mov', '$dataStr 00:00:00')
          .lte('data_mov', '$dataStr 23:59:59')
          .order('data_mov', ascending: true);

      num saldoAmb = _estoqueInicial['amb'] ?? 0;
      num saldoVinte = _estoqueInicial['vinte'] ?? 0;

      final List<Map<String, dynamic>> lista = [];

      for (final m in dados) {
        final num entradaAmb = (m['entrada_amb'] ?? 0) as num;
        final num entradaVinte = (m['entrada_vinte'] ?? 0) as num;
        final num saidaAmb = (m['saida_amb'] ?? 0) as num;
        final num saidaVinte = (m['saida_vinte'] ?? 0) as num;
        final String cliente = (m['cliente']?.toString().trim() ?? '');
        final String desc = (m['descricao']?.toString().trim() ?? '');
        final String descricao = cliente.isNotEmpty ? cliente : desc;

        // Atualiza saldos: entrada soma, saída subtrai
        saldoAmb += entradaAmb - saidaAmb;
        saldoVinte += entradaVinte - saidaVinte;

        lista.add({
          'id': m['id'],
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

      _movs = lista;
      _ordenar('data_mov', true);

      _estoqueFinal = {
        'amb': _movsOrdenadas.isEmpty ? null : _movsOrdenadas.last['saldo_amb'],
        'vinte': _movsOrdenadas.isEmpty ? null : _movsOrdenadas.last['saldo_vinte'],
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

  void _navegarParaCACL() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MedicaoTanquesPage(
          onVoltar: () => Navigator.pop(context),
          filialSelecionadaId: widget.filialId,
          tanqueSelecionadoId: widget.tanqueId,
          caclBloqueadoComoVerificacao: true,
        ),
      ),
    );
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
            Text('Estoque do Tanque – ${widget.referenciaTanque}'),
            Text(
              '${widget.nomeFilial} | ${_fmtData(widget.data.toIso8601String())}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onVoltar ?? () => Navigator.pop(context),
        ),
        actions: [
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
        child: _carregando
            ? const Center(child: CircularProgressIndicator())
            : _erro
                ? Center(child: Text(_mensagemErro))
                : _buildConteudo(),
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
    
    final sobraPerda = _possuiCACL && estoqueCACL != null 
        ? estoqueCACL - estoqueFinalCalculado 
        : 0;
    
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
          _buildCampoResumo('Estoque final calculado (20ºC):', estoqueFinalCalculado),
          
          if (_possuiCACL && estoqueCACL != null)
            _buildCampoResumo('Saldo do CACL (20ºC):', estoqueCACL, cor: const Color(0xFF2E7D32))
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: 220,
                child: ElevatedButton(
                  onPressed: _navegarParaCACL,
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
                        'FECHAR TANQUE',
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
          
          _buildCampoResumo('Sobra/perda (20ºC):', sobraPerda, 
              cor: sobraPerda < 0 ? Colors.red : const Color(0xFF0D47A1)),
        ],
      ),
    );
  }

  Widget _buildCampoResumo(String label, num valor, {Color? cor}) {
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
            fontSize: 16,
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
          child: Column(
            children: [
              _cabecalho(),
              _corpo(),
              _rodape(),
            ],
          ),
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
        child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
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
                    _cell(_fmtNum(e['saldo_amb']), _wNum, cor: (e['saldo_amb'] ?? 0) < 0 ? Colors.red : null),
                    _cell(_fmtNum(e['saldo_vinte']), _wNum, cor: (e['saldo_vinte'] ?? 0) < 0 ? Colors.red : null),
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
        style: TextStyle(fontSize: 12, color: cor ?? Colors.grey.shade700, fontWeight: fw),
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
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
      ),
    );
  }
}