import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';

class FiltroEstoqueProdutoPage extends StatefulWidget {
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
    DateTime? dataFiltro,
    required String produtoId,
    required String produtoNome,
    required bool isIntraday,
  }) onConsultarEstoqueProduto;
  final VoidCallback onVoltar;

  const FiltroEstoqueProdutoPage({
    super.key,
    this.filialId,
    this.terminalId,
    required this.nomeFilial,
    this.empresaId,
    this.empresaNome,
    required this.onConsultarEstoqueProduto,
    required this.onVoltar,
  });

  @override
  State<FiltroEstoqueProdutoPage> createState() => _FiltroEstoqueProdutoPageState();
}

class _FiltroEstoqueProdutoPageState extends State<FiltroEstoqueProdutoPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  DateTime? _dataSelecionada;
  String? _produtoSelecionadoId;
  String? _produtoSelecionadoNome;
  String? _filialSelecionadaId;
  String? _filialSelecionadaNome;
  String? _terminalSelecionadoId;
  String? _terminalSelecionadoNome;
  List<Map<String, dynamic>> _produtosDisponiveis = [];
  List<Map<String, dynamic>> _filiaisDisponiveis = [];
  List<Map<String, dynamic>> _terminaisDisponiveis = [];
  bool _carregandoProdutos = false;
  bool _carregandoFiliais = false;
  bool _carregandoTerminais = false;
  bool _intraday = true; // Sempre true para estoque por produto
  bool _terminalVinculado = false; // Indica se o usuário tem terminal fixo

  @override
  void initState() {
    super.initState();
    _dataSelecionada = DateTime.now();

    final usuario = UsuarioAtual.instance;
    
    // Verificar se usuário tem terminal vinculado no login
    if (usuario?.terminalId != null && usuario!.terminalId!.isNotEmpty) {
      _terminalVinculado = true;
      _terminalSelecionadoId = usuario.terminalId;
      _terminalSelecionadoNome = usuario.terminalNome ?? 'Terminal vinculado';
    }
    
    // Inicializar filial a partir do usuário logado
    _filialSelecionadaId = usuario?.filialId ?? '';

    _carregarFiliaisDisponiveis();
    _carregarTerminaisDisponiveis();
    _carregarProdutosDisponiveis();
  }

  Future<void> _carregarFiliaisDisponiveis() async {
    setState(() => _carregandoFiliais = true);

    try {
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
            _filialSelecionadaId = '';
            _filialSelecionadaNome = null;
          }
        } else {
          // Usuário não possui filial: pré-selecionar a primeira filial disponível
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

  Future<void> _carregarTerminaisDisponiveis() async {
    // Se usuário já tem terminal vinculado, não precisa carregar lista
    if (_terminalVinculado) {
      setState(() {
        _terminaisDisponiveis = [
          {'id': _terminalSelecionadoId!, 'nome': _terminalSelecionadoNome!}
        ];
      });
      return;
    }

    setState(() => _carregandoTerminais = true);

    try {
      final usuario = UsuarioAtual.instance;
      if (usuario == null) {
        setState(() {
          _terminaisDisponiveis = [
            {'id': '', 'nome': '<usuário não logado>'}
          ];
        });
        return;
      }

      // Buscar empresa_id do usuário
      String? empresaId = usuario.empresaId;
      
      // Se não tiver empresa_id no usuário, tentar usar o do parâmetro
      if (empresaId == null || empresaId.isEmpty) {
        empresaId = widget.empresaId;
      }

      if (empresaId == null || empresaId.isEmpty) {
        debugPrint('⚠️ Empresa ID não disponível para buscar terminais');
        setState(() {
          _terminaisDisponiveis = [
            {'id': '', 'nome': '<empresa não identificada>'}
          ];
        });
        return;
      }

      debugPrint('🔍 Buscando terminais para empresa: $empresaId');

      // Buscar terminais através da tabela relacoes_terminais
      final relacoes = await _supabase
          .from('relacoes_terminais')
          .select('''
            terminal_id,
            terminais!inner (
              id,
              nome
            )
          ''')
          .eq('empresa_id', empresaId);

      debugPrint('📊 Relações encontradas: ${relacoes.length}');

      final Map<String, Map<String, dynamic>> terminaisUnicos = {};
      
      for (var relacao in relacoes) {
        if (relacao['terminais'] != null) {
          final terminal = relacao['terminais'] as Map<String, dynamic>;
          final terminalId = terminal['id']?.toString();
          
          if (terminalId != null && !terminaisUnicos.containsKey(terminalId)) {
            terminaisUnicos[terminalId] = {
              'id': terminalId,
              'nome': terminal['nome']?.toString() ?? 'Terminal sem nome',
            };
          }
        }
      }

      List<Map<String, dynamic>> terminais = terminaisUnicos.values.toList()
        ..sort((a, b) => (a['nome'] ?? '').compareTo(b['nome'] ?? ''));

      debugPrint('✅ Terminais encontrados: ${terminais.length}');

      final List<Map<String, dynamic>> listaFinal = [];
      listaFinal.add({'id': '', 'nome': '<selecione>'});
      listaFinal.addAll(terminais);

      setState(() {
        _terminaisDisponiveis = listaFinal;
        // Se só tiver um terminal disponível, pré-selecionar automaticamente
        if (terminais.length == 1) {
          _terminalSelecionadoId = terminais.first['id'];
          _terminalSelecionadoNome = terminais.first['nome'];
        } else {
          _terminalSelecionadoId = '';
          _terminalSelecionadoNome = null;
        }
      });

    } catch (e) {
      debugPrint('❌ Erro ao carregar terminais: $e');
      setState(() {
        _terminaisDisponiveis = [
          {'id': '', 'nome': '<erro ao carregar terminais>'}
        ];
        _terminalSelecionadoId = '';
      });
    } finally {
      setState(() => _carregandoTerminais = false);
    }
  }

  Future<void> _carregarProdutosDisponiveis() async {
    setState(() => _carregandoProdutos = true);
    
    try {
      // Buscar todos os produtos ativos
      final response = await _supabase
          .from('produtos')
          .select('id, nome')
          .eq('ativo', true)
          .order('nome');
      
      List<Map<String, dynamic>> produtos = [];
      for (var produto in response) {
        produtos.add({
          'id': produto['id'].toString(),
          'nome': produto['nome']?.toString() ?? 'Produto sem nome',
        });
      }
      
      final List<Map<String, dynamic>> listaFinal = [];
      listaFinal.add({'id': '', 'nome': '<selecione>'});
      listaFinal.addAll(produtos);
      
      setState(() {
        _produtosDisponiveis = listaFinal;
        _produtoSelecionadoId = '';
        _produtoSelecionadoNome = null;
      });
      
    } catch (e) {
      debugPrint('❌ Erro ao carregar produtos: $e');
      setState(() {
        _produtosDisponiveis = [
          {'id': '', 'nome': '<erro ao carregar produtos>'}
        ];
        _produtoSelecionadoId = '';
      });
    } finally {
      setState(() => _carregandoProdutos = false);
    }
  }

  Future<void> _selecionarData(BuildContext context) async {
    final DateTime? selecionado = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Selecione a data',
      fieldLabelText: 'Data de referência',
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

  void _irParaEstoqueProduto() {
    // Validar campos obrigatórios
    if (_dataSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione uma data.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_produtoSelecionadoId == null || _produtoSelecionadoId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione um produto.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validar terminal
    if (_terminalSelecionadoId == null || _terminalSelecionadoId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione um terminal.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Obter nome do produto selecionado
    final produtoSelecionado = _produtosDisponiveis.firstWhere(
      (p) => p['id'] == _produtoSelecionadoId,
      orElse: () => {'id': '', 'nome': ''},
    );
    _produtoSelecionadoNome = produtoSelecionado['nome'];

    final String? filialToPass = (_filialSelecionadaId != null && _filialSelecionadaId!.isNotEmpty)
        ? _filialSelecionadaId
        : null;

    widget.onConsultarEstoqueProduto(
      filialId: filialToPass,
      terminalId: _terminalSelecionadoId,
      nomeFilial: _terminalSelecionadoNome ?? _filialSelecionadaNome ?? 'Terminal não selecionado',
      empresaId: widget.empresaId,
      dataFiltro: _dataSelecionada,
      produtoId: _produtoSelecionadoId!,
      produtoNome: _produtoSelecionadoNome!,
      isIntraday: true, // Sempre true para estoque por produto
    );
  }

  void _resetarFiltros() {
    setState(() {
      _dataSelecionada = DateTime.now();
      _produtoSelecionadoId = '';
      _produtoSelecionadoNome = null;
      
      // Se não tiver terminal vinculado, resetar também
      if (!_terminalVinculado) {
        _terminalSelecionadoId = '';
        _terminalSelecionadoNome = null;
      }
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
              'Estoque por Produto',
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
        child: _buildConteudo(),
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

          // Primeira linha: Filial e Terminal
          Row(
            children: [
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
                        height: 50,
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
                            itemHeight: 50,
                            icon: const Icon(Icons.arrow_drop_down, size: 20),
                            style: const TextStyle(fontSize: 13, color: Colors.black),
                            onChanged: (String? novoValor) {
                              setState(() {
                                _filialSelecionadaId = novoValor;
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

              // Campo Terminal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Terminal *',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                        if (_terminalVinculado) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.lock,
                            size: 14,
                            color: Colors.grey,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (_carregandoTerminais)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        height: 50,
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
                            value: _terminalSelecionadoId,
                            isExpanded: true,
                            itemHeight: 50,
                            icon: const Icon(Icons.arrow_drop_down, size: 20),
                            style: const TextStyle(fontSize: 13, color: Colors.black),
                            onChanged: _terminalVinculado 
                                ? null // Desabilitado se terminal vinculado
                                : (String? novoValor) {
                                    setState(() {
                                      _terminalSelecionadoId = novoValor;
                                      if (novoValor != null && novoValor.isNotEmpty) {
                                        final terminal = _terminaisDisponiveis.firstWhere(
                                          (t) => t['id'] == novoValor,
                                          orElse: () => {'id': '', 'nome': ''},
                                        );
                                        _terminalSelecionadoNome = terminal['nome'];
                                      } else {
                                        _terminalSelecionadoNome = null;
                                      }
                                    });
                                  },
                            items: _terminaisDisponiveis.map<DropdownMenuItem<String>>((terminal) {
                              return DropdownMenuItem<String>(
                                value: terminal['id']!,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    terminal['nome']!,
                                    style: TextStyle(
                                      color: terminal['id']!.isEmpty
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
            ],
          ),

          const SizedBox(height: 16),

          // Segunda linha: Data e Produto
          Row(
            children: [
              // Campo Data
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Data de referência *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _selecionarData(context),
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade400, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _dataSelecionada != null
                                  ? '${_dataSelecionada!.day.toString().padLeft(2, '0')}/${_dataSelecionada!.month.toString().padLeft(2, '0')}/${_dataSelecionada!.year}'
                                  : 'Selecione a data',
                              style: const TextStyle(fontSize: 13, color: Colors.black),
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
                        height: 50,
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
                            value: _produtoSelecionadoId,
                            isExpanded: true,
                            itemHeight: 50,
                            icon: const Icon(Icons.arrow_drop_down, size: 20),
                            style: const TextStyle(fontSize: 13, color: Colors.black),
                            onChanged: (String? novoValor) {
                              setState(() {
                                _produtoSelecionadoId = novoValor;
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
                value: _filialSelecionadaNome ?? 'Não selecionada',
              ),
              _buildItemResumo(
                icon: Icons.settings_input_component,
                label: 'Terminal',
                value: _terminalSelecionadoNome ?? 'Não selecionado',
              ),
              if (widget.empresaNome != null)
                _buildItemResumo(
                  icon: Icons.business,
                  label: 'Empresa',
                  value: widget.empresaNome!,
                ),
              _buildItemResumo(
                icon: Icons.calendar_today,
                label: 'Data',
                value: _dataSelecionada != null
                  ? '${_dataSelecionada!.day.toString().padLeft(2, '0')}/${_dataSelecionada!.month.toString().padLeft(2, '0')}/${_dataSelecionada!.year}'
                  : 'Não selecionada',
              ),
              _buildItemResumo(
                icon: Icons.inventory_2,
                label: 'Produto',
                value: _produtoSelecionadoId != null && _produtoSelecionadoId!.isNotEmpty
                  ? _produtosDisponiveis
                      .firstWhere(
                        (prod) => prod['id'] == _produtoSelecionadoId,
                        orElse: () => {'id': '', 'nome': 'Não selecionado'}
                      )['nome']!
                  : 'Não selecionado',
              ),
              _buildItemResumo(
                icon: Icons.access_time,
                label: 'Modo',
                value: 'Intraday (diário)',
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
          Icon(icon, size: 14, color: Colors.grey.shade600),
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
                    style: TextStyle(fontSize: 13, color: Color.fromARGB(255, 95, 95, 95)),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Botão Consultar
          SizedBox(
            width: 140,
            height: 36,
            child: ElevatedButton(
              onPressed: _irParaEstoqueProduto,
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
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
                  'Campos obrigatórios: Terminal, Data de referência e Produto',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _terminalVinculado
                    ? 'Terminal vinculado ao seu usuário (não pode ser alterado).'
                    : 'Mostra o estoque do produto no terminal selecionado na data informada.',
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