import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

// ==============================================================
//                COMPONENTE AUTOCOMPLETE REUTILIZÁVEL
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
      child: TextFormField(
        controller: widget.controller,
        focusNode: _internalFocusNode,
        onChanged: _onTextChanged,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Digite para buscar...',
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
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
            vertical: 8,
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

// ==============================================================
//                DIALOG DE NOVA TRANSFERÊNCIA MODERNIZADO
// ==============================================================
class NovaTransferenciaDialog extends StatefulWidget {
  const NovaTransferenciaDialog({super.key});

  @override
  State<NovaTransferenciaDialog> createState() => _NovaTransferenciaDialogState();
}

class _NovaTransferenciaDialogState extends State<NovaTransferenciaDialog> {
  DateTime _dataSelecionada = DateTime.now();
  bool _salvando = false;
  
  // NOVO FLAG DE CONTROLE (PASSO 1)
  bool _preenchimentoAutomaticoAtivo = false;
  
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
  
  // Estados para autocomplete das placas
  bool _mostrarSugestoesCavalo = false;
  bool _carregandoPlacasCavalo = false;
  List<Map<String, dynamic>> _placasCavaloEncontradas = [];
  
  bool _mostrarSugestoesReboque1 = false;
  bool _carregandoPlacasReboque1 = false;
  List<Map<String, dynamic>> _placasReboque1Encontradas = [];
  
  bool _mostrarSugestoesReboque2 = false;
  bool _carregandoPlacasReboque2 = false;
  List<Map<String, dynamic>> _placasReboque2Encontradas = [];
  
  // Focus nodes para controlar o fechamento das sugestões
  final FocusNode _cavaloFocusNode = FocusNode();
  final FocusNode _reboque1FocusNode = FocusNode();
  final FocusNode _reboque2FocusNode = FocusNode();
  
  @override
  void initState() {
    super.initState();
    _carregarDadosUsuario();
    _carregarProdutos();
    _carregarFiliais();
    _gerarDatasDisponiveis();
    
    // Configurar focus nodes para fechar sugestões
    _cavaloFocusNode.addListener(() {
      if (!_cavaloFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() => _mostrarSugestoesCavalo = false);
          }
        });
      }
    });
    
    _reboque1FocusNode.addListener(() {
      if (!_reboque1FocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() => _mostrarSugestoesReboque1 = false);
          }
        });
      }
    });
    
    _reboque2FocusNode.addListener(() {
      if (!_reboque2FocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() => _mostrarSugestoesReboque2 = false);
          }
        });
      }
    });
  }
  
  @override
  void dispose() {
    _cavaloFocusNode.dispose();
    _reboque1FocusNode.dispose();
    _reboque2FocusNode.dispose();
    _motoristaController.dispose();
    _quantidadeController.dispose();
    _transportadoraController.dispose();
    _cavaloController.dispose();
    _reboque1Controller.dispose();
    _reboque2Controller.dispose();
    super.dispose();
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

  // PASSO 7: FUNÇÃO PARA APLICAR MÁSCARA DE PLACA ABC-1234
  String _aplicarMascaraPlaca(String texto) {
    final limpo = texto
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');

    if (limpo.length <= 3) return limpo;

    final letras = limpo.substring(0, 3);
    final numeros = limpo.substring(3, limpo.length.clamp(3, 7));

    return '$letras-$numeros';
  }

  // PASSO 8: FUNÇÃO DE INVALIDAÇÃO AO EDITAR PLACA MANUALMENTE
  void _onEdicaoManualPlaca(String texto, TextEditingController controller) {
    if (_preenchimentoAutomaticoAtivo) {
      _preenchimentoAutomaticoAtivo = false;
      _limparMotoristaEPlacas();
    }

    controller.value = TextEditingValue(
      text: _aplicarMascaraPlaca(texto),
      selection: TextSelection.collapsed(
        offset: _aplicarMascaraPlaca(texto).length,
      ),
    );
  }

  // PASSO 3: FUNÇÃO PARA LIMPAR MOTORISTA E PLACAS
  void _limparMotoristaEPlacas() {
    setState(() {
      _motoristaController.clear();
      _motoristaId = null;

      _cavaloController.clear();
      _reboque1Controller.clear();
      _reboque2Controller.clear();
      
      // NOVO: Também limpar a transportadora
      _transportadoraController.clear();
      _transportadoraId = null;
    });
  }

  // PASSO 4: FUNÇÃO PARA APLICAR O CONJUNTO NOS CAMPOS
  // PASSO 4: FUNÇÃO PARA APLICAR O CONJUNTO NOS CAMPOS
  void _aplicarConjuntoNosCampos(Map<String, dynamic> conjunto) {
    setState(() {
      _preenchimentoAutomaticoAtivo = true;

      _cavaloController.text = _aplicarMascaraPlaca(conjunto['cavalo'] ?? '');
      _reboque1Controller.text = _aplicarMascaraPlaca(conjunto['reboque_um'] ?? '');
      _reboque2Controller.text = _aplicarMascaraPlaca(conjunto['reboque_dois'] ?? '');
      
      // NOVO: Definir transportadora como "Petroserra" automaticamente
      _transportadoraController.text = 'Petroserra';
      
      // Vamos também buscar o ID da transportadora Petroserra
      _buscarIdTransportadoraPetroserra();
    });
  }

  Future<void> _buscarIdTransportadoraPetroserra() async {
    try {
      final supabase = Supabase.instance.client;
      
      final response = await supabase
          .from('transportadoras')
          .select('id')
          .eq('nome_dois', 'Petroserra')
          .limit(1)
          .maybeSingle();
      
      if (response != null) {
        _transportadoraId = response['id']?.toString();
      }
    } catch (e) {
      debugPrint('Erro ao buscar ID da Petroserra: $e');
    }
  }

  // PASSO 2: FUNÇÃO PARA BUSCAR UM CONJUNTO PELO MOTORISTA
  Future<Map<String, dynamic>?> _buscarConjuntoPorMotorista(String motoristaId) async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('conjuntos')
          .select('cavalo, reboque_um, reboque_dois')
          .eq('motorista_id', motoristaId)
          .limit(1)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Erro ao buscar conjunto por motorista: $e');
      return null;
    }
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
  
  Widget _buildCampoAutocomplete<T>({
    required TextEditingController controller,
    required String label,
    required Future<List<T>> Function(String) buscarItens,
    required String Function(T) obterTextoExibicao,
    required String Function(T) obterId,
    required void Function(T)? onSelecionado,
    double? width,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label acima do campo (padronizado)
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0D47A1),
            ),
          ),
          const SizedBox(height: 4),
          
          // Campo de autocomplete
          AutocompleteField<T>(
            controller: controller,
            label: label,
            buscarItens: buscarItens,
            obterTextoExibicao: obterTextoExibicao,
            obterId: obterId,
            validarParaBusca: (texto) => texto.length >= 3,
            onSelecionado: onSelecionado,
          ),
        ],
      ),
    );
  }

  Future<void> _carregarProdutos() async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('produtos')
          .select('id, nome');

      final produtos = List<Map<String, dynamic>>.from(response);

      const ordemPorId = {
        '82c348c8-efa1-4d1a-953a-ee384d5780fc': 1,  // Gasolina Comum
        '93686e9d-6ef5-4f7c-a97d-b058b3c2c693': 2,  // Gasolina Aditivada
        'c77a6e31-52f0-4fe1-bdc8-685dff83f3a1': 3,  // Diesel S500
        '58ce20cf-f252-4291-9ef6-f4821f22c29e': 4,  // Diesel S10
        '66ca957a-5698-4a02-8c9e-987770b6a151': 5,  // Etanol
        'f8e95435-471a-424c-947f-def8809053a0': 6,  // Gasolina A
        '4da89784-301f-4abe-b97e-c48729969e3d': 7,  // S500 A
        '3c26a7e5-8f3a-4429-a8c7-2e0e72f1b80a': 8,  // S10 A
        'cecab8eb-297a-4640-81ae-e88335b88d8b': 9,  // Anidro
        'ecd91066-e763-42e3-8a0e-d982ea6da535': 10, // B100
      };

      produtos.sort((a, b) {
        final idA = a['id'].toString().toLowerCase();
        final idB = b['id']?.toString().toLowerCase() ?? '';

        return (ordemPorId[idA] ?? 999)
            .compareTo(ordemPorId[idB] ?? 999);
      });

      setState(() {
        _produtos = produtos;
      });
    } catch (e) {
      debugPrint('Erro ao carregar produtos: $e');
      setState(() {
        _produtos = [];
      });
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

  Future<List<Map<String, dynamic>>> _buscarPlacas(String texto) async {
    if (texto.length < 3) return [];
    
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('view_placas_tanques')
          .select('placas, tanques')
          .ilike('placas', '${texto.replaceAll('-', '').toUpperCase()}%')
          .order('placas')
          .limit(10);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Erro ao buscar placas: $e');
      return [];
    }
  }

  Future<void> _buscarPlacasCavalo(String texto) async {
    if (texto.length < 3) {
      setState(() {
        _placasCavaloEncontradas.clear();
        _mostrarSugestoesCavalo = false;
      });
      return;
    }

    setState(() {
      _carregandoPlacasCavalo = true;
    });

    try {
      final placas = await _buscarPlacas(texto);
      setState(() {
        _placasCavaloEncontradas = placas;
        _carregandoPlacasCavalo = false;
        _mostrarSugestoesCavalo = placas.isNotEmpty;
      });
    } catch (e) {
      debugPrint('Erro ao buscar placas cavalo: $e');
      setState(() {
        _placasCavaloEncontradas.clear();
        _carregandoPlacasCavalo = false;
        _mostrarSugestoesCavalo = false;
      });
    }
  }

  Future<void> _buscarPlacasReboque1(String texto) async {
    if (texto.length < 3) {
      setState(() {
        _placasReboque1Encontradas.clear();
        _mostrarSugestoesReboque1 = false;
      });
      return;
    }

    setState(() {
      _carregandoPlacasReboque1 = true;
    });

    try {
      final placas = await _buscarPlacas(texto);
      setState(() {
        _placasReboque1Encontradas = placas;
        _carregandoPlacasReboque1 = false;
        _mostrarSugestoesReboque1 = placas.isNotEmpty;
      });
    } catch (e) {
      debugPrint('Erro ao buscar placas reboque1: $e');
      setState(() {
        _placasReboque1Encontradas.clear();
        _carregandoPlacasReboque1 = false;
        _mostrarSugestoesReboque1 = false;
      });
    }
  }

  Future<void> _buscarPlacasReboque2(String texto) async {
    if (texto.length < 3) {
      setState(() {
        _placasReboque2Encontradas.clear();
        _mostrarSugestoesReboque2 = false;
      });
      return;
    }

    setState(() {
      _carregandoPlacasReboque2 = true;
    });

    try {
      final placas = await _buscarPlacas(texto);
      setState(() {
        _placasReboque2Encontradas = placas;
        _carregandoPlacasReboque2 = false;
        _mostrarSugestoesReboque2 = placas.isNotEmpty;
      });
    } catch (e) {
      debugPrint('Erro ao buscar placas reboque2: $e');
      setState(() {
        _placasReboque2Encontradas.clear();
        _carregandoPlacasReboque2 = false;
        _mostrarSugestoesReboque2 = false;
      });
    }
  }

  void _selecionarPlacaCavalo(Map<String, dynamic> item) {
    setState(() {
      _cavaloController.text = _aplicarMascaraPlaca(item['placas']);
      _mostrarSugestoesCavalo = false;
    });
  }

  void _selecionarPlacaReboque1(Map<String, dynamic> item) {
    setState(() {
      _reboque1Controller.text = _aplicarMascaraPlaca(item['placas']);
      _mostrarSugestoesReboque1 = false;
    });
  }

  void _selecionarPlacaReboque2(Map<String, dynamic> item) {
    setState(() {
      _reboque2Controller.text = _aplicarMascaraPlaca(item['placas']);
      _mostrarSugestoesReboque2 = false;
    });
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

  String _resolverColunaProduto(String produtoId) {
    const mapaProdutoColuna = {
      '3c26a7e5-8f3a-4429-a8c7-2e0e72f1b80a': 's10_a',
      '4da89784-301f-4abe-b97e-c48729969e3d': 's500_a',
      '58ce20cf-f252-4291-9ef6-f4821f22c29e': 'd_s10',
      '66ca957a-5698-4a02-8c9e-987770b6a151': 'etanol',
      '82c348c8-efa1-4d1a-953a-ee384d5780fc': 'g_comum',
      '93686e9d-6ef5-4f7c-a97d-b058b3c2c693': 'g_aditivada',
      'c77a6e31-52f0-4fe1-bdc8-685dff83f3a1': 'd_s500',
      'cecab8eb-297a-4640-81ae-e88335b88d8b': 'anidro',
      'ecd91066-e763-42e3-8a0e-d982ea6da535': 'b100',
      'f8e95435-471a-424c-947f-def8809053a0': 'gasolina_a',
    };

    // Normalizar UUID (remover espaços, converter para minúsculas)
    final uuidNormalizado = produtoId.trim().toLowerCase();
    
    final coluna = mapaProdutoColuna[uuidNormalizado];

    if (coluna == null) {
      throw Exception('Produto (UUID: $produtoId) sem coluna de movimentação configurada');
    }

    return coluna;
  }

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

      // Buscar empresa_id da filial de origem para a ordem
      final filialResponse = await supabase
          .from('filiais')
          .select('empresa_id')
          .eq('id', _origemId!)
          .single();

      final empresaIdOrdem = filialResponse['empresa_id'];

      // Criar ordem primeiro
      final hoje = DateTime.now();
      final dataMov = '${hoje.year}-${hoje.month.toString().padLeft(2, '0')}-${hoje.day.toString().padLeft(2, '0')}';

      final ordemResponse = await supabase
          .from('ordens')
          .insert({
            'empresa_id': empresaIdOrdem,
            'filial_id': _origemId,  // Filial de origem
            'usuario_id': _usuarioId,
            'tipo': 'transferencia',
            'data_ordem': dataMov,
          })
          .select('id')
          .single();

      final ordemId = ordemResponse['id'];

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

      // Coluna do produto específica (baseado no UUID)
      final colunaProduto = _resolverColunaProduto(_produtoId!);

      // placas
      final placas = <String>[];
      if (_cavaloController.text.isNotEmpty) placas.add(_cavaloController.text);
      if (_reboque1Controller.text.isNotEmpty) placas.add(_reboque1Controller.text);
      if (_reboque2Controller.text.isNotEmpty) placas.add(_reboque2Controller.text);

      // Criar UMA ÚNICA LINHA com todos os dados da transferência
      final transferencia = {
        'ordem_id': ordemId,
        'tipo_op': 'transf',
        'produto_id': _produtoId,
        'quantidade': quantidade,
        'descricao': '$origemNome → $destinoNome',
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
        'filial_id': null,
        'tipo_mov': null,
        'tipo_mov_orig': 'saida',
        'tipo_mov_dest': 'entrada',
        
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

  // Widget para campo de placa com autocomplete
  Widget _buildCampoPlaca({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required bool mostrarSugestoes,
    required bool carregando,
    required List<Map<String, dynamic>> placasEncontradas,
    required Function(String) onChanged,
    required Function(Map<String, dynamic>) onSelecionar,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0D47A1),
          ),
        ),
        const SizedBox(height: 4),
        Stack(
          children: [
            TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
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
                suffixIcon: carregando
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.search, size: 16),
              ),
            ),
            
            if (mostrarSugestoes && placasEncontradas.isNotEmpty)
              Positioned(
                top: 42,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: placasEncontradas.map((item) {
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => onSelecionar(item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey.shade200,
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.directions_car, 
                                  size: 14, 
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _aplicarMascaraPlaca(item['placas']),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Container(
        width: 900,
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF0D47A1),
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  Icon(Icons.swap_horiz, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  const Text(
                    'Nova Transferência',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    onPressed: () => Navigator.of(context).pop(false),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36),
                  ),
                ],
              ),
            ),
            
            // Conteúdo
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Linha 1: Data, Produto, Quantidade
                    Row(
                      children: [
                        // Campo Data
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Data',
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
                                    value: _formatarData(_dataSelecionada),
                                    isExpanded: true,
                                    icon: const Icon(Icons.arrow_drop_down, size: 20),
                                    style: const TextStyle(fontSize: 13, color: Colors.black),
                                    onChanged: (dataString) {
                                      if (dataString != null) {
                                        final index = _datasFormatadas.indexOf(dataString);
                                        if (index >= 0) {
                                          setState(() => _dataSelecionada = _datasDisponiveis[index]);
                                        }
                                      }
                                    },
                                    items: _datasFormatadas.map((dataStr) {
                                      return DropdownMenuItem<String>(
                                        value: dataStr,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          child: Text(dataStr),
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
                        
                        // Campo Produto
                        Expanded(
                          flex: 2,
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
                                    hint: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 12),
                                      child: Text('Selecione um produto'),
                                    ),
                                    onChanged: (id) {
                                      setState(() {
                                        _produtoSelecionado = id;
                                        _produtoId = id;
                                      });
                                    },
                                    items: _produtos.map((produto) {
                                      return DropdownMenuItem<String>(
                                        value: produto['id']?.toString(),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          child: Text(produto['nome']?.toString() ?? ''),
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
                        
                        // Campo Quantidade
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Quantidade *',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0D47A1),
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextFormField(
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
                                style: const TextStyle(fontSize: 13),
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
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
                                  counterText: '',
                                  suffixText: 'litros',
                                  suffixStyle: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Linha 2: Motorista, Cavalo, Reboque 1, Reboque 2
                    Row(
                      children: [
                        // Campo Motorista (autocomplete) - PASSO 5: MODIFICADO
                        Expanded(
                          flex: 2,
                          child: _buildCampoAutocomplete<Map<String, dynamic>>(
                            controller: _motoristaController,
                            label: 'Motorista',
                            buscarItens: _buscarMotoristas,
                            obterTextoExibicao: (item) => item['nome']?.toString() ?? '',
                            obterId: (item) => item['id']?.toString() ?? '',
                            onSelecionado: (motorista) async {
                              _motoristaId = motorista['id']?.toString();

                              final conjunto = await _buscarConjuntoPorMotorista(_motoristaId!);

                              if (conjunto == null) {
                                _limparMotoristaEPlacas();
                                return;
                              }

                              _aplicarConjuntoNosCampos(conjunto);
                            },
                          ),
                        ),
                        
                        const SizedBox(width: 16),
                        
                        // Campo Cavalo (autocomplete melhorado) - PASSO 9: MODIFICADO
                        Expanded(
                          flex: 1,
                          child: _buildCampoPlaca(
                            controller: _cavaloController,
                            focusNode: _cavaloFocusNode,
                            label: 'Cavalo',
                            mostrarSugestoes: _mostrarSugestoesCavalo,
                            carregando: _carregandoPlacasCavalo,
                            placasEncontradas: _placasCavaloEncontradas,
                            onChanged: (texto) {
                              _onEdicaoManualPlaca(texto, _cavaloController);
                              _buscarPlacasCavalo(texto);
                            },
                            onSelecionar: _selecionarPlacaCavalo,
                          ),
                        ),
                        
                        const SizedBox(width: 16),
                        
                        // Campo Reboque 1 - PASSO 9: MODIFICADO
                        Expanded(
                          flex: 1,
                          child: _buildCampoPlaca(
                            controller: _reboque1Controller,
                            focusNode: _reboque1FocusNode,
                            label: 'Reboque 1',
                            mostrarSugestoes: _mostrarSugestoesReboque1,
                            carregando: _carregandoPlacasReboque1,
                            placasEncontradas: _placasReboque1Encontradas,
                            onChanged: (texto) {
                              _onEdicaoManualPlaca(texto, _reboque1Controller);
                              _buscarPlacasReboque1(texto);
                            },
                            onSelecionar: _selecionarPlacaReboque1,
                          ),
                        ),
                        
                        const SizedBox(width: 16),
                        
                        // Campo Reboque 2 - PASSO 9: MODIFICADO
                        Expanded(
                          flex: 1,
                          child: _buildCampoPlaca(
                            controller: _reboque2Controller,
                            focusNode: _reboque2FocusNode,
                            label: 'Reboque 2',
                            mostrarSugestoes: _mostrarSugestoesReboque2,
                            carregando: _carregandoPlacasReboque2,
                            placasEncontradas: _placasReboque2Encontradas,
                            onChanged: (texto) {
                              _onEdicaoManualPlaca(texto, _reboque2Controller);
                              _buscarPlacasReboque2(texto);
                            },
                            onSelecionar: _selecionarPlacaReboque2,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Linha 3: Transportadora, Origem, Destino
                    Row(
                      children: [
                        // Campo Transportadora (autocomplete)
                        Expanded(
                          flex: 2,
                          child: _buildCampoAutocomplete<Map<String, dynamic>>(
                            controller: _transportadoraController,
                            label: 'Transportadora',
                            buscarItens: _buscarTransportadoras,
                            obterTextoExibicao: (item) => item['nome_dois']?.toString() ?? '',
                            obterId: (item) => item['id']?.toString() ?? '',
                            onSelecionado: (transportadora) {
                              _transportadoraId = transportadora['id']?.toString();
                            },
                          ),
                        ),
                        
                        const SizedBox(width: 16),
                        
                        // Campo Origem
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Origem *',
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
                                    value: _origemSelecionada,
                                    isExpanded: true,
                                    icon: const Icon(Icons.arrow_drop_down, size: 20),
                                    style: const TextStyle(fontSize: 13, color: Colors.black),
                                    hint: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 12),
                                      child: Text('Selecione a origem'),
                                    ),
                                    onChanged: (id) {
                                      setState(() {
                                        _origemSelecionada = id;
                                        _origemId = id;
                                      });
                                    },
                                    items: _filiais.map((filial) {
                                      return DropdownMenuItem<String>(
                                        value: filial['id']?.toString(),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          child: Text(filial['nome_dois']?.toString() ?? ''),
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
                        
                        // Campo Destino
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Destino *',
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
                                    value: _destinoSelecionado,
                                    isExpanded: true,
                                    icon: const Icon(Icons.arrow_drop_down, size: 20),
                                    style: const TextStyle(fontSize: 13, color: Colors.black),
                                    hint: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 12),
                                      child: Text('Selecione o destino'),
                                    ),
                                    onChanged: (id) {
                                      setState(() {
                                        _destinoSelecionado = id;
                                        _destinoId = id;
                                      });
                                    },
                                    items: _filiais.map((filial) {
                                      return DropdownMenuItem<String>(
                                        value: filial['id']?.toString(),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          child: Text(filial['nome_dois']?.toString() ?? ''),
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
                    
                    const SizedBox(height: 24),
                    
                    // Aviso de campos obrigatórios
                    Container(
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
                            child: Text(
                              '* Campos obrigatórios: Produto, Quantidade, Origem e Destino',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade800,
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
            
            // Footer com botões
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Botão Cancelar
                  SizedBox(
                    width: 120,
                    height: 36,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        side: BorderSide(color: Colors.grey.shade400, width: 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color.fromARGB(255, 95, 95, 95),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Botão Criar Ordem
                  SizedBox(
                    width: 140,
                    height: 36,
                    child: ElevatedButton(
                      onPressed: _salvando ? null : _salvar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: _salvando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Criar Ordem',
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
            ),
          ],
        ),
      ),
    );
  }
}