import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

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
  List<Map<String, dynamic>> transferencias = [];
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
          _horizontalBodyController.offset != _horizontalHeaderController.offset) {
        _horizontalBodyController.jumpTo(_horizontalHeaderController.offset);
      }
    });

    _horizontalBodyController.addListener(() {
      if (_horizontalHeaderController.hasClients &&
          _horizontalHeaderController.offset != _horizontalBodyController.offset) {
        _horizontalHeaderController.jumpTo(_horizontalBodyController.offset);
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
            motoristas!motorista_id(nome),
            produtos!produto_id(nome),
            transportadoras!transportadora_id(nome_dois),
            origem_filial:filiais!filial_origem_id(nome_dois),
            destino_filial:filiais!filial_destino_id(nome_dois)
          ''')
          .eq("tipo_op", "Transf")  // REMOVIDO: .eq("tipo_mov", "saida")
          .order("ts_mov", ascending: true);

      setState(() {
        transferencias = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint("Erro ao carregar transferencias: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar transferências: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => carregando = false);
    }
  }

  void _mostrarDialogNovaTransferencia() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const NovaTransferenciaDialog(),
    );

    if (result == true) {
      await carregar();
    }
  }

  List<Map<String, dynamic>> get _transferenciasFiltradas {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) return transferencias;

    return transferencias.where((t) {
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

  bool _isHoje(DateTime data) {
    final hoje = DateTime.now();
    return data.year == hoje.year &&
        data.month == hoje.month &&
        data.day == hoje.day;
  }

  String _extrairPrimeiraPlaca(dynamic placaData) {
    if (placaData == null) return "";
    
    if (placaData is String) {
      return placaData;
    }
    
    if (placaData is List && placaData.isNotEmpty) {
      return placaData.first.toString();
    }
    
    return placaData.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Transferências Entre Filiais"),
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
            onPressed: carregar,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : _transferenciasFiltradas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.swap_horiz, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhuma transferência encontrada',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Tente alterar os termos da pesquisa',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              : _buildTabelaConteudo(),
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

  Widget _buildTabelaConteudo() {
    
    return Scrollbar(
      controller: _verticalScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalScrollController,
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          child: Column(
            children: [
              // Cabeçalho da tabela com rolagem horizontal
              Scrollbar(
                controller: _horizontalHeaderController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontalHeaderController,
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
              
              // Conteúdo da tabela com rolagem horizontal
              Scrollbar(
                controller: _horizontalBodyController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontalBodyController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: 1350,
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _transferenciasFiltradas.length,
                      itemBuilder: (context, index) {
                        final t = _transferenciasFiltradas[index];
                        final data = t['data_mov'] is String
                            ? DateTime.parse(t['data_mov'])
                            : (t['data_mov'] is DateTime ? t['data_mov'] : DateTime.now());
                        final isHoje = _isHoje(data);
                        
                        // Extrair nomes das relações
                        final motoristaNome = t['motoristas']?['nome']?.toString() ?? '';
                        final produtoNome = t['produtos']?['nome']?.toString() ?? '';
                        final transportadoraNome = t['transportadoras']?['nome_dois']?.toString() ?? '';
                        final origemNome = t['origem_filial']?['nome_dois']?.toString() ?? '';
                        final destinoNome = t['destino_filial']?['nome_dois']?.toString() ?? '';
                        
                        // Formatar quantidade
                        final quantidade = t['quantidade']?.toString() ?? '';
                        final quantidadeFormatada = quantidade.isNotEmpty && quantidade != '0'
                            ? _formatarQuantidade(quantidade)
                            : '';
                        
                        return Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: index % 2 == 0 
                                ? Colors.grey.shade50 
                                : Colors.white,
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              _cell(
                                '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}',
                                80,
                                isHoje: isHoje,
                              ),
                              _cell(_extrairPrimeiraPlaca(t['placa']), 100, isHoje: isHoje),
                              _cell(motoristaNome, 140, isHoje: isHoje),
                              _cell(produtoNome, 120, isHoje: isHoje),
                              _cell(quantidadeFormatada, 80, isHoje: isHoje, isNumber: true),
                              _cell(transportadoraNome, 140, isHoje: isHoje),
                              _cell(t['cavalo']?.toString() ?? '', 100, isHoje: isHoje),
                              _cell(t['reboque1']?.toString() ?? '', 100, isHoje: isHoje),
                              _cell(t['reboque2']?.toString() ?? '', 100, isHoje: isHoje),
                              _cell(origemNome, 140, isHoje: isHoje),
                              _cell(destinoNome, 140, isHoje: isHoje),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              
              // Contador de resultados
              Container(
                height: 32,
                color: Colors.grey.shade100,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_transferenciasFiltradas.length} transferência(s)',
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

  Widget _cell(String texto, double largura, {required bool isHoje, bool isNumber = false}) {
    return Container(
      width: largura,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      child: Text(
        texto.isNotEmpty ? texto : '-',
        style: TextStyle(
          fontSize: 12,
          color: isHoje ? Colors.black : Colors.grey.shade700,
          fontWeight: isNumber ? FontWeight.w600 : FontWeight.normal,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _formatarQuantidade(String quantidade) {
    try {
      // Remove caracteres não numéricos
      final apenasNumeros = quantidade.replaceAll(RegExp(r'[^\d]'), '');
      if (apenasNumeros.isEmpty) return '';
      
      final valor = int.parse(apenasNumeros);
      if (valor == 0) return '';
      
      // Formata como 999.999
      if (valor > 999) {
        final parteMilhar = (valor ~/ 1000).toString();
        final parteCentena = (valor % 1000).toString().padLeft(3, '0');
        return '$parteMilhar.$parteCentena';
      }
      
      return valor.toString();
    } catch (e) {
      return quantidade;
    }
  }
}

// ==============================================================
//                COMPONENTE AUTOCOMPLETE MELHORADO
// ==============================================================
class AutocompleteField<T> extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final Future<List<T>> Function(String) buscarItens;
  final String Function(T) obterTextoExibicao;
  final String Function(T) obterId;
  final FocusNode? focusNode;
  final void Function(T)? onSelecionado;
  final bool Function(String)? validarParaBusca;

  const AutocompleteField({
    super.key,
    required this.controller,
    required this.label,
    required this.buscarItens,
    required this.obterTextoExibicao,
    required this.obterId,
    this.focusNode,
    this.onSelecionado,
    this.validarParaBusca,
  });

  @override
  State<AutocompleteField<T>> createState() => _AutocompleteFieldState<T>();
}

class _AutocompleteFieldState<T> extends State<AutocompleteField<T>> {
  final List<T> _sugestoes = [];
  bool _carregando = false;
  Timer? _debounceTimer;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final FocusNode _internalFocusNode = FocusNode();
  bool _mostrarLista = false;

  @override
  void initState() {
    super.initState();
    _internalFocusNode.addListener(_onFocusChanged);
    
    if (widget.focusNode != null) {
      widget.focusNode!.addListener(_onExternalFocusChanged);
    }
  }

  void _onExternalFocusChanged() {
    if (widget.focusNode!.hasFocus && !_internalFocusNode.hasFocus) {
      _internalFocusNode.requestFocus();
    } else if (!widget.focusNode!.hasFocus && _internalFocusNode.hasFocus) {
      _internalFocusNode.unfocus();
    }
  }

  void _onFocusChanged() {
    if (_internalFocusNode.hasFocus) {
      _mostrarLista = true;
      if (_sugestoes.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mostrarOverlay();
        });
      }
    } else {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_internalFocusNode.hasFocus) {
          _fecharOverlay();
          _mostrarLista = false;
        }
      });
    }
  }

  Future<void> _buscarItens(String texto) async {
    if (widget.validarParaBusca != null && !widget.validarParaBusca!(texto)) {
      setState(() {
        _sugestoes.clear();
      });
      _fecharOverlay();
      return;
    }

    setState(() {
      _carregando = true;
    });

    try {
      final itens = await widget.buscarItens(texto);

      setState(() {
        _sugestoes.clear();
        _sugestoes.addAll(itens);
        _carregando = false;
      });

      if (_sugestoes.isNotEmpty && _mostrarLista) {
        _mostrarOverlay();
      } else {
        _fecharOverlay();
      }
    } catch (e) {
      debugPrint('Erro ao buscar itens: $e');
      setState(() {
        _sugestoes.clear();
        _carregando = false;
      });
      _fecharOverlay();
    }
  }

  void _onTextChanged(String texto) {
    _debounceTimer?.cancel();
    
    if (widget.validarParaBusca != null && !widget.validarParaBusca!(texto)) {
      setState(() {
        _sugestoes.clear();
      });
      _fecharOverlay();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _buscarItens(texto);
      }
    });
  }

  void _onItemSelecionado(T item) {
    widget.controller.text = widget.obterTextoExibicao(item);
    setState(() {
      _sugestoes.clear();
    });
    _fecharOverlay();
    _internalFocusNode.unfocus();
    _mostrarLista = false;
    
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: widget.controller.text.length),
    );
    
    if (widget.onSelecionado != null) {
      widget.onSelecionado!(item);
    }
  }

  void _mostrarOverlay() {
    if (_sugestoes.isEmpty || _overlayEntry != null) return;

    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.3,
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _sugestoes.length,
                itemBuilder: (context, index) {
                  final item = _sugestoes[index];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _onItemSelecionado(item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: Text(
                          widget.obterTextoExibicao(item),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _fecharOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _fecharOverlay();
    _internalFocusNode.removeListener(_onFocusChanged);
    _internalFocusNode.dispose();
    
    if (widget.focusNode != null) {
      widget.focusNode!.removeListener(_onExternalFocusChanged);
    }
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: widget.controller,
            focusNode: _internalFocusNode,
            onChanged: _onTextChanged,
            decoration: InputDecoration(
              labelText: widget.label,
              counterText: '',
              hintText: '',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              suffixIcon: _carregando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ==============================================================
//                DIALOG DE NOVA TRANSFERÊNCIA
// ==============================================================

class NovaTransferenciaDialog extends StatefulWidget {
  const NovaTransferenciaDialog({super.key});

  @override
  State<NovaTransferenciaDialog> createState() => _NovaTransferenciaDialogState();
}

class _NovaTransferenciaDialogState extends State<NovaTransferenciaDialog> {
  DateTime _dataSelecionada = DateTime.now();
  bool _salvando = false;
  
  // Controllers para os campos
  final TextEditingController _motoristaController = TextEditingController();
  final TextEditingController _quantidadeController = TextEditingController();
  final TextEditingController _transportadoraController = TextEditingController();
  final TextEditingController _cavaloController = TextEditingController();
  final TextEditingController _reboque1Controller = TextEditingController();
  final TextEditingController _reboque2Controller = TextEditingController();
  
  // IDs para salvar no banco
  String? _motoristaId;
  String? _produtoId;
  String? _transportadoraId;
  String? _origemId;
  String? _destinoId;
  String? _empresaId;
  String? _usuarioId;
  
  // Listas para dropdowns
  List<Map<String, dynamic>> _produtos = [];
  List<Map<String, dynamic>> _filiais = [];
  List<String> _datasFormatadas = [];
  List<DateTime> _datasDisponiveis = [];
  
  // Valores selecionados
  String? _produtoSelecionado;
  String? _origemSelecionada;
  String? _destinoSelecionado;
  
  @override
  void initState() {
    super.initState();
    _carregarDadosUsuario();
    _carregarProdutos();
    _carregarFiliais();
    _gerarDatasDisponiveis();
  }

  void _gerarDatasDisponiveis() {
    final hoje = DateTime.now();
    _datasDisponiveis = [
      hoje,
      hoje.add(const Duration(days: 1)),
      hoje.add(const Duration(days: 2)),
      hoje.add(const Duration(days: 3)),
      hoje.add(const Duration(days: 4)),
    ];
    _datasFormatadas = _datasDisponiveis.map(_formatarData).toList();
  }

  Future<void> _carregarDadosUsuario() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user != null) {
        _usuarioId = user.id;
        
        // Buscar empresa_id do usuário
        final usuarioData = await supabase
            .from('usuarios')
            .select('empresa_id')
            .eq('id', user.id)
            .maybeSingle();
            
        if (usuarioData != null) {
          _empresaId = usuarioData['empresa_id']?.toString();
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados do usuário: $e');
    }
  }

  Future<void> _carregarProdutos() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('produtos')
          .select('id, nome')
          .order('nome');
      
      setState(() {
        _produtos = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Erro ao carregar produtos: $e');
    }
  }

  Future<void> _carregarFiliais() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('filiais')
          .select('id, nome_dois')
          .order('nome_dois');
      
      setState(() {
        _filiais = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Erro ao carregar filiais: $e');
    }
  }

  // Funções para buscar dados (apenas para autocomplete)
  Future<List<Map<String, dynamic>>> _buscarMotoristas(String texto) async {
    if (texto.length < 3) return [];
    
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('motoristas')
        .select('id, nome')
        .ilike('nome', '%$texto%')
        .order('nome')
        .limit(10);
    
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> _buscarTransportadoras(String texto) async {
    if (texto.length < 3) return [];
    
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('transportadoras')
        .select('id, nome_dois')
        .ilike('nome_dois', '%$texto%')
        .order('nome_dois')
        .limit(10);
    
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<String>> _buscarPlacas(String texto) async {
    if (texto.length < 3) return [];
    
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('vw_placas')
        .select('placa')
        .ilike('placa', '$texto%')
        .order('placa')
        .limit(10);

    return response.map<String>((p) => p['placa'].toString()).toList();
  }

  // Formatar quantidade no formato "999.999"
  String _aplicarMascaraQuantidade(String texto) {
    // Remove tudo que não é número
    String apenasNumeros = texto.replaceAll(RegExp(r'[^\d]'), '');

    // Limita a 6 dígitos (999.999)
    if (apenasNumeros.length > 6) {
      apenasNumeros = apenasNumeros.substring(0, 6);
    }

    if (apenasNumeros.isEmpty) return '';

    // Aplica máscara 999.999
    if (apenasNumeros.length > 3) {
      String parteMilhar = apenasNumeros.substring(0, apenasNumeros.length - 3);
      String parteCentena = apenasNumeros.substring(apenasNumeros.length - 3);
      return '$parteMilhar.$parteCentena';
    }

    return apenasNumeros;
  }  

  // PASSO 1 — MAPA FIXO UUID → COLUNA (conforme tabela fornecida)
  String _resolverColunaProduto(String produtoId) {
    // MAPA: UUID do produto → Coluna na tabela movimentacoes
    const mapaProdutoColuna = {
      '3c26a7e5-8f3a-4429-a8c7-2e0e72f1b80a': 's10_a',     // Diesel A-S10
      '4da89784-301f-4abe-b97e-c48729969e3d': 's500_a',    // Diesel A-S500
      '58ce20cf-f252-4291-9ef6-f4821f22c29e': 'd_s10',     // Diesel S10-B
      '66ca957a-5698-4a02-8c9e-987770b6a151': 'etanol',    // Hidratado
      '82c348c8-efa1-4d1a-953a-ee384d5780fc': 'g_comum',   // Gasolina Comum
      '93686e9d-6ef5-4f7c-a97d-b058b3c2c693': 'g_aditivada', // Gasolina Aditivada
      'c77a6e31-52f0-4fe1-bdc8-685df83f3a1': 'd_s500',     // Diesel S500-B
      'cecab8eb-297a-4640-81ae-e88335b88d8b': 'anidro',    // Anidro
      'ecd91066-e763-42e3-8a0e-d982ea6da535': 'b100',      // B100
      'f8e95435-471a-424c-947f-def8809053a0': 'gasolina_a', // Gasolina A
    };

    // Normalizar UUID (remover espaços, converter para minúsculas)
    final uuidNormalizado = produtoId.trim().toLowerCase();
    
    final coluna = mapaProdutoColuna[uuidNormalizado];

    if (coluna == null) {
      throw Exception('Produto (UUID: $produtoId) sem coluna de movimentação configurada');
    }

    return coluna;
  }

  // PASSO 2 — FUNÇÃO _salvar() ATUALIZADA PARA 1 LINHA APENAS
  Future<void> _salvar() async {
    if (_produtoId == null ||
        _origemId == null ||
        _destinoId == null ||
        _quantidadeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha os campos obrigatórios'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_origemId == _destinoId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Origem e destino não podem ser iguais'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_empresaId == null || _usuarioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuário ou empresa não identificados'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _salvando = true);

    try {
      final supabase = Supabase.instance.client;

      final quantidade =
          int.parse(_quantidadeController.text.replaceAll('.', ''));
      
      // Buscar nomes das filiais para a descrição
      final origemNome = _filiais
        .firstWhere(
          (f) => f['id']?.toString() == _origemId,
          orElse: () => {'nome_dois': ''},
        )['nome_dois']
        ?.toString() ??
        '';
      
      final destinoNome = _filiais
        .firstWhere(
          (f) => f['id']?.toString() == _destinoId,
          orElse: () => {'nome_dois': ''},
        )['nome_dois']
        ?.toString() ??
        '';

      // PASSO 4 — COLUNA DO PRODUTO ESPECÍFICA (baseado no UUID)
      final colunaProduto = _resolverColunaProduto(_produtoId!);

      // placas
      final placas = <String>[];
      if (_cavaloController.text.isNotEmpty) placas.add(_cavaloController.text);
      if (_reboque1Controller.text.isNotEmpty) placas.add(_reboque1Controller.text);
      if (_reboque2Controller.text.isNotEmpty) placas.add(_reboque2Controller.text);

      // Criar UMA ÚNICA LINHA com todos os dados da transferência
      final transferencia = {
        'tipo_op': 'Transf',
        'produto_id': _produtoId,
        'quantidade': quantidade,
        'descricao': '$origemNome → $destinoNome',  // Descrição formatada
        'placa': placas.isNotEmpty ? placas : null,
        'usuario_id': _usuarioId,
        'empresa_id': _empresaId,
        'motorista_id': _motoristaId,
        'transportadora_id': _transportadoraId,
        'data_mov': _dataSelecionada.toIso8601String().split('T')[0],
        'filial_origem_id': _origemId,
        'filial_destino_id': _destinoId,
        'updated_at': DateTime.now().toIso8601String(),
        
        // NOVOS CAMPOS - APENAS 1 LINHA
        'filial_id': null,            // NULL pois não é específico de uma filial
        'tipo_mov': null,             // NULL pois não usamos mais
        'tipo_mov_orig': 'saida',     // Movimento na origem
        'tipo_mov_dest': 'entrada',   // Movimento no destino
        
        // COLUNAS DE PRODUTO INICIALIZADAS COM 0
        'g_comum': 0,
        'g_aditivada': 0,
        'd_s10': 0,
        'd_s500': 0,
        'etanol': 0,
        'anidro': 0,
        'b100': 0,
        'gasolina_a': 0,
        's500_a': 0,
        's10_a': 0,
      };
      
      // Atribuir quantidade apenas na coluna correta do produto
      transferencia[colunaProduto] = quantidade;

      // INSERIR APENAS 1 LINHA
      await supabase.from('movimentacoes').insert([transferencia]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transferência registrada com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Erro ao salvar transferência: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      child: Container(
        width: 800,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.swap_horiz, color: Theme.of(context).primaryColor, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Nova Transferência',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(false),
                  tooltip: 'Fechar',
                ),
              ],
            ),
            
            const Divider(),
            const SizedBox(height: 16),
            
            // Campos do formulário
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Primeira linha: Data e Produto
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Campo Data (dropdown simples)
                        SizedBox(
                          width: 150,
                          child: DropdownButtonFormField<String>(
                            initialValue: _formatarData(_dataSelecionada),
                            decoration: const InputDecoration(
                              labelText: 'Data',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            ),
                            items: _datasFormatadas.map((dataStr) {
                              return DropdownMenuItem<String>(
                                value: dataStr,
                                child: Text(dataStr),
                              );
                            }).toList(),
                            onChanged: (dataString) {
                              if (dataString != null) {
                                // Encontrar o DateTime correspondente à string selecionada
                                final index = _datasFormatadas.indexOf(dataString);
                                if (index >= 0) {
                                  setState(() => _dataSelecionada = _datasDisponiveis[index]);
                                }
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Campo Produto (dropdown simples)
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _produtoSelecionado,
                            decoration: const InputDecoration(
                              labelText: 'Produto *',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            ),
                            items: _produtos.map((produto) {
                              return DropdownMenuItem<String>(
                                value: produto['id']?.toString(),
                                child: Text(produto['nome']?.toString() ?? ''),
                              );
                            }).toList(),
                            onChanged: (id) {
                              setState(() {
                                _produtoSelecionado = id;
                                _produtoId = id;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Campo Quantidade
                        SizedBox(
                          width: 150,
                          child: TextFormField(
                            controller: _quantidadeController,
                            keyboardType: TextInputType.number,
                            maxLength: 7,
                            onChanged: (value) {
                              final maskedValue = _aplicarMascaraQuantidade(value);
                              
                              if (maskedValue != value) {
                                final cursorPosition = _quantidadeController.selection.baseOffset;
                                _quantidadeController.value = TextEditingValue(
                                  text: maskedValue,
                                  selection: TextSelection.collapsed(
                                    offset: cursorPosition + (maskedValue.length - value.length),
                                  ),
                                );
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'Quantidade *',
                              border: OutlineInputBorder(),
                              counterText: '',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              suffixText: 'litros',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Segunda linha: Motorista e Transportadora (autocomplete)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AutocompleteField<Map<String, dynamic>>(
                            controller: _motoristaController,
                            label: 'Motorista',
                            buscarItens: _buscarMotoristas,
                            obterTextoExibicao: (item) => item['nome']?.toString() ?? '',
                            obterId: (item) => item['id']?.toString() ?? '',
                            validarParaBusca: (texto) => texto.length >= 3,
                            onSelecionado: (motorista) {
                              _motoristaId = motorista['id']?.toString();
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AutocompleteField<Map<String, dynamic>>(
                            controller: _transportadoraController,
                            label: 'Transportadora',
                            buscarItens: _buscarTransportadoras,
                            obterTextoExibicao: (item) => item['nome_dois']?.toString() ?? '',
                            obterId: (item) => item['id']?.toString() ?? '',
                            validarParaBusca: (texto) => texto.length >= 3,
                            onSelecionado: (transportadora) {
                              _transportadoraId = transportadora['id']?.toString();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Terceira linha: Cavalo, Reboque 1, Reboque 2 (autocomplete)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AutocompleteField<String>(
                            controller: _cavaloController,
                            label: 'Cavalo',
                            buscarItens: _buscarPlacas,
                            obterTextoExibicao: (item) => item,
                            obterId: (item) => item,
                            validarParaBusca: (texto) => texto.length >= 3,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AutocompleteField<String>(
                            controller: _reboque1Controller,
                            label: 'Reboque 1',
                            buscarItens: _buscarPlacas,
                            obterTextoExibicao: (item) => item,
                            obterId: (item) => item,
                            validarParaBusca: (texto) => texto.length >= 3,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AutocompleteField<String>(
                            controller: _reboque2Controller,
                            label: 'Reboque 2',
                            buscarItens: _buscarPlacas,
                            obterTextoExibicao: (item) => item,
                            obterId: (item) => item,
                            validarParaBusca: (texto) => texto.length >= 3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Quarta linha: Origem e Destino (dropdown simples)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _origemSelecionada,
                            decoration: const InputDecoration(
                              labelText: 'Origem *',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            ),
                            items: _filiais.map((filial) {
                              return DropdownMenuItem<String>(
                                value: filial['id']?.toString(),
                                child: Text(filial['nome_dois']?.toString() ?? ''),
                              );
                            }).toList(),
                            onChanged: (id) {
                              setState(() {
                                _origemSelecionada = id;
                                _origemId = id;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _destinoSelecionado,
                            decoration: const InputDecoration(
                              labelText: 'Destino *',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            ),
                            items: _filiais.map((filial) {
                              return DropdownMenuItem<String>(
                                value: filial['id']?.toString(),
                                child: Text(filial['nome_dois']?.toString() ?? ''),
                              );
                            }).toList(),
                            onChanged: (id) {
                              setState(() {
                                _destinoSelecionado = id;
                                _destinoId = id;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Aviso de campos obrigatórios
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '* Campos obrigatórios: Produto, Quantidade, Origem e Destino',
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Botões de ação
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.cancel, size: 20),
                  label: const Text('Cancelar'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _salvando ? null : _salvar,
                  icon: _salvando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check, size: 20),
                  label: Text(_salvando ? 'Salvando...' : 'Criar Ordem'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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
}