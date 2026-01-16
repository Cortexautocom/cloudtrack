import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MovimentacoesPage extends StatefulWidget {
  final String filialId; // 'todas' ou uuid
  final DateTime dataInicio;
  final DateTime dataFim;
  final String produtoId; // 'todos' ou uuid
  final String tipoMov;   // 'todos' | 'entrada' | 'saida'
  final String tipoOp;    // 'todos' | 'venda' | 'transf'

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
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalHeaderController = ScrollController();
  final ScrollController _horizontalBodyController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

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

      final response = await supabase
          .from("movimentacoes")
          .select('''
            *,
            produtos!produto_id(nome)
          ''')
          .gte("data_mov",
              widget.dataInicio.toIso8601String().split('T')[0])
          .lte("data_mov",
              widget.dataFim.toIso8601String().split('T')[0])
          .order("ts_mov", ascending: true);

      List<Map<String, dynamic>> lista =
          List<Map<String, dynamic>>.from(response);

      lista = lista.where((m) {
        if (widget.filialId != 'todas' &&
            m['filial_id'] != widget.filialId) return false;

        if (widget.produtoId != 'todos' &&
            m['produto_id'] != widget.produtoId) return false;

        if (widget.tipoMov != 'todos' &&
            m['tipo_mov'] != widget.tipoMov) return false;

        if (widget.tipoOp != 'todos' &&
            m['tipo_op'] != widget.tipoOp) return false;

        return true;
      }).toList();

      setState(() {
        movimentacoes = lista;
      });
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
              .contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Movimentações"),
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
          : _movimentacoesFiltradas.isEmpty
              ? _buildVazio()
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

  Widget _buildVazio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Nenhuma movimentação encontrada',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabelaConteudo() {
    return Scrollbar(
      controller: _verticalScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalScrollController,
        child: Column(
          children: [
            // CABEÇALHO
            Scrollbar(
              controller: _horizontalHeaderController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _horizontalHeaderController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 600,
                  child: Container(
                    height: 40,
                    color: const Color(0xFF0D47A1),
                    child: Row(
                      children: [
                        _th("Data", 120),
                        _th("Produto", 200),
                        _th("Descrição", 200),
                        _th("Quantidade", 80),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // CORPO
            Scrollbar(
              controller: _horizontalBodyController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _horizontalBodyController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 600,
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics:
                        const NeverScrollableScrollPhysics(),
                    itemCount:
                        _movimentacoesFiltradas.length,
                    itemBuilder: (context, index) {
                      final m =
                          _movimentacoesFiltradas[index];

                      final data = m['data_mov'] is String
                          ? DateTime.parse(m['data_mov'])
                          : m['data_mov'];

                      final produtoNome =
                          m['produtos']?['nome']?.toString() ?? '';

                      final quantidade =
                          m['quantidade']?.toString() ?? '';

                      return Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: index % 2 == 0
                              ? Colors.grey.shade50
                              : Colors.white,
                          border: Border(
                            bottom: BorderSide(
                                color:
                                    Colors.grey.shade200,
                                width: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            _cell(
                                '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}',
                                120),
                            _cell(produtoNome, 200),
                            _cell(
                                m['descricao']?.toString() ??
                                    '',
                                200),
                            _cell(quantidade, 80,
                                isNumber: true),
                          ],
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              child: Text(
                '${_movimentacoesFiltradas.length} movimentação(ões)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
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

  Widget _cell(String texto, double largura,
      {bool isNumber = false}) {
    return Container(
      width: largura,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      child: Text(
        texto.isNotEmpty ? texto : '-',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade700,
          fontWeight:
              isNumber ? FontWeight.w600 : FontWeight.normal,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
