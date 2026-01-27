import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
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
          .eq("tipo_op", "transf")
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
//                COMPONENTE AUTOCOMPLETE MELHORADO (MODIFICADO)
// ==============================================================
class AutocompleteField<T> extends StatefulWidget {
  final TextEditingController controller;
  final String label; // Será usado como hintText
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
      child: TextFormField(
        controller: widget.controller,
        focusNode: _internalFocusNode,
        onChanged: _onTextChanged,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          // REMOVIDO: labelText: widget.label,
          hintText: 'Digite para buscar...',
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4), // Reduzido de 6 para 4
            borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 1.2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8, // Reduzido para ficar mais compacto
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
    );
  }
}