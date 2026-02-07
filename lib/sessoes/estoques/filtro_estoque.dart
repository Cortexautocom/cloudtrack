import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FiltroEstoquePage extends StatefulWidget {
  final String filialId;
  final String nomeFilial;
  final String? empresaId;
  final String? empresaNome;
  final Function({
    required String filialId,
    required String nomeFilial,
    String? empresaId,
    DateTime? mesFiltro,
    String? produtoFiltro,
    required String tipoRelatorio,
    required bool isIntraday,
    DateTime? dataIntraday,
  }) onConsultarEstoque;
  final VoidCallback onVoltar;

  const FiltroEstoquePage({
    super.key,
    required this.filialId,
    required this.nomeFilial,
    this.empresaId,
    this.empresaNome,
    required this.onConsultarEstoque,
    required this.onVoltar,
  });

  @override
  State<FiltroEstoquePage> createState() => _FiltroEstoquePageState();
}

class _FiltroEstoquePageState extends State<FiltroEstoquePage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  DateTime? _mesSelecionado;
  String? _produtoSelecionado;
  String _tipoRelatorio = 'sintetico';
  List<Map<String, dynamic>> _produtosDisponiveis = [];
  bool _carregandoProdutos = false;
  bool _carregando = false;
  bool _intraday = false;
  DateTime _dataSelecionada = DateTime.now();

  @override
  void initState() {
    super.initState();
    _mesSelecionado = DateTime.now();
    _carregarProdutosDisponiveis();
  }

  Future<void> _carregarProdutosDisponiveis() async {
    setState(() => _carregandoProdutos = true);
    
    try {
      final dados = await _supabase
          .from('produtos')
          .select('id, nome')
          .order('nome');
      
      final List<Map<String, dynamic>> produtos = [];
      for (var produto in dados) {
        produtos.add({
          'id': produto['id'].toString(),
          'nome': produto['nome'].toString(),
        });
      }
      
      final produtosOrdenados = _ordenarProdutosPorClasse(produtos);
      
      setState(() {
        _produtosDisponiveis = [
          {'id': '', 'nome': '<selecione>'}
        ];
        _produtosDisponiveis.addAll(produtosOrdenados);
        _produtoSelecionado = '';
      });
    } catch (e) {
      debugPrint("❌ Erro ao carregar produtos: $e");
      setState(() {
        _produtosDisponiveis = [
          {'id': '', 'nome': '<selecione>'}
        ];
        _produtoSelecionado = '';
      });
    } finally {
      setState(() => _carregandoProdutos = false);
    }
  }

  List<Map<String, dynamic>> _ordenarProdutosPorClasse(
    List<Map<String, dynamic>> produtos,
  ) {
    const ordemPorId = {
      '82c348c8-efa1-4d1a-953a-ee384d5780fc': 1,
      '93686e9d-6ef5-4f7c-a97d-b058b3c2c693': 2,
      'c77a6e31-52f0-4fe1-bdc8-685dff83f3a1': 3,
      '58ce20cf-f252-4291-9ef6-f4821f22c29e': 4,
      '66ca957a-5698-4a02-8c9e-987770b6a151': 5,
      'f8e95435-471a-424c-947f-def8809053a0': 6,
      '4da89784-301f-4abe-b97e-c48729969e3d': 7,
      '3c26a7e5-8f3a-4429-a8c7-2e0e72f1b80a': 8,
      'cecab8eb-297a-4640-81ae-e88335b88d8b': 9,
      'ecd91066-e763-42e3-8a0e-d982ea6da535': 10,
    };

    produtos.sort((a, b) {
      final idA = a['id'].toString().toLowerCase();
      final idB = b['id'].toString().toLowerCase();

      return (ordemPorId[idA] ?? 999)
          .compareTo(ordemPorId[idB] ?? 999);
    });

    return produtos;
  }

  Future<void> _selecionarMes(BuildContext context) async {
    final DateTime? selecionado = await showDatePicker(
      context: context,
      initialDate: _mesSelecionado ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Selecione o mês',
      fieldLabelText: 'Mês de referência',
      fieldHintText: 'MM/AAAA',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0D47A1),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0D47A1),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (selecionado != null) {
      setState(() {
        _mesSelecionado = DateTime(selecionado.year, selecionado.month);
      });
    }
  }

  Future<void> _selecionarDataIntraday(BuildContext context) async {
    final DateTime? selecionado = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Selecione a data',
      fieldLabelText: 'Data específica',
      fieldHintText: 'DD/MM/AAAA',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0D47A1),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0D47A1),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (selecionado != null) {
      setState(() {
        _dataSelecionada = selecionado;
      });
    }
  }

  void _irParaEstoqueMes() {
    // Validar mês apenas se não for intraday
    if (!_intraday && _mesSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione um mês.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_produtoSelecionado == null || _produtoSelecionado!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione um produto.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    widget.onConsultarEstoque(
      filialId: widget.filialId,
      nomeFilial: widget.nomeFilial,
      empresaId: widget.empresaId,
      mesFiltro: _intraday ? null : _mesSelecionado,
      produtoFiltro: _produtoSelecionado,
      tipoRelatorio: _tipoRelatorio,
      isIntraday: _intraday,
      dataIntraday: _intraday ? _dataSelecionada : null,
    );
  }

  void _resetarFiltros() {
    setState(() {
      _mesSelecionado = DateTime.now();
      _produtoSelecionado = '';
      _tipoRelatorio = 'sintetico';
      _intraday = false;
      _dataSelecionada = DateTime.now();
    });
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
              'Filtros de Estoque',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.nomeFilial,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
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
        child: _carregando
            ? _buildCarregando()
            : _buildConteudo(),
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
            'Carregando filtros...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildConteudo() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardFiltros(),
          const SizedBox(height: 20),
          _buildCardResumo(),
          const SizedBox(height: 20),
          _buildBotoes(),
          const SizedBox(height: 20),
          _buildNotas(),
        ],
      ),
    );
  }

  Widget _buildCardFiltros() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header do card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.filter_alt, color: const Color(0xFF0D47A1), size: 20),
                const SizedBox(width: 10),
                const Text(
                  'Filtros de Consulta',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0D47A1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Checkbox Intraday
          Row(
            children: [
              Checkbox(
                value: _intraday,
                onChanged: (value) {
                  setState(() {
                    _intraday = value ?? false;
                  });
                },
                activeColor: const Color(0xFF0D47A1),
              ),
              const Text(
                'Intraday (movimentações diárias)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF424242),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Linha com os filtros
          Row(
            children: [
              // Campo Mês de Referência ou Data Específica
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _intraday ? 'Data específica *' : 'Mês de referência *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _intraday ? Colors.grey : const Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: _intraday ? () => _selecionarDataIntraday(context) : () => _selecionarMes(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _intraday ? Colors.grey.shade100 : Colors.white,
                          border: Border.all(
                            color: _intraday ? Colors.grey.shade300 : Colors.grey.shade400,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _intraday
                                ? '${_dataSelecionada.day.toString().padLeft(2, '0')}/${_dataSelecionada.month.toString().padLeft(2, '0')}/${_dataSelecionada.year}'
                                : (_mesSelecionado != null
                                    ? '${_mesSelecionado!.month.toString().padLeft(2, '0')}/${_mesSelecionado!.year}'
                                    : 'Selecione o mês'),
                              style: TextStyle(
                                fontSize: 13,
                                color: _intraday ? Colors.grey.shade600 : Colors.black,
                              ),
                            ),
                            Icon(
                              Icons.calendar_today,
                              color: Colors.grey.shade600,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Campo Produto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Produto *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_carregandoProdutos)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade400, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: const Color(0xFF0D47A1),
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade400, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _produtoSelecionado,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, size: 20),
                            style: const TextStyle(fontSize: 13, color: Colors.black),
                            onChanged: (String? novoValor) {
                              setState(() {
                                _produtoSelecionado = novoValor;
                              });
                            },
                            items: _produtosDisponiveis.map<DropdownMenuItem<String>>((produto) {
                              return DropdownMenuItem<String>(
                                value: produto['id']!,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    produto['nome']!,
                                    style: TextStyle(
                                      color: produto['id']!.isEmpty 
                                          ? Colors.grey.shade600 
                                          : Colors.black,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Campo Tipo de Relatório
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tipo de relatório',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade400, width: 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _tipoRelatorio,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down, size: 20),
                          style: const TextStyle(fontSize: 13, color: Colors.black),
                          onChanged: (String? novoValor) {
                            setState(() {
                              _tipoRelatorio = novoValor!;
                            });
                          },
                          items: const [
                            DropdownMenuItem<String>(
                              value: 'sintetico',
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('Sintético'),
                              ),
                            ),
                            DropdownMenuItem<String>(
                              value: 'analitico',
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('Analítico'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardResumo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.summarize, color: const Color(0xFF0D47A1), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Resumo dos Filtros',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0D47A1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Grid de itens do resumo
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              _buildItemResumo(
                icon: Icons.store,
                label: 'Filial',
                value: widget.nomeFilial,
              ),
              if (widget.empresaNome != null)
                _buildItemResumo(
                  icon: Icons.business,
                  label: 'Empresa',
                  value: widget.empresaNome!,
                ),
              _buildItemResumo(
                icon: Icons.calendar_today,
                label: _intraday ? 'Data' : 'Mês',
                value: _intraday
                  ? '${_dataSelecionada.day.toString().padLeft(2, '0')}/${_dataSelecionada.month.toString().padLeft(2, '0')}/${_dataSelecionada.year}'
                  : (_mesSelecionado != null
                      ? '${_mesSelecionado!.month.toString().padLeft(2, '0')}/${_mesSelecionado!.year}'
                      : 'Não selecionado'),
              ),
              if (_intraday)
                _buildItemResumo(
                  icon: Icons.access_time,
                  label: 'Modo',
                  value: 'Intraday (diário)',
                ),
              _buildItemResumo(
                icon: Icons.inventory_2,
                label: 'Produto',
                value: _produtoSelecionado != null && _produtoSelecionado!.isNotEmpty
                  ? _produtosDisponiveis
                      .firstWhere(
                        (prod) => prod['id'] == _produtoSelecionado,
                        orElse: () => {'id': '', 'nome': 'Não selecionado'}
                      )['nome']!
                  : 'Não selecionado',
              ),
              _buildItemResumo(
                icon: Icons.assessment,
                label: 'Tipo de relatório',
                value: _tipoRelatorio == 'sintetico' ? 'Sintético' : 'Analítico',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemResumo({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return SizedBox(
      width: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 14,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotoes() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Botão Redefinir
          SizedBox(
            width: 140,
            height: 36,
            child: OutlinedButton(
              onPressed: _resetarFiltros,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                side: BorderSide(color: Colors.grey.shade400, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.refresh, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Redefinir',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color.fromARGB(255, 95, 95, 95),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Botão Consultar Estoque
          SizedBox(
            width: 140,
            height: 36,
            child: ElevatedButton(
              onPressed: _irParaEstoqueMes,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Consultar',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotas() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.orange.shade200, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.info, color: Colors.orange.shade700, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _intraday
                    ? 'Campos obrigatórios: Data específica e Produto'
                    : 'Campos obrigatórios: Mês de referência e Produto',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _intraday
                    ? 'Modo Intraday: mostra apenas movimentações da data selecionada.'
                    : 'O tipo de relatório determina o nível de detalhamento da consulta.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}