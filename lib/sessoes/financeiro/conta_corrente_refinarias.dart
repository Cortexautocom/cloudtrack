import 'package:flutter/material.dart';

class ContaCorrenteRefinariasPage extends StatefulWidget {
  final String? filialId;
  final String nomeFilial;
  final VoidCallback onVoltar;

  const ContaCorrenteRefinariasPage({
    super.key,
    this.filialId,
    required this.nomeFilial,
    required this.onVoltar,
  });

  @override
  State<ContaCorrenteRefinariasPage> createState() => _ContaCorrenteRefinariasPageState();
}

class _ContaCorrenteRefinariasPageState extends State<ContaCorrenteRefinariasPage> {
  final ScrollController _vertical = ScrollController();
  final ScrollController _hHeader = ScrollController();
  final ScrollController _hBody = ScrollController();

  static const double _hCab = 40;
  static const double _hRow = 42;

  static const double _wData       = 85;
  static const double _wBase       = 110;
  static const double _wNF         = 90;
  static const double _wFormaPag   = 115;
  static const double _wProduto    = 115;
  static const double _wQtd        = 80;
  static const double _wEntrada    = 105;
  static const double _wTotalNF    = 105;
  static const double _wPreco      = 90;
  static const double _wPrecoTab   = 105;
  static const double _wDifPreco   = 95;
  static const double _wSaldo      = 105;

  double get _wTable =>
      _wData + _wBase + _wNF + _wFormaPag + _wProduto + _wQtd +
      _wEntrada + _wTotalNF + _wPreco + _wPrecoTab + _wDifPreco + _wSaldo;

  // Dados fictícios
  final List<Map<String, dynamic>> _dadosFicticios = List.generate(20, (i) {
    final data = i + 1;
    final isDiesel = i % 2 == 0;
    final preco = isDiesel ? 5.50 + (i * 0.01) : 6.20 - (i * 0.01);
    final precoTab = isDiesel ? 5.45 : 6.15;
    final entrada = i % 5 == 0 ? 50000.00 : 0.0;
    
    return {
      'data': '${data.toString().padLeft(2, '0')}/03/2026',
      'base': i % 3 == 0 ? 'REDUC' : (i % 3 == 1 ? 'REPLAN' : 'REVAP'),
      'nf': '${12345 + i}',
      'forma_pag': i % 4 == 0 ? 'Boleto' : (i % 4 == 1 ? 'PIX' : 'TED'),
      'produto': isDiesel ? 'Diesel S10' : 'Gasolina C',
      'qtd': 10000.0 + (i * 1000),
      'entrada': entrada,
      'total_nf': (10000.0 + (i * 1000)) * preco,
      'preco': preco,
      'preco_tabela': precoTab,
      'dif_preco': preco - precoTab,
      'saldo_final': 50000.00 + (i * 5000),
    };
  });

  @override
  void initState() {
    super.initState();
    _syncScroll();
  }

  void _syncScroll() {
    _hHeader.addListener(() {
      if (_hBody.hasClients && _hBody.offset != _hHeader.offset) {
        _hBody.jumpTo(_hHeader.offset);
      }
    });
    _hBody.addListener(() {
      if (_hHeader.hasClients && _hHeader.offset != _hBody.offset) {
        _hBody.jumpTo(_hHeader.offset);
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

  String _fmtMoeda(num v) {
    final s = v.abs().toStringAsFixed(2).replaceAll('.', ',');
    final partes = s.split(',');
    final inteiro = partes[0];
    final decimal = partes[1];
    
    final b = StringBuffer();
    for (int i = 0; i < inteiro.length; i++) {
      final r = inteiro.length - i;
      b.write(inteiro[i]);
      if (r > 1 && r % 3 == 1) b.write('.');
    }
    final formatado = 'R\$ ${b.toString()},${decimal}';
    return v < 0 ? '- $formatado' : formatado;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D47A1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onVoltar,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Conta-corrente Refinarias"),
            Text(
              widget.nomeFilial,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(child: _buildTabela()),
            _buildResumo(),
          ],
        ),
      ),
    );
  }

  Widget _buildResumo() {
    final saldoFinal = _dadosFicticios.last['saldo_final'] as double;
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
          _buildCampoResumo('Saldo Final Acumulado:', saldoFinal),
        ],
      ),
    );
  }

  Widget _buildCampoResumo(String label, double valor) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(
          _fmtMoeda(valor),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
        ),
      ],
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
            decoration: const BoxDecoration(
              color: Color(0xFF0D47A1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(9),
                topRight: Radius.circular(9),
              ),
            ),
            child: Row(
              children: [
                _th('Data',          _wData),
                _th('Base',          _wBase),
                _th('NF',            _wNF),
                _th('Forma de Pag.', _wFormaPag),
                _th('Produto',       _wProduto),
                _th('Qtd.',          _wQtd),
                _th('Entrada (R\$)', _wEntrada),
                _th('Total NF',      _wTotalNF),
                _th('Preço',         _wPreco),
                _th('Preço Tabela',  _wPrecoTab),
                _th('Dif. Preço',    _wDifPreco),
                _th('Saldo Final',   _wSaldo),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _th(String t, double w) {
    return Container(
      width: w,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        t,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
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
            itemCount: _dadosFicticios.length,
            itemBuilder: (context, i) {
              final e = _dadosFicticios[i];
              final dif = (e['dif_preco'] as num).toDouble();
              return Container(
                height: _hRow,
                color: i % 2 == 0 ? Colors.grey.shade50 : Colors.white,
                child: Row(
                  children: [
                    _cell(e['data'],                         _wData),
                    _cell(e['base'],                         _wBase),
                    _cell(e['nf'],                           _wNF),
                    _cell(e['forma_pag'],                    _wFormaPag),
                    _cell(e['produto'],                      _wProduto),
                    _cell(_fmtNum(e['qtd']),                 _wQtd),
                    _cell(_fmtMoeda(e['entrada']),           _wEntrada,  cor: Colors.green.shade700),
                    _cell(_fmtMoeda(e['total_nf']),          _wTotalNF),
                    _cell(_fmtPreco(e['preco']),             _wPreco),
                    _cell(_fmtPreco(e['preco_tabela']),      _wPrecoTab),
                    _cell(_fmtPreco(dif),                    _wDifPreco, cor: dif < 0 ? Colors.red : Colors.green.shade700),
                    _cell(_fmtMoeda(e['saldo_final']),       _wSaldo,    fw: FontWeight.bold),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _fmtNum(num v) {
    final s = v.toStringAsFixed(0);
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final r = s.length - i;
      b.write(s[i]);
      if (r > 1 && r % 3 == 1) b.write('.');
    }
    return b.toString();
  }

  String _fmtPreco(num v) {
    return 'R\$ ${v.abs().toStringAsFixed(2).replaceAll('.', ',')}${v < 0 ? ' (-)' : ''}';
  }

  Widget _cell(String t, double w, {Color? cor, FontWeight? fw}) {
    return Container(
      width: w,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        t,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: cor ?? Colors.grey.shade700, fontWeight: fw),
      ),
    );
  }
}
