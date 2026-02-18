import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'nova_transf.dart';

// ==============================================================
//                PÁGINA DE TRANSFERÊNCIAS
// ==============================================================
class TransferenciasPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const TransferenciasPage({super.key, required this.onVoltar});

  @override
  State<TransferenciasPage> createState() => _TransferenciasPageState();
}

class _TransferenciasPageState extends State<TransferenciasPage> {
  bool carregando = true;

  // Lista do dia (bloco 1)
  List<Map<String, dynamic>> transferenciasHoje = [];

  // Lista histórica paginada (bloco 2)
  List<Map<String, dynamic>> transferenciasHistorico = [];

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalHeaderControllerHoje = ScrollController();
  final ScrollController _horizontalBodyControllerHoje = ScrollController();
  final ScrollController _horizontalHeaderControllerHist = ScrollController();
  final ScrollController _horizontalBodyControllerHist = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  // Paginação histórico
  int _paginaAtual = 1;
  final int _porPagina = 50;
  bool _temMaisPaginas = true;
  bool _carregandoHistorico = false;

  @override
  void initState() {
    super.initState();
    carregarHoje();
    carregarHistorico(reset: true);

    // Sincroniza rolagem horizontal do bloco HOJE
    _horizontalHeaderControllerHoje.addListener(() {
      if (_horizontalBodyControllerHoje.hasClients &&
          _horizontalBodyControllerHoje.offset !=
              _horizontalHeaderControllerHoje.offset) {
        _horizontalBodyControllerHoje
            .jumpTo(_horizontalHeaderControllerHoje.offset);
      }
    });

    _horizontalBodyControllerHoje.addListener(() {
      if (_horizontalHeaderControllerHoje.hasClients &&
          _horizontalHeaderControllerHoje.offset !=
              _horizontalBodyControllerHoje.offset) {
        _horizontalHeaderControllerHoje
            .jumpTo(_horizontalBodyControllerHoje.offset);
      }
    });

    // Sincroniza rolagem horizontal do bloco HISTÓRICO
    _horizontalHeaderControllerHist.addListener(() {
      if (_horizontalBodyControllerHist.hasClients &&
          _horizontalBodyControllerHist.offset !=
              _horizontalHeaderControllerHist.offset) {
        _horizontalBodyControllerHist
            .jumpTo(_horizontalHeaderControllerHist.offset);
      }
    });

    _horizontalBodyControllerHist.addListener(() {
      if (_horizontalHeaderControllerHist.hasClients &&
          _horizontalHeaderControllerHist.offset !=
              _horizontalBodyControllerHist.offset) {
        _horizontalHeaderControllerHist
            .jumpTo(_horizontalBodyControllerHist.offset);
      }
    });
  }

  @override
  void dispose() {
    _horizontalHeaderControllerHoje.dispose();
    _horizontalBodyControllerHoje.dispose();
    _horizontalHeaderControllerHist.dispose();
    _horizontalBodyControllerHist.dispose();
    _verticalScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  DateTime _inicioHoje() {
    final agora = DateTime.now();
    return DateTime(agora.year, agora.month, agora.day);
  }

  DateTime _fimHoje() {
    final agora = DateTime.now();
    return DateTime(agora.year, agora.month, agora.day, 23, 59, 59);
  }

  Future<void> carregarHoje() async {
    setState(() => carregando = true);

    try {
      final supabase = Supabase.instance.client;
      final inicio = _inicioHoje().toIso8601String();
      final fim = _fimHoje().toIso8601String();

      final response = await supabase
          .from("movimentacoes")
          .select('''
            *,
            motoristas!motorista_id(nome),
            produtos!produto_id(nome),
            transportadoras!transportadora_id(nome_dois),
            origem_filial:filiais!filial_origem_id(nome_dois),
            destino_filial:filiais!filial_destino_id(nome_dois)
          ''')
          .eq("tipo_op", "transf")
          .gte("data_mov", inicio)
          .lte("data_mov", fim)
          .order("data_mov", ascending: false);

      setState(() {
        transferenciasHoje = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint("Erro ao carregar transferencias de hoje: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar transferências de hoje: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => carregando = false);
    }
  }

  Future<void> carregarHistorico({bool reset = false}) async {
    if (_carregandoHistorico) return;

    if (reset) {
      _paginaAtual = 1;
      _temMaisPaginas = true;
      transferenciasHistorico.clear();
    }

    if (!_temMaisPaginas) return;

    setState(() => _carregandoHistorico = true);

    try {
      final supabase = Supabase.instance.client;
      final from = (_paginaAtual - 1) * _porPagina;
      final to = from + _porPagina - 1;

      final response = await supabase
          .from("movimentacoes")
          .select('''
            *,
            motoristas!motorista_id(nome),
            produtos!produto_id(nome),
            transportadoras!transportadora_id(nome_dois),
            origem_filial:filiais!filial_origem_id(nome_dois),
            destino_filial:filiais!filial_destino_id(nome_dois)
          ''')
          .eq("tipo_op", "transf")
          .order("data_mov", ascending: true)
          .range(from, to);

      final novos = List<Map<String, dynamic>>.from(response);

      setState(() {
        transferenciasHistorico.addAll(novos);
        _temMaisPaginas = novos.length == _porPagina;
        if (_temMaisPaginas) _paginaAtual++;
      });
    } catch (e) {
      debugPrint("Erro ao carregar histórico: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar histórico: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _carregandoHistorico = false);
      }
    }
  }

  List<Map<String, dynamic>> _filtrar(List<Map<String, dynamic>> lista) {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) return lista;

    return lista.where((t) {
      return (t['descricao']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['placa']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['data_mov']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['quantidade']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['motoristas']?['nome']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['produtos']?['nome']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['transportadoras']?['nome_dois']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['origem_filial']?['nome_dois']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['destino_filial']?['nome_dois']?.toString().toLowerCase() ?? '').contains(query);
    }).toList();
  }

  String _extrairPrimeiraPlaca(dynamic placaData) {
    if (placaData == null) return "";
    if (placaData is List && placaData.isNotEmpty) return placaData.first.toString();
    if (placaData is String) return placaData;
    return placaData.toString();
  }

  String _extrairPlacaPorIndex(dynamic placaData, int index) {
    if (placaData == null) return "";
    if (placaData is List && placaData.length > index) {
      return placaData[index].toString();
    }
    return "";
  }

  String _formatarQuantidade(String quantidade) {
    try {
      final apenasNumeros = quantidade.replaceAll(RegExp(r'[^\d]'), '');
      if (apenasNumeros.isEmpty) return '';
      final valor = int.parse(apenasNumeros);
      if (valor == 0) return '';
      if (valor > 999) {
        final parteMilhar = (valor ~/ 1000).toString();
        final parteCentena = (valor % 1000).toString().padLeft(3, '0');
        return '$parteMilhar.$parteCentena';
      }
      return valor.toString();
    } catch (_) {
      return quantidade;
    }
  }

  Widget _buildTabela(
    String titulo,
    List<Map<String, dynamic>> dados, {
    required ScrollController headerController,
    required ScrollController bodyController,
    bool paginacao = false,
  }) {
    final lista = _filtrar(dados);

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    titulo,
                    style:
                        const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  if (paginacao)
                    IconButton(
                      icon: const Icon(Icons.more_horiz),
                      tooltip: 'Carregar mais',
                      onPressed: _temMaisPaginas && !_carregandoHistorico
                          ? () => carregarHistorico()
                          : null,
                    ),
                ],
              ),
            ),
            if (lista.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Nenhuma transferência encontrada',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            else
              Column(
                children: [
                  Scrollbar(
                    controller: headerController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: headerController,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: 1350,
                        child: Container(
                          height: 40,
                          color: const Color(0xFF0D47A1),
                          child: Row(
                            children: [
                              _th("Data", 80),
                              _th("Placa", 100),
                              _th("Motorista", 140),
                              _th("Produto", 120),
                              _th("Qtd", 80),
                              _th("Transportadora", 140),
                              _th("Cavalo", 100),
                              _th("Reboq. 1", 100),
                              _th("Reboq. 2", 100),
                              _th("Origem", 140),
                              _th("Destino", 140),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Scrollbar(
                    controller: bodyController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: bodyController,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: 1350,
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: lista.length,
                          itemBuilder: (context, index) {
                            final t = lista[index];
                            final data = t['data_mov'] is String
                                ? DateTime.parse(t['data_mov'])
                                : (t['data_mov'] is DateTime
                                    ? t['data_mov']
                                    : DateTime.now());

                            final motoristaNome =
                                t['motoristas']?['nome']?.toString() ?? '';
                            final produtoNome =
                                t['produtos']?['nome']?.toString() ?? '';
                            final transportadoraNome =
                                t['transportadoras']?['nome_dois']?.toString() ??
                                    '';
                            final origemNome =
                                t['origem_filial']?['nome_dois']?.toString() ??
                                    '';
                            final destinoNome =
                                t['destino_filial']?['nome_dois']?.toString() ??
                                    '';

                            final quantidade = t['quantidade']?.toString() ?? '';
                            final quantidadeFormatada =
                                quantidade.isNotEmpty && quantidade != '0'
                                    ? _formatarQuantidade(quantidade)
                                    : '';

                            return Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: index % 2 == 0
                                    ? Colors.grey.shade50
                                    : Colors.white,
                                border: Border(
                                  bottom: BorderSide(
                                      color: Colors.grey.shade200, width: 0.5),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _cell(
                                      '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}',
                                      80),
                                  _cell(_extrairPrimeiraPlaca(t['placa']), 100),
                                  _cell(motoristaNome, 140),
                                  _cell(produtoNome, 120),
                                  _cell(quantidadeFormatada, 80,
                                      isNumber: true),
                                  _cell(transportadoraNome, 140),
                                  _cell(_extrairPlacaPorIndex(t['placa'], 0), 100),
                                  _cell(_extrairPlacaPorIndex(t['placa'], 1), 100),
                                  _cell(_extrairPlacaPorIndex(t['placa'], 2), 100),
                                  _cell(origemNome, 140),
                                  _cell(destinoNome, 140),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Container(
                    height: 32,
                    color: Colors.grey.shade100,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${lista.length} transferência(s)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
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

  Widget _cell(String texto, double largura, {bool isNumber = false}) {
    return Container(
      width: largura,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      child: Text(
        texto.isNotEmpty ? texto : '-',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade700,
          fontWeight: isNumber ? FontWeight.w600 : FontWeight.normal,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  void _mostrarDialogNovaTransferencia() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const NovaTransferenciaDialog(),
    );

    if (result == true) {
      await carregarHoje();
      await carregarHistorico(reset: true);
    }
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
              icon: Icon(Icons.clear, color: Colors.grey.shade600, size: 20),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Transferências entre filiais"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onVoltar,
        ),
        actions: [
          Container(
            width: 300,
            margin: const EdgeInsets.only(right: 16),
            child: _buildSearchField(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await carregarHoje();
              await carregarHistorico(reset: true);
            },
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              controller: _verticalScrollController,
              children: [
                _buildTabela(
                  "Transferências de hoje",
                  transferenciasHoje,
                  headerController: _horizontalHeaderControllerHoje,
                  bodyController: _horizontalBodyControllerHoje,
                ),

                const SizedBox(height: 30),

                _buildTabela(
                  "Transferências entre filiais - Histórico",
                  transferenciasHistorico,
                  headerController: _horizontalHeaderControllerHist,
                  bodyController: _horizontalBodyControllerHist,
                  paginacao: true,
                ),
                if (_carregandoHistorico)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarDialogNovaTransferencia,
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
