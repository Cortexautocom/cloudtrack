import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';

class FiltroEstoquePage extends StatefulWidget {
  final String? filialId;
  final String? terminalId;
  final String nomeFilial;
  final String? empresaId;
  final String? empresaNome;
  final Function({
    required String? filialId,
    required String? terminalId,
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
    this.filialId,
    this.terminalId,
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
  String? _filialSelecionadaId;
  String? _filialSelecionadaNome;
  String _tipoRelatorio = 'sintetico';
  List<Map<String, dynamic>> _produtosDisponiveis = [];
  List<Map<String, dynamic>> _filiaisDisponiveis = [];
  bool _carregandoProdutos = false;
  bool _carregandoFiliais = false;
  bool _carregando = false;
  bool _intraday = false;
  DateTime _dataSelecionada = DateTime.now();

  @override
  void initState() {
    super.initState();
    _mesSelecionado = DateTime.now();

    final usuario = UsuarioAtual.instance;
    // Inicializar filial a partir do usuário logado (filial_id é opcional para todos os níveis)
    _filialSelecionadaId = usuario?.filialId ?? '';

    _carregarFiliaisDisponiveis();
    _carregarProdutosDisponiveis();
  }

  Future<void> _carregarFiliaisDisponiveis() async {
    setState(() => _carregandoFiliais = true);

    try {
      // Buscar TODAS as filiais sem filtro de empresa_id (nível 4 precisa ver todas)
      final dados = await _supabase
          .from('filiais')
          .select('id, nome, nome_dois')
          .order('nome');

      final List<Map<String, dynamic>> filiais = [];
      for (var filial in dados) {
        final nome = filial['nome_dois'] ?? filial['nome'] ?? '';
        filiais.add({
          'id': filial['id'].toString(),
          'nome': nome.toString(),
        });
      }

      setState(() {
        _filiaisDisponiveis = [
          {'id': '', 'nome': '<selecione>'}
        ];
        _filiaisDisponiveis.addAll(filiais);

        // Se o usuário tem filial_id pré-selecionada, capturar o nome correspondente
        if (_filialSelecionadaId != null && _filialSelecionadaId!.isNotEmpty) {
          final filialEncontrada = filiais.firstWhere(
            (f) => f['id'] == _filialSelecionadaId,
            orElse: () => {'id': '', 'nome': ''},
          );
          if (filialEncontrada['id']!.isNotEmpty) {
            _filialSelecionadaNome = filialEncontrada['nome'];
          } else {
            // filial_id do usuário não encontrada na lista, resetar
            _filialSelecionadaId = '';
            _filialSelecionadaNome = null;
          }
        } else {
          // Usuário não possui filial: pré-selecionar a primeira filial disponível (mantendo editável)
          if (filiais.isNotEmpty) {
            _filialSelecionadaId = filiais.first['id'];
            _filialSelecionadaNome = filiais.first['nome'];
          } else {
            _filialSelecionadaId = '';
            _filialSelecionadaNome = null;
          }
        }
      });
    } catch (e) {
      debugPrint('❌ Erro ao carregar filiais: $e');
      setState(() {
        _filiaisDisponiveis = [
          {'id': '', 'nome': '<selecione>'}
        ];
      });
    } finally {
      setState(() => _carregandoFiliais = false);
    }
  }

  Future<void> _carregarProdutosDisponiveis({bool incluirTodos = false}) async {
    setState(() => _carregandoProdutos = true);
    
    try {
      debugPrint('🔍 Carregando produtos (incluirTodos: $incluirTodos)...');
      
      // Buscar apenas id e nome de todos os produtos, sem qualquer filtro
      final dados = await _supabase
          .from('produtos')
          .select('id, nome')
          .order('nome');

      debugPrint('📊 Produtos encontrados: ${dados.length}');

      final List<Map<String, dynamic>> produtos = [];
      
      // Adicionar "Todos os produtos" apenas no modo intraday
      if (incluirTodos) {
        produtos.add({'id': 'todos', 'nome': 'Todos os produtos'});
      }
      
      produtos.add({'id': '', 'nome': '<selecione>'});
      
      for (var produto in dados) {
        produtos.add({
          'id': produto['id'].toString(),
          'nome': produto['nome'].toString(),
        });
      }

      setState(() {
        _produtosDisponiveis = produtos;
        _produtoSelecionado = '';
      });
      
      debugPrint('✅ Produtos carregados: ${_produtosDisponiveis.length - 1} itens');
      
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

    // Validar: "Todos os produtos" só é permitido no modo intraday
    if (!_intraday && _produtoSelecionado == 'todos') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A opção "Todos os produtos" só está disponível no modo Intraday.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final String? filialToPass = (_filialSelecionadaId != null && _filialSelecionadaId!.isNotEmpty)
        ? _filialSelecionadaId
        : null;

    widget.onConsultarEstoque(
      filialId: filialToPass,
      terminalId: widget.terminalId,
      nomeFilial: _filialSelecionadaNome ?? 'Filial não selecionada',
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
    // Recarregar produtos sem opção "Todos" (modo mensal)
    _carregarProdutosDisponiveis(incluirTodos: false);
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
                  final novoIntraday = value ?? false;
                  // Se estava com "Todos" selecionado e desmarcou intraday, resetar produto
                  if (!novoIntraday && _produtoSelecionado == 'todos') {
                    _produtoSelecionado = '';
                  }
                  setState(() {
                    _intraday = novoIntraday;
                  });
                  // Recarregar lista de produtos com a regra correta
                  _carregarProdutosDisponiveis(incluirTodos: novoIntraday);
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
              // Campo Filial
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filial',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_carregandoFiliais)
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
                            value: _filialSelecionadaId,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, size: 20),
                            style: const TextStyle(fontSize: 13, color: Colors.black),
                            onChanged: (String? novoValor) {
                              setState(() {
                                _filialSelecionadaId = novoValor;
                                // Capturar o nome da filial selecionada
                                if (novoValor != null && novoValor.isNotEmpty) {
                                  final filial = _filiaisDisponiveis.firstWhere(
                                    (f) => f['id'] == novoValor,
                                    orElse: () => {'id': '', 'nome': ''},
                                  );
                                  _filialSelecionadaNome = filial['nome'];
                                } else {
                                  _filialSelecionadaNome = null;
                                }
                              });
                            },
                            items: _filiaisDisponiveis.map<DropdownMenuItem<String>>((filial) {
                              return DropdownMenuItem<String>(
                                value: filial['id']!,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    filial['nome']!,
                                    style: TextStyle(
                                      color: filial['id']!.isEmpty
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
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.grey.shade400,
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
                                color: Colors.black,
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
                label: widget.terminalId != null ? 'Terminal' : 'Filial',
                value: _filialSelecionadaNome ?? 'Não selecionada',
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