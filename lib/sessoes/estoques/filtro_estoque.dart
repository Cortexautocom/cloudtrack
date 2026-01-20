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
  List<Map<String, String>> _produtosDisponiveis = [];
  bool _carregandoProdutos = false;
  // ignore: prefer_final_fields
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    // Inicializar mês atual como padrão
    _mesSelecionado = DateTime.now();
    // Carregar produtos disponíveis
    _carregarProdutosDisponiveis();
  }

  Future<void> _carregarProdutosDisponiveis() async {
    setState(() => _carregandoProdutos = true);
    
    try {
      // ALTERAÇÃO: Consultar diretamente a tabela de produtos
      // para obter TODOS os produtos do sistema
      final dados = await _supabase
          .from('produtos')  // ← Mudado de 'movimentacoes' para 'produtos'
          .select('id, nome')  // ← Seleciona apenas id e nome
          .order('nome');  // ← Ordena por nome
      
      setState(() {
        // Adicionar opção "<selecione>" no início
        _produtosDisponiveis = [
          {'id': '', 'nome': '<selecione>'}
        ];
        
        // Adicionar TODOS os produtos da tabela
        for (var produto in dados) {
          if (produto['id'] != null && produto['nome'] != null) {
            _produtosDisponiveis.add({
              'id': produto['id'].toString(),
              'nome': produto['nome'].toString(),
            });
          }
        }
        
        // Por padrão, seleciona "<selecione>" (valor vazio)
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

  void _irParaEstoqueMes() {
    if (_mesSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione um mês.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Verificar se um produto foi selecionado
    if (_produtoSelecionado == null || _produtoSelecionado!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione um produto.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Chamar o callback passado pelo pai
    widget.onConsultarEstoque(
      filialId: widget.filialId,
      nomeFilial: widget.nomeFilial,
      empresaId: widget.empresaId,
      mesFiltro: _mesSelecionado,
      produtoFiltro: _produtoSelecionado,
    );
  }

  void _resetarFiltros() {
    setState(() {
      _mesSelecionado = DateTime.now();
      _produtoSelecionado = '';
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
            Text(
              'Filtros de Estoque',
              style: const TextStyle(
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
          // FILTROS EM LINHA
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filtros de Consulta',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Linha com os dois filtros
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Filtro de Mês
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Mês de referência *',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => _selecionarMes(context),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.white,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _mesSelecionado != null
                                        ? '${_mesSelecionado!.month.toString().padLeft(2, '0')}/${_mesSelecionado!.year}'
                                        : 'Selecione o mês',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const Icon(Icons.calendar_today, color: Colors.grey, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Filtro de Produto
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Produto *',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_carregandoProdutos)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.white,
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF0D47A1),
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.white,
                                ),
                                child: DropdownButton<String>(
                                  value: _produtoSelecionado,
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                  icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                  onChanged: (String? novoValor) {
                                    setState(() {
                                      _produtoSelecionado = novoValor;
                                    });
                                  },
                                  items: _produtosDisponiveis.map<DropdownMenuItem<String>>((produto) {
                                    return DropdownMenuItem<String>(
                                      value: produto['id']!,
                                      child: Text(
                                        produto['nome']!,
                                        style: TextStyle(
                                          color: produto['id']!.isEmpty ? Colors.grey : Colors.black87,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // RESUMO DOS FILTROS EM LINHA
          Card(
            elevation: 1,
            color: Colors.grey[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resumo dos filtros:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Itens do resumo em linha
                  Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      _buildItemResumoLinha(
                        'Filial:',
                        widget.nomeFilial,
                        Icons.store,
                      ),
                      if (widget.empresaNome != null)
                        _buildItemResumoLinha(
                          'Empresa:',
                          widget.empresaNome!,
                          Icons.business,
                        ),
                      _buildItemResumoLinha(
                        'Mês:',
                        _mesSelecionado != null
                          ? '${_mesSelecionado!.month.toString().padLeft(2, '0')}/${_mesSelecionado!.year}'
                          : 'Não selecionado',
                        Icons.calendar_today,
                      ),
                      _buildItemResumoLinha(
                        'Produto:',
                        _produtoSelecionado != null && _produtoSelecionado!.isNotEmpty
                          ? _produtosDisponiveis
                              .firstWhere(
                                (prod) => prod['id'] == _produtoSelecionado,
                                orElse: () => {'id': '', 'nome': 'Não selecionado'}
                              )['nome']!
                          : 'Não selecionado',
                        Icons.inventory_2,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 30),
          
          // BOTÕES DE AÇÃO
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 200, // Largura máxima definida
                child: OutlinedButton(
                  onPressed: _resetarFiltros,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.refresh, size: 18),
                      SizedBox(width: 8),
                      Text('Redefinir'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 200, // Largura máxima definida
                child: ElevatedButton(
                  onPressed: _irParaEstoqueMes,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Consultar Estoque'),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // NOTAS
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Observações:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '• O mês de referência é obrigatório para a consulta.',
                  style: TextStyle(fontSize: 12, color: Color.fromARGB(255, 19, 96, 184)),
                ),
                Text(
                  '• A seleção de um produto é obrigatória para a consulta.',
                  style: TextStyle(fontSize: 12, color: Color.fromARGB(255, 19, 96, 184)),
                ),
                Text(
                  '• Os dados são atualizados automaticamente.',
                  style: TextStyle(fontSize: 12, color: Color.fromARGB(255, 19, 96, 184)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemResumoLinha(String titulo, String valor, IconData icone) {
    return Container(
      constraints: const BoxConstraints(minWidth: 200),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}