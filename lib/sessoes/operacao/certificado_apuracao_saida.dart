import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert' show base64Encode;
import 'dart:js' as js;
import 'certificado_pdf.dart';
import '../../login_page.dart';

// ================= MODELO DE DADOS TANQUE =================

class TanqueDados {
  final String id;
  final TextEditingController volumeAmbCtrl;
  final TextEditingController volume20CCtrl;
  final String? produtoNome; // Nome do produto deste tanque
  final String? produtoId; // ID do produto (UUID)
  bool buscarDoBanco;
  
  // Dados da coleta (preenchidos no dialog)
  String? tempAmostra;
  String? densidadeObservada;
  String? tempCT;
  String? densidade20C;
  String? fatorCorrecao;

  TanqueDados({
    required this.id,
    required this.volumeAmbCtrl,
    required this.volume20CCtrl,
    this.produtoNome,
    this.produtoId,
    this.buscarDoBanco = false,
    this.tempAmostra,
    this.densidadeObservada,
    this.tempCT,
    this.densidade20C,
    this.fatorCorrecao,
  });

  void dispose() {
    volumeAmbCtrl.dispose();
    volume20CCtrl.dispose();
  }
}

// ================= COMPONENTE PLACA AUTOCOMPLETE =================

class PlacaAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final FocusNode? focusNode;
  final void Function(String)? onChanged;
  final bool enabled;

  const PlacaAutocompleteField({
    super.key,
    required this.controller,
    required this.label,
    this.focusNode,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<PlacaAutocompleteField> createState() => _PlacaAutocompleteFieldState();
}

class _PlacaAutocompleteFieldState extends State<PlacaAutocompleteField> {
  final List<String> _sugestoes = [];
  bool _carregando = false;
  Timer? _debounceTimer;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final FocusNode _internalFocusNode = FocusNode();

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
    if (!widget.enabled) return;
    
    if (_internalFocusNode.hasFocus) {
      _mostrarOverlay();
    } else {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_internalFocusNode.hasFocus) {
          _fecharOverlay();
        }
      });
    }
  }

  Future<void> _buscarPlacas(String texto) async {
    if (!widget.enabled) return;
    
    if (texto.length < 3) {
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
      final res = await Supabase.instance.client
          .from('vw_placas')
          .select('placa')
          .ilike('placa', '$texto%')
          .order('placa')
          .limit(10);

      final sugestoes = res.map<String>((p) => p['placa'].toString()).toList();

      setState(() {
        _sugestoes.clear();
        _sugestoes.addAll(sugestoes);
        _carregando = false;
      });

      if (_sugestoes.isNotEmpty && _internalFocusNode.hasFocus) {
        _mostrarOverlay();
      } else {
        _fecharOverlay();
      }
    } catch (e) {
      print('Erro ao buscar placas: $e');
      setState(() {
        _sugestoes.clear();
        _carregando = false;
      });
      _fecharOverlay();
    }
  }

  void _onTextChanged(String texto) {
    if (!widget.enabled) return;
    
    _debounceTimer?.cancel();
    
    if (texto.length < 3) {
      setState(() {
        _sugestoes.clear();
      });
      _fecharOverlay();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _buscarPlacas(texto);
      }
    });

    if (widget.onChanged != null) {
      widget.onChanged!(texto);
    }
  }

  void _onPlacaSelecionada(String placa) {
    if (!widget.enabled) return;
    
    widget.controller.text = placa;
    setState(() {
      _sugestoes.clear();
    });
    _fecharOverlay();
    _internalFocusNode.unfocus();
    
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: placa.length),
    );
  }

  void _mostrarOverlay() {
    if (!widget.enabled) return;
    
    if (_sugestoes.isEmpty || _overlayEntry != null) return;

    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        top: offset.dy + size.height + 4,
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
                  final placa = _sugestoes[index];
                  return ListTile(
                    title: Text(
                      placa,
                      style: const TextStyle(fontSize: 14),
                    ),
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    onTap: () => _onPlacaSelecionada(placa),
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
            maxLength: 8,
            textCapitalization: TextCapitalization.characters,
            onChanged: _onTextChanged,
            enabled: widget.enabled,
            decoration: InputDecoration(
              labelText: widget.label,
              counterText: '',
              hintText: '',
              filled: true,
              fillColor: widget.enabled ? Colors.white : Colors.grey[200],
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

// ================= PÁGINA PRINCIPAL =================
class EmitirCertificadoPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final String? idCertificado;
  final String? idMovimentacao;
  final List<Map<String, dynamic>>? tanquesDaOrdem; // NOVA: Lista de tanques da ordem
  final bool modoSomenteVisualizacao;

  const EmitirCertificadoPage({
    super.key,
    required this.onVoltar,
    this.idCertificado,
    this.idMovimentacao,
    this.tanquesDaOrdem,
    this.modoSomenteVisualizacao = false,
  });

  @override
  State<EmitirCertificadoPage> createState() =>
      _EmitirCertificadoPageState();
}

class _EmitirCertificadoPageState extends State<EmitirCertificadoPage> {
  final _formKey = GlobalKey<FormState>();
  bool _modoVisualizacao = false;
  Map<String, dynamic>? _dadosExistentes;
  bool _carregandoDadosMovimentacao = false;
  bool _salvandoCertificado = false;

  // ================= CONTROLLERS =================
  final TextEditingController dataCtrl = TextEditingController();
  final TextEditingController horaCtrl = TextEditingController();
  // FocusNode removido - não é mais usado
  // final FocusNode _focusTempCT = FocusNode();

  final Map<String, TextEditingController?> campos = {
    'numeroControle': TextEditingController(),
    'transportadora': TextEditingController(),
    'motorista': TextEditingController(),
    'notas': TextEditingController(),

    'placaCavalo': TextEditingController(),
    'carreta1': TextEditingController(),
    'carreta2': TextEditingController(),

    // Campos abaixo não são mais usados na UI - dados vêm do dialog de cada tanque
    // Mantidos por compatibilidade com código legado (podem ser removidos futuramente)
    'tempAmostra': TextEditingController(),
    'densidadeAmostra': TextEditingController(),
    'tempCT': TextEditingController(),
    'densidade20': TextEditingController(),
    'fatorCorrecao': TextEditingController(),
  };

  // ================= LISTA DE TANQUES =================
  List<TanqueDados> _tanques = [];

  // ================= PRODUTOS =================
  List<String> produtos = [];
  String? produtoSelecionado;
  bool carregandoProdutos = true;

  @override
  void initState() {
    super.initState();
    _setarDataHoraAtual();
    _carregarProdutos();
    _inicializarTanquesDaOrdem(); // Inicializa tanques baseado na ordem

    // Listener removido - cálculos agora são feitos no dialog de cada tanque
    // _focusTempCT.addListener(() { ... });

    if (widget.modoSomenteVisualizacao || (widget.idCertificado != null && widget.idCertificado!.isNotEmpty)) {
      // MODO VISUALIZAÇÃO - Forçado pelo parâmetro ou certificado já existe
      _modoVisualizacao = true;
      if (widget.idCertificado != null && widget.idCertificado!.isNotEmpty) {
        _carregarDadosCertificado(widget.idCertificado!);
      }
    } else {
      // MODO CRIAÇÃO - Novo certificado
      _modoVisualizacao = false;
      if (widget.idMovimentacao != null && widget.idMovimentacao!.isNotEmpty) {
        _carregarDadosMovimentacao(widget.idMovimentacao!);
      }
    }
  }

  Future<void> _carregarDadosMovimentacao(String idMovimentacao) async {
    setState(() {
      _carregandoDadosMovimentacao = true;
    });

    try {
      final supabase = Supabase.instance.client;

      final movimentacao = await supabase
          .from('movimentacoes')
          .select('''
            *,
            produtos:produto_id(nome),
            motoristas:motorista_id(nome),
            transportadoras:transportadora_id(nome),
            nota_fiscal
          ''')
          .eq('id', idMovimentacao)
          .maybeSingle();

      if (movimentacao != null) {
        if (movimentacao['nota_fiscal'] != null) {
          campos['notas']!.text =
              movimentacao['nota_fiscal'].toString();
        }

        if (movimentacao['produtos'] != null &&
            movimentacao['produtos']['nome'] != null) {
          produtoSelecionado =
              movimentacao['produtos']['nome'].toString();
        }

        if (movimentacao['motoristas'] != null &&
            movimentacao['motoristas']['nome'] != null) {
          campos['motorista']!.text =
              movimentacao['motoristas']['nome'].toString();
        }

        if (movimentacao['transportadoras'] != null &&
            movimentacao['transportadoras']['nome'] != null) {
          campos['transportadora']!.text =
              movimentacao['transportadoras']['nome'].toString();
        }

        if (movimentacao['placa'] != null &&
            movimentacao['placa'] is List) {
          final placas =
              List<String>.from(movimentacao['placa']);
          if (placas.isNotEmpty) {
            campos['placaCavalo']!.text = placas[0];
            if (placas.length > 1) {
              campos['carreta1']!.text = placas[1];
            }
            if (placas.length > 2) {
              campos['carreta2']!.text = placas[2];
            }
          }
        }

        // Nota: Os volumes dos tanques já são preenchidos em _inicializarTanquesDaOrdem()
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar dados: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      setState(() {
        _carregandoDadosMovimentacao = false;
      });
    }
  }

  Future<void> _carregarDadosCertificado(String idCertificado) async {
    try {
      final supabase = Supabase.instance.client;
      
      final dados = await supabase
          .from('ordens_analises')
          .select('*')
          .eq('id', idCertificado)
          .single();
      
      _dadosExistentes = Map<String, dynamic>.from(dados);
      
      _preencherCamposComDadosExistentes();
      
      // Carregar dados das coletas dos tanques
      final movimentacaoId = _dadosExistentes!['movimentacao_id']?.toString();
      if (movimentacaoId != null && movimentacaoId.isNotEmpty) {
        await _carregarDadosColetasTanques(movimentacaoId);
      }
      
    } catch (e) {
      print('Erro ao carregar certificado: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar certificado: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
  
  // Método para carregar dados específicos de cada tanque da tabela coletas_tanques
  Future<void> _carregarDadosColetasTanques(String movimentacaoId) async {
    try {
      final supabase = Supabase.instance.client;
      
      final coletas = await supabase
          .from('coletas_tanques')
          .select('*')
          .eq('movimentacao_id', movimentacaoId)
          .order('tanque_numero');
      
      if (coletas.isEmpty) return;
      
      setState(() {
        // Preencher dados de cada tanque com os dados salvos
        for (int i = 0; i < coletas.length && i < _tanques.length; i++) {
          final coleta = coletas[i];
          final tanque = _tanques[i];
          
          // Dados da coleta
          tanque.tempAmostra = _formatarDecimalParaExibicao(coleta['temperatura_amostra']);
          tanque.densidadeObservada = _formatarDecimalParaExibicao(coleta['densidade_observada']);
          tanque.tempCT = _formatarDecimalParaExibicao(coleta['temperatura_ct']);
          
          // Volumes
          if (coleta['volume_amb'] != null) {
            tanque.volumeAmbCtrl.text = _mascaraMilharUI(coleta['volume_amb'].toString());
          }
          if (coleta['volume_vinte'] != null) {
            tanque.volume20CCtrl.text = _mascaraMilharUI(coleta['volume_vinte'].toString());
          }
        }
      });
      
      print('✓ Dados de ${coletas.length} tanque(s) carregados da tabela coletas_tanques');
    } catch (e) {
      print('Erro ao carregar dados das coletas: $e');
      // Não lança exceção para não bloquear a visualização do certificado
    }
  }
  
  void _preencherCamposComDadosExistentes() {
    if (_dadosExistentes == null) return;

    setState(() {
      campos['numeroControle']!.text =
          _dadosExistentes!['numero_controle']?.toString() ?? '';
      campos['transportadora']!.text =
          _dadosExistentes!['transportadora']?.toString() ?? '';
      campos['motorista']!.text =
          _dadosExistentes!['motorista']?.toString() ?? '';
      campos['notas']!.text =
          _dadosExistentes!['notas_fiscais']?.toString() ?? '';

      campos['placaCavalo']!.text =
          _dadosExistentes!['placa_cavalo']?.toString() ?? '';
      campos['carreta1']!.text =
          _dadosExistentes!['carreta1']?.toString() ?? '';
      campos['carreta2']!.text =
          _dadosExistentes!['carreta2']?.toString() ?? '';

      // Preencher dados da coleta no primeiro tanque
      if (_tanques.isNotEmpty) {
        _tanques[0].tempAmostra =
            _formatarDecimalParaExibicao(_dadosExistentes!['temperatura_amostra']);
        _tanques[0].densidadeObservada =
            _formatarDecimalParaExibicao(_dadosExistentes!['densidade_observada']);
        _tanques[0].tempCT =
            _formatarDecimalParaExibicao(_dadosExistentes!['temperatura_ct']);
        _tanques[0].densidade20C =
            _formatarDecimalParaExibicao(_dadosExistentes!['densidade_20c']);
        _tanques[0].fatorCorrecao =
            _formatarDecimalParaExibicao(_dadosExistentes!['fator_correcao']);

        // Preenche volumes do primeiro tanque
        final origemAmb = _dadosExistentes!['origem_ambiente'];
        if (origemAmb != null) {
          _tanques[0].volumeAmbCtrl.text =
              _mascaraMilharUI(origemAmb.toString());
        }

        final destino20 = _dadosExistentes!['destino_20c'];
        if (destino20 != null) {
          _tanques[0].volume20CCtrl.text =
              _mascaraMilharUI(destino20.toString());
        }
      }

      if (_dadosExistentes!['data_analise'] != null) {
        try {
          final data = DateTime.parse(_dadosExistentes!['data_analise']);
          dataCtrl.text =
              '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
        } catch (_) {}
      }

      if (_dadosExistentes!['hora_analise'] != null) {
        horaCtrl.text = _dadosExistentes!['hora_analise'].toString();
      }

      produtoSelecionado =
          _dadosExistentes!['produto_nome']?.toString();
    });
  }
  
  String _formatarDecimalParaExibicao(dynamic valor) {
    if (valor == null) return '';
    
    try {
      String texto = valor.toString();
      if (texto.contains('.')) {
        texto = texto.replaceAll('.', ',');
      }
      return texto;
    } catch (e) {
      return '';
    }
  }

  void _setarDataHoraAtual() {
    final agora = DateTime.now();
    dataCtrl.text =
        '${agora.day.toString().padLeft(2, '0')}/${agora.month.toString().padLeft(2, '0')}/${agora.year}';
    horaCtrl.text =
        '${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _carregarProdutos() async {
    try {
      final dados = await Supabase.instance.client
          .from('produtos')
          .select('nome')
          .order('nome');

      setState(() {
        produtos =
            dados.map<String>((p) => p['nome'].toString()).toList();
        carregandoProdutos = false;
      });
    } catch (_) {
      carregandoProdutos = false;
    }
  }

  // ================= CÁLCULOS =================
  Future<void> _calcularResultadosObtidos() async {
    if (_modoVisualizacao) return;

    if (produtoSelecionado == null) return;

    final tempAmostra = campos['tempAmostra']!.text;
    final densObs = campos['densidadeAmostra']!.text;
    final tempCT = campos['tempCT']!.text;

    campos['densidade20']!.text = '';
    campos['fatorCorrecao']!.text = '';

    if (tempAmostra.isEmpty || densObs.isEmpty) return;

    final dens20 = await _buscarDensidade20C(
      temperaturaAmostra: tempAmostra,
      densidadeObservada: densObs,
      produtoNome: produtoSelecionado!,
    );

    campos['densidade20']!.text = dens20;

    if (dens20 == '-' || dens20.isEmpty || tempCT.isEmpty) {
      campos['fatorCorrecao']!.text = '-';
      setState(() {});
      return;
    }

    final fcv = await _buscarFCV(
      temperaturaTanque: tempCT,
      densidade20C: dens20,
      produtoNome: produtoSelecionado!,
    );

    if (fcv != '-' && fcv.isNotEmpty) {
      campos['fatorCorrecao']!.text = fcv;
    } else {
      campos['fatorCorrecao']!.text = '-';
    }

    // Calcular volume 20°C para todos os tanques que tiverem volume ambiente preenchido
    if (fcv != '-' && fcv.isNotEmpty) {
      _calcularVolumeApurado20C();
    }

    setState(() {});
  }

  String _formatarNumeroParaCampo(double valor) {
    if (valor.isNaN || valor.isInfinite) return '';

    final valorInteiro = valor.round();
    return _aplicarMascaraMilhar(valorInteiro.toString());
  }

  String _aplicarMascaraMilhar(String texto) {
    final apenasNumeros = texto.replaceAll(RegExp(r'[^\d]'), '');

    if (apenasNumeros.isEmpty || apenasNumeros == '0') return '0';

    String resultado = '';
    for (int i = apenasNumeros.length - 1, c = 0; i >= 0; i--, c++) {
      if (c > 0 && c % 3 == 0) resultado = '.$resultado';
      resultado = apenasNumeros[i] + resultado;
    }

    return resultado;
  }

  void _calcularVolumeApurado20C() {
    if (_modoVisualizacao) return;

    final fcvText = campos['fatorCorrecao']!.text;
    if (fcvText.isEmpty || fcvText == '-') return;

    // Calcula para todos os tanques
    for (var tanque in _tanques) {
      _calcularVolume20CTanque(tanque);
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ================= HEADER =================
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                onPressed: _voltar,
              ),
              const Text(
                'Certificado de Apuração de Volumes',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                ),
              ),
              if (_modoVisualizacao)
                Container(
                  margin: const EdgeInsets.only(left: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Certificado Emitido',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const Divider(),

          // ================= CONTEÚDO =================
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // ================= LOADING =================
                          if (_carregandoDadosMovimentacao)
                            Container(
                              padding: const EdgeInsets.all(20),
                              child: const Column(
                                children: [
                                  CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D47A1)),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Carregando dados da movimentação...',
                                    style: TextStyle(
                                      color: Color(0xFF0D47A1),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          // ================= FORMULÁRIO =================
                          Opacity(
                            opacity: _carregandoDadosMovimentacao ? 0.5 : 1.0,
                            child: AbsorbPointer(
                              absorbing: _modoVisualizacao || _carregandoDadosMovimentacao,
                              child: Column(
                                children: [
                                  // ================= NÚMERO DE CONTROLE =================
                                  _linha([
                                    Material(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: TextFormField(
                                        controller: campos['numeroControle'],
                                        enabled: false,
                                        decoration: _decoration('Nº Controle do Certificado').copyWith(
                                          hintText: _modoVisualizacao ? '' : 'A ser gerado automaticamente',
                                          filled: true,
                                          fillColor: Colors.grey[200],
                                        ),
                                        style: const TextStyle(
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ]),
                                  const SizedBox(height: 12),
                                  _linhaFlexivel([
                                    {
                                      'flex': 5,
                                      'widget': TextFormField(
                                                  controller: campos['notas'],
                                                  keyboardType: TextInputType.number,
                                                  onChanged: _modoVisualizacao ? null : (value) {
                                                    final cursorPosition = campos['notas']!.selection.baseOffset;
                                                    final maskedValue = _aplicarMascaraNotasFiscais(value);

                                                    if (maskedValue != value) {
                                                      campos['notas']!.value = TextEditingValue(
                                                        text: maskedValue,
                                                        selection: TextSelection.collapsed(
                                                          offset: cursorPosition + (maskedValue.length - value.length),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  enabled: !_modoVisualizacao,
                                                  decoration: _decoration('Notas Fiscais').copyWith(
                                                    hintText: '',
                                                    fillColor: _modoVisualizacao ? Colors.grey[200] : Colors.white,
                                                  ),
                                                ),
                                    },
                                    {
                                      'flex': 5,
                                      'widget': carregandoProdutos
                                          ? const Center(
                                              child: SizedBox(
                                                width: 24,
                                                height: 24,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  color: Color(0xFF0D47A1),
                                                ),
                                              ),
                                            )
                                          : DropdownButtonFormField<String>(
                                              value: produtoSelecionado,
                                              items: produtos
                                                  .map(
                                                    (p) => DropdownMenuItem(
                                                      value: p,
                                                      child: Text(p),
                                                    ),
                                                  )
                                                  .toList(),
                                              onChanged: _modoVisualizacao ? null : (valor) {
                                                setState(() {
                                                  produtoSelecionado = valor;
                                                });
                                                _calcularResultadosObtidos();
                                              },
                                              decoration: _decoration('Produto').copyWith(
                                                fillColor: _modoVisualizacao ? Colors.grey[200] : Colors.white,
                                              ),
                                            ),
                                    },
                                    {
                                      'flex': 3,
                                      'widget': _campo('Data', dataCtrl, enabled: false),
                                    },
                                    {
                                      'flex': 2,
                                      'widget': _campo('Hora', horaCtrl, enabled: false),
                                    },
                                  ]),
                                  const SizedBox(height: 12),
                                  
                                  _linhaFlexivel([
                                    {
                                      'flex': 10,
                                      'widget': TextFormField(
                                        controller: campos['motorista'],
                                        maxLength: 50,
                                        enabled: !_modoVisualizacao,
                                        decoration: _decoration('Motorista').copyWith(
                                          counterText: '',
                                          fillColor: _modoVisualizacao ? Colors.grey[200] : Colors.white,
                                        ),
                                      ),
                                    },
                                    {
                                      'flex': 10,
                                      'widget': TextFormField(
                                        controller: campos['transportadora'],
                                        maxLength: 50,
                                        enabled: !_modoVisualizacao,
                                        decoration: _decoration('Transportadora').copyWith(
                                          counterText: '',
                                          fillColor: _modoVisualizacao ? Colors.grey[200] : Colors.white,
                                        ),
                                      ),
                                    },
                                  ]),
                                  const SizedBox(height: 12),                                
                                  // LINHA COM OS 3 CAMPOS DE PLACA - COM AUTOCOMPLETE
                                  _linhaFlexivel([
                                    {
                                      'flex': 4,
                                      'widget': PlacaAutocompleteField(
                                        controller: campos['placaCavalo']!,
                                        label: 'Placa do cavalo',
                                        enabled: !_modoVisualizacao,
                                      ),
                                    },
                                    {
                                      'flex': 4,
                                      'widget': PlacaAutocompleteField(
                                        controller: campos['carreta1']!,
                                        label: 'Carreta 1',
                                        enabled: !_modoVisualizacao,
                                      ),
                                    },
                                    {
                                      'flex': 4,
                                      'widget': PlacaAutocompleteField(
                                        controller: campos['carreta2']!,
                                        label: 'Carreta 2',
                                        enabled: !_modoVisualizacao,
                                      ),
                                    },
                                  ]),
                                  const SizedBox(height: 20),
                                  
                                  // ======== CAMPOS REMOVIDOS - AGORA PREENCHIDOS NO DIALOG DE CADA TANQUE ========
                                  // _secao('Coletas na presença do motorista'),
                                  // _linha([... campos de temperatura, densidade, etc ...])
                                  // _secao('Resultados obtidos'),
                                  // _linha([... campos de densidade 20°C e FCV ...])
                                  // ================================================================================
                                  
                                  _secao('Volumes apurados'),
                                  _buildSecaoTanques(),
                                  const SizedBox(height: 40),
                                ],
                              ),
                            ),
                          ),
                          if (!_carregandoDadosMovimentacao)
                          // ================= BOTÕES =================
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // BOTÃO VOLTAR
                              ElevatedButton.icon(
                                onPressed: _voltar,
                                icon: const Icon(Icons.arrow_back, size: 24),
                                label: const Text(
                                  'Voltar',
                                  style: TextStyle(fontSize: 16),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),

                              // BOTÃO GERAR PDF
                              ElevatedButton.icon(
                                onPressed: _modoVisualizacao ? _baixarPDF : null,
                                icon: const Icon(Icons.picture_as_pdf, size: 24),
                                label: const Text(
                                  'Gerar Certificado PDF',
                                  style: TextStyle(fontSize: 16),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _modoVisualizacao
                                      ? const Color(0xFF0D47A1)
                                      : Colors.grey[300],
                                  foregroundColor:
                                      _modoVisualizacao ? Colors.white : Colors.grey[600],
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),

                              // BOTÃO EMITIR CERTIFICADO
                              if (!_modoVisualizacao)
                                ElevatedButton.icon(
                                  onPressed: _salvandoCertificado ? null : _confirmarEmissaoCertificado,
                                  icon: _salvandoCertificado 
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.check_circle, size: 24),
                                  label: Text(
                                    _salvandoCertificado ? 'Emitindo...' : 'Emitir certificado',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                )
                              else
                                ElevatedButton.icon(
                                  onPressed: null,
                                  icon: const Icon(Icons.check_circle, size: 24),
                                  label: const Text(
                                    'Certificado emitido',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[400],
                                    foregroundColor: Colors.white,
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= MÉTODOS DE GERENCIAMENTO DE TANQUES =================
  
  void _inicializarTanquesDaOrdem() {
    if (widget.tanquesDaOrdem != null && widget.tanquesDaOrdem!.isNotEmpty) {
      // Criar tanques baseado na lista recebida
      for (var tanqueInfo in widget.tanquesDaOrdem!) {
        final novoTanque = TanqueDados(
          id: tanqueInfo['movimentacao_id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
          volumeAmbCtrl: TextEditingController(),
          volume20CCtrl: TextEditingController(),
          buscarDoBanco: false,
          produtoNome: tanqueInfo['produto_nome']?.toString(),
          produtoId: tanqueInfo['produto_id']?.toString(),
        );
        
        // Preencher valores iniciais se disponíveis
        if (tanqueInfo['saida_amb'] != null) {
          novoTanque.volumeAmbCtrl.text = _mascaraMilharUI(tanqueInfo['saida_amb'].toString());
        }
        if (tanqueInfo['saida_vinte'] != null) {
          novoTanque.volume20CCtrl.text = _mascaraMilharUI(tanqueInfo['saida_vinte'].toString());
        }
        
        _tanques.add(novoTanque);
      }
    } else {
      // Caso não tenha tanques da ordem, criar um padrão
      _tanques.add(TanqueDados(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        volumeAmbCtrl: TextEditingController(),
        volume20CCtrl: TextEditingController(),
        buscarDoBanco: false,
      ));
    }
  }

  void _toggleBuscarDoBanco(String id, bool valor) {
    setState(() {
      final index = _tanques.indexWhere((t) => t.id == id);
      if (index != -1) {
        _tanques[index].buscarDoBanco = valor;
        // TODO: Implementar busca no banco quando necessário
      }
    });
  }

  // ================= DIALOG DADOS DA COLETA =================
  Future<void> _abrirDialogDadosColeta(TanqueDados tanque, int numeroTanque) async {
    // Controllers temporários para o dialog
    final tempAmostraCtrl = TextEditingController(text: tanque.tempAmostra ?? '');
    final densObsCtrl = TextEditingController(text: tanque.densidadeObservada ?? '');
    final tempCTCtrl = TextEditingController(text: tanque.tempCT ?? '');
    final dens20Ctrl = TextEditingController(text: tanque.densidade20C ?? '');
    final fcvCtrl = TextEditingController(text: tanque.fatorCorrecao ?? '');
    
    // Função local para calcular densidade 20°C e FCV
    Future<void> calcularResultados(void Function(void Function()) setStateDialog) async {
      if (produtoSelecionado == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecione um produto primeiro!'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      final tempAmostra = tempAmostraCtrl.text;
      final densObs = densObsCtrl.text;
      final tempCT = tempCTCtrl.text;
      
      if (tempAmostra.isEmpty || densObs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preencha temperatura da amostra e densidade observada!'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      setStateDialog(() {
        dens20Ctrl.text = 'Calculando...';
        fcvCtrl.text = 'Calculando...';
      });
      
      // Buscar densidade 20°C
      final dens20 = await _buscarDensidade20C(
        temperaturaAmostra: tempAmostra,
        densidadeObservada: densObs,
        produtoNome: produtoSelecionado!,
      );
      
      setStateDialog(() {
        dens20Ctrl.text = dens20;
      });
      
      if (dens20 == '-' || dens20.isEmpty || tempCT.isEmpty) {
        setStateDialog(() {
          fcvCtrl.text = '-';
        });
        return;
      }
      
      // Buscar FCV
      final fcv = await _buscarFCV(
        temperaturaTanque: tempCT,
        densidade20C: dens20,
        produtoNome: produtoSelecionado!,
      );
      
      setStateDialog(() {
        fcvCtrl.text = fcv;
      });
    }
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            // Verificar se o FCV está calculado e é válido
            final fcvValido = fcvCtrl.text.isNotEmpty && 
                              fcvCtrl.text != '-' && 
                              fcvCtrl.text != 'Calculando...';
            
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
                side: const BorderSide(
                  color: Color(0xFF0D47A1),
                  width: 2.0,
                ),
              ),
              backgroundColor: Colors.white,
              title: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D47A1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.science, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'Dados da Coleta - Tanque $numeroTanque',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      
                      if (tanque.produtoNome != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.local_gas_station, color: Color(0xFF0D47A1)),
                                const SizedBox(width: 8),
                                Text(
                                  'Produto: ${tanque.produtoNome}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      // Campo: Temperatura da amostra
                      TextFormField(
                        controller: tempAmostraCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          String masked = _aplicarMascaraTemperatura(value);
                          if (masked != value) {
                            tempAmostraCtrl.value = TextEditingValue(
                              text: masked,
                              selection: TextSelection.collapsed(offset: masked.length),
                            );
                          }
                          setStateDialog(() {});
                        },
                        decoration: _decoration('Temperatura da amostra (ºC)'),
                      ),
                      const SizedBox(height: 12),
                      
                      // Campo: Densidade observada
                      TextFormField(
                        controller: densObsCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          String masked = _aplicarMascaraDensidade(value);
                          if (masked != value) {
                            densObsCtrl.value = TextEditingValue(
                              text: masked,
                              selection: TextSelection.collapsed(offset: masked.length),
                            );
                          }
                          setStateDialog(() {});
                        },
                        decoration: _decoration('Densidade observada'),
                      ),
                      const SizedBox(height: 12),
                      
                      // Campo: Temperatura do CT
                      TextFormField(
                        controller: tempCTCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          String masked = _aplicarMascaraTemperatura(value);
                          if (masked != value) {
                            tempCTCtrl.value = TextEditingValue(
                              text: masked,
                              selection: TextSelection.collapsed(offset: masked.length),
                            );
                          }
                          setStateDialog(() {});
                        },
                        decoration: _decoration('Temperatura do CT (ºC)'),
                      ),
                      const SizedBox(height: 20),
                      
                      const Divider(),
                      const SizedBox(height: 12),
                      
                      // Campo: Densidade a 20ºC (calculado)
                      TextFormField(
                        controller: dens20Ctrl,
                        enabled: false,
                        decoration: _decoration('Densidade a 20ºC').copyWith(
                          fillColor: Colors.grey[100],
                          suffixIcon: const Icon(Icons.calculate, color: Colors.green),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Campo: FCV (calculado)
                      TextFormField(
                        controller: fcvCtrl,
                        enabled: false,
                        decoration: _decoration('Fator de correção de volume (FCV)').copyWith(
                          fillColor: Colors.grey[100],
                          suffixIcon: const Icon(Icons.calculate, color: Colors.green),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              actions: [
                // Layout customizado: Calcular à esquerda, Voltar e Salvar à direita
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Botão Calcular - à esquerda
                      ElevatedButton.icon(
                        onPressed: () => calcularResultados(setStateDialog),
                        icon: const Icon(Icons.calculate, size: 20),
                        label: const Text(
                          'Calcular',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      
                      // Botões Voltar e Salvar - à direita
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[700],
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: Colors.grey[400]!),
                              ),
                            ),
                            child: const Text(
                              'Voltar',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: !fcvValido ? null : () {
                              // Validar campos obrigatórios
                              if (tempAmostraCtrl.text.isEmpty || 
                                  densObsCtrl.text.isEmpty || 
                                  tempCTCtrl.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Preencha todos os campos obrigatórios!'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }
                              
                              // Validar que FCV foi calculado
                              if (!fcvValido) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Clique em "Calcular" antes de salvar!'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }
                              
                              // Salvar dados no tanque
                              setState(() {
                                tanque.tempAmostra = tempAmostraCtrl.text;
                                tanque.densidadeObservada = densObsCtrl.text;
                                tanque.tempCT = tempCTCtrl.text;
                                tanque.densidade20C = dens20Ctrl.text;
                                tanque.fatorCorrecao = fcvCtrl.text;
                              });
                              
                              // Recalcular volume 20°C com o novo FCV
                              _calcularVolume20CTanque(tanque);
                              
                              Navigator.of(dialogContext).pop();
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✓ Dados da coleta salvos para Tanque $numeroTanque!'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: fcvValido ? Colors.green : Colors.grey[300],
                              foregroundColor: fcvValido ? Colors.white : Colors.grey[600],
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Salvar',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              actionsPadding: EdgeInsets.zero, // Remove padding padrão pois já temos padding customizado
            );
          },
        );
      },
    );
    
    // Limpar recursos
    tempAmostraCtrl.dispose();
    densObsCtrl.dispose();
    tempCTCtrl.dispose();
    dens20Ctrl.dispose();
    fcvCtrl.dispose();
  }

  Widget _buildSecaoTanques() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Lista de tanques
        ..._tanques.asMap().entries.map((entry) {
          final index = entry.key;
          final tanque = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildLinhaTanque(tanque, index + 1),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildLinhaTanque(TanqueDados tanque, int numeroTanque) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[50],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho com número do tanque e produto
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tanque $numeroTanque${tanque.produtoNome != null ? " - ${tanque.produtoNome}" : ""}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF0D47A1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Campos de volume e switch
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: TextFormField(
                    controller: tanque.volumeAmbCtrl,
                    keyboardType: TextInputType.number,
                    enabled: !_modoVisualizacao,
                    onChanged: (value) => _calcularVolume20CTanque(tanque),
                    decoration: _decoration('Volume carregado (ambiente)').copyWith(
                      fillColor: _modoVisualizacao ? Colors.grey[100] : Colors.white,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: TextFormField(
                    controller: tanque.volume20CCtrl,
                    keyboardType: TextInputType.number,
                    enabled: false,
                    decoration: _decoration('Volume apurado a 20 ºC').copyWith(
                      fillColor: Colors.grey[100],
                    ),
                  ),
                ),
              ),
              // Ícone de dados da coleta
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.science_outlined,
                        color: tanque.tempAmostra != null ? Colors.green : Color(0xFF0D47A1),
                        size: 28,
                      ),
                      tooltip: 'Dados da Coleta',
                      onPressed: _modoVisualizacao ? null : () => _abrirDialogDadosColeta(tanque, numeroTanque),
                    ),
                    Text(
                      'Dados da\nColeta',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: tanque.tempAmostra != null ? Colors.green : Color(0xFF0D47A1),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Buscar do banco',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF0D47A1),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Switch(
                        value: tanque.buscarDoBanco,
                        onChanged: _modoVisualizacao 
                            ? null 
                            : (valor) => _toggleBuscarDoBanco(tanque.id, valor),
                        activeColor: const Color(0xFF0D47A1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _calcularVolume20CTanque(TanqueDados tanque) {
    if (_modoVisualizacao) return;

    // Usar o FCV específico deste tanque (do dialog de dados da coleta)
    final fcvText = tanque.fatorCorrecao;
    if (fcvText == null || fcvText.isEmpty || fcvText == '-') {
      tanque.volume20CCtrl.text = '';
      return;
    }

    final volumeAmbText = tanque.volumeAmbCtrl.text;
    if (volumeAmbText.isEmpty) {
      tanque.volume20CCtrl.text = '';
      return;
    }

    final volumeAmb = double.tryParse(volumeAmbText.replaceAll('.', ''));
    final fcv = double.tryParse(fcvText.replaceAll(',', '.'));

    if (volumeAmb == null || fcv == null) return;

    final volume20C = volumeAmb * fcv;
    tanque.volume20CCtrl.text = _formatarNumeroParaCampo(volume20C);

    setState(() {});
  }

  // ================= UI HELPERS =================
  Widget _linha(List<Widget> campos) => Row(
        children: campos
            .map((c) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: c,
                  ),
                ))
            .toList(),
      );

  Widget _linhaFlexivel(List<Map<String, dynamic>> camposConfig) => Row(
        children: camposConfig
            .map((config) => Expanded(
                  flex: config['flex'] ?? 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: config['widget'],
                  ),
                ))
            .toList(),
      );

  Widget _campo(String label, TextEditingController c,
      {bool enabled = true}) {
    return Material(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextFormField(
        controller: c,
        enabled: enabled,
        decoration: _decoration(label, disabled: !enabled).copyWith(
          fillColor: enabled ? Colors.white : Colors.grey[200],
        ),
      ),
    );
  }

  InputDecoration _decoration(String label,
          {bool disabled = false}) =>
      InputDecoration(
        labelText: label,
        filled: true,
        fillColor: disabled ? Colors.grey[200] : Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6)),
      );

  Widget _secao(String t) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 6),
          Text(
            t.toUpperCase(),
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1)),
          ),
          const SizedBox(height: 10),
        ],
      );

  // ================= CÁLCULOS =================
  Future<String> _buscarDensidade20C({
    required String temperaturaAmostra,
    required String densidadeObservada,
    required String produtoNome,
  }) async {
    final supabase = Supabase.instance.client;
    
    try {
      if (temperaturaAmostra.isEmpty || densidadeObservada.isEmpty) {
        return '-';
      }
      
      final nomeProdutoLower = produtoNome.toLowerCase().trim();
      final bool usarViewAnidroHidratado = 
          nomeProdutoLower.contains('anidro') || 
          nomeProdutoLower.contains('hidratado');
      
      String temperaturaFormatada = temperaturaAmostra
          .replaceAll(' ºC', '')
          .replaceAll('°C', '')
          .replaceAll('ºC', '')
          .replaceAll('°', '')
          .replaceAll('C', '')
          .trim();
      
      temperaturaFormatada = temperaturaFormatada.replaceAll('.', ',');
      
      String densidadeFormatada = densidadeObservada
          .replaceAll(' ', '')
          .replaceAll('°C', '')
          .replaceAll('ºC', '')
          .replaceAll('°', '')
          .trim();
      
      densidadeFormatada = densidadeFormatada.replaceAll('.', ',');
      
      if (!densidadeFormatada.contains(',')) {
        if (densidadeFormatada.length == 4) {
          densidadeFormatada = '0,${densidadeFormatada.substring(0, 3)}';
        } else {
          densidadeFormatada = '0,$densidadeFormatada';
        }
      }
      
      String nomeColuna;
      if (densidadeFormatada.contains(',')) {
        final partes = densidadeFormatada.split(',');
        if (partes.length == 2) {
          String parteInteira = partes[0];
          String parteDecimal = partes[1];
          
          parteDecimal = parteDecimal.padRight(4, '0');
          
          if (parteDecimal.length > 4) {
            parteDecimal = parteDecimal.substring(0, 4);
          }
          
          String densidade5Digitos = '${parteInteira}${parteDecimal}'.padLeft(5, '0');
          
          if (densidade5Digitos.length > 5) {
            densidade5Digitos = densidade5Digitos.substring(0, 5);
          }
          
          nomeColuna = 'd_$densidade5Digitos';
        } else {
          return '-';
        }
      } else {
        return '-';
      }
      
      final nomeView = usarViewAnidroHidratado 
          ? 'tcd_anidro_hidratado_vw' 
          : 'tcd_gasolina_diesel_vw';
      
      String _formatarResultado(String valorBruto) {
        String valorLimpo = valorBruto.trim();
        valorLimpo = valorLimpo.replaceAll('.', ',');
        
        if (!valorLimpo.contains(',')) {
          valorLimpo = '$valorLimpo,0';
        }
        
        final partes = valorLimpo.split(',');
        if (partes.length == 2) {
          String parteInteira = partes[0];
          String parteDecimal = partes[1];
          
          parteDecimal = parteDecimal.padRight(4, '0');
          
          if (parteDecimal.length > 4) {
            parteDecimal = parteDecimal.substring(0, 4);
          }
          
          return '$parteInteira,$parteDecimal';
        }
        
        return valorLimpo;
      }
      
      final resultado = await supabase
          .from(nomeView)
          .select(nomeColuna)
          .eq('temperatura_obs', temperaturaFormatada)
          .maybeSingle();
      
      if (resultado != null && resultado[nomeColuna] != null) {
        String valorBruto = resultado[nomeColuna].toString();
        return _formatarResultado(valorBruto);
      }
      
      List<String> formatosParaTentar = [];
      
      if (temperaturaFormatada.contains(',')) {
        final partes = temperaturaFormatada.split(',');
        if (partes.length == 2) {
          String parteInteira = partes[0];
          String parteDecimal = partes[1];
          
          if (usarViewAnidroHidratado) {
            formatosParaTentar.addAll([
              '$parteInteira,$parteDecimal',
              '$parteInteira,${parteDecimal}0',
              '$parteInteira,${parteDecimal.padLeft(2, '0')}',
              '$parteInteira,0$parteDecimal',
            ]);
            
            if (parteDecimal.length == 1) {
              formatosParaTentar.add('$parteInteira,${parteDecimal}0');
            }
            
            if (parteDecimal.length == 2) {
              formatosParaTentar.add('$parteInteira,${parteDecimal.substring(0, 1)}');
            }
          } else {
            formatosParaTentar.addAll([
              '$parteInteira,$parteDecimal',
              '$parteInteira,${parteDecimal}0',
              '$parteInteira,0',
            ]);
          }
        }
      } else {
        if (usarViewAnidroHidratado) {
          formatosParaTentar.addAll([
            '$temperaturaFormatada,00',
            '$temperaturaFormatada,0',
            temperaturaFormatada,
          ]);
        } else {
          formatosParaTentar.addAll([
            '$temperaturaFormatada,0',
            temperaturaFormatada,
            '$temperaturaFormatada,00',
          ]);
        }
      }
      
      final formatosComPonto = formatosParaTentar.map((f) => f.replaceAll(',', '.')).toList();
      formatosParaTentar.addAll(formatosComPonto);
      formatosParaTentar = formatosParaTentar.toSet().toList();
      
      for (final formatoTemp in formatosParaTentar) {
        try {
          final resultado = await supabase
              .from(nomeView)
              .select(nomeColuna)
              .eq('temperatura_obs', formatoTemp)
              .maybeSingle();
          
          if (resultado != null && resultado[nomeColuna] != null) {
            String valorBruto = resultado[nomeColuna].toString();
            return _formatarResultado(valorBruto);
          }
        } catch (e) {
          continue;
        }
      }
      
      return '-';
      
    } catch (e) {
      return '-';
    }
  }

  Future<String> _buscarFCV({
    required String temperaturaTanque,
    required String densidade20C,
    required String produtoNome,
  }) async {
    final supabase = Supabase.instance.client;

    try {
      if (temperaturaTanque.isEmpty ||
          temperaturaTanque == '-' ||
          densidade20C.isEmpty ||
          densidade20C == '-') {
        return '-';
      }

      final nomeProdutoLower = produtoNome.toLowerCase().trim();
      final nomeView = (nomeProdutoLower.contains('anidro') ||
              nomeProdutoLower.contains('hidratado'))
          ? 'tcv_anidro_hidratado_vw'
          : 'tcv_gasolina_diesel_vw';

      String temperaturaFormatada = temperaturaTanque
          .replaceAll('°C', '')
          .replaceAll('ºC', '')
          .replaceAll('°', '')
          .replaceAll('C', '')
          .trim()
          .replaceAll('.', ',');

      String densidadeFormatada =
          densidade20C.trim().replaceAll('.', ',');

      final densidadeNum =
          double.tryParse(densidadeFormatada.replaceAll(',', '.'));

      if (densidadeNum == null) {
        return '-';
      }

      String _formatarFCV(String valor) {
        String v = valor.replaceAll('.', ',').trim();

        if (!v.contains(',')) {
          return '$v,0000';
        }

        final partes = v.split(',');
        String inteiro = partes[0];
        String decimal = partes[1];

        decimal = decimal.padRight(4, '0');
        if (decimal.length > 4) {
          decimal = decimal.substring(0, 4);
        }

        return '$inteiro,$decimal';
      }

      String _densidadeParaCodigo(String densidade) {
        final partes = densidade.split(',');
        if (partes.length != 2) return '';
        final codigo =
            '${partes[0]}${partes[1].padRight(4, '0')}'.padLeft(5, '0');
        return codigo.length > 5 ? codigo.substring(0, 5) : codigo;
      }

      final codigoOriginal = _densidadeParaCodigo(densidadeFormatada);

      Future<String?> _buscarFCVPorCodigo(String codigo) async {
        final coluna = 'v_$codigo';

        try {
          final r = await supabase
              .from(nomeView)
              .select(coluna)
              .eq('temperatura_obs', temperaturaFormatada)
              .maybeSingle();

          if (r != null && r[coluna] != null) {
            return _formatarFCV(r[coluna].toString());
          }
        } catch (_) {}
        return null;
      }

      final direto = await _buscarFCVPorCodigo(codigoOriginal);
      if (direto != null) return direto;

      final sampleRow = await supabase
          .from(nomeView)
          .select()
          .limit(1)
          .maybeSingle();

      if (sampleRow == null) {
        return '-';
      }

      final densidadesDisponiveis = sampleRow.keys
          .where((k) => k.startsWith('v_'))
          .map((k) {
            final codigo = k.replaceFirst('v_', '');
            if (codigo.length == 5) {
              final valor =
                  double.tryParse('${codigo[0]}.${codigo.substring(1)}');
              if (valor != null) {
                return {
                  'codigo': codigo,
                  'valor': valor,
                  'diferenca': (valor - densidadeNum).abs()
                };
              }
            }
            return null;
          })
          .whereType<Map<String, dynamic>>()
          .toList();

      if (densidadesDisponiveis.isEmpty) {
        return '-';
      }

      densidadesDisponiveis.sort((a, b) {
        final da = a['diferenca'] as double;
        final db = b['diferenca'] as double;
        return da.compareTo(db);
      });

      final densidadeMaisProxima = densidadesDisponiveis.first;
      final codigoMaisProximo = densidadeMaisProxima['codigo'] as String;
      final diferenca = densidadeMaisProxima['diferenca'] as double;

      final aproximado = await _buscarFCVPorCodigo(codigoMaisProximo);
      
      if (aproximado != null) {        
        return aproximado;
      }

      final temperaturaAlternativas = [
        temperaturaFormatada,
        temperaturaFormatada.replaceAll(',', '.'),
        ..._gerarVariacoesTemperatura(temperaturaFormatada),
      ];

      for (final tempAlt in temperaturaAlternativas) {
        try {
          final r = await supabase
              .from(nomeView)
              .select('v_$codigoMaisProximo')
              .eq('temperatura_obs', tempAlt)
              .maybeSingle();

          if (r != null && r['v_$codigoMaisProximo'] != null) {
            if (context.mounted && diferenca > 0.0001) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
              });
            }
            return _formatarFCV(r['v_$codigoMaisProximo'].toString());
          }
        } catch (_) {
          continue;
        }
      }

      return '-';
    } catch (_) {
      return '-';
    }
  }

  List<String> _gerarVariacoesTemperatura(String temperatura) {
    final List<String> variacoes = [];
    
    if (temperatura.contains(',')) {
      final partes = temperatura.split(',');
      final inteiro = partes[0];
      final decimal = partes[1];
      
      variacoes.addAll([
        '$inteiro,${decimal.padRight(2, '0')}',
        '$inteiro,${decimal.substring(0, decimal.length - 1)}',
      ]);
      
      if (decimal.length > 1) {
        variacoes.add('$inteiro,${decimal.substring(0, 1)}');
      }
      
      final temperaturaComPonto = temperatura.replaceAll(',', '.');
      variacoes.addAll([
        temperaturaComPonto,
        '$inteiro.${decimal.padRight(2, '0')}',
      ]);
    } else {
      variacoes.addAll([
        '$temperatura,0',
        '$temperatura,00',
        '$temperatura.0',
        '$temperatura.00',
      ]);
    }
    
    return variacoes.toSet().toList();
  }

  // ================= DOWNLOAD PDF =================
  Future<void> _baixarPDF() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha todos os campos obrigatórios!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_modoVisualizacao) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emita o certificado primeiro para gerar o PDF!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (produtoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um produto!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    try {
      // Usar dados do primeiro tanque
      final tanquePrincipal = _tanques.isNotEmpty ? _tanques[0] : null;
      
      final dadosPDF = {
        'numeroControle': campos['numeroControle']!.text,
        'transportadora': campos['transportadora']!.text,
        'motorista': campos['motorista']!.text,
        'placaCavalo': campos['placaCavalo']!.text,
        'carreta1': campos['carreta1']!.text,
        'carreta2': campos['carreta2']!.text,
        'notas': campos['notas']!.text,
        // Usar dados da coleta do tanque principal
        'tempAmostra': tanquePrincipal?.tempAmostra ?? '',
        'densidadeAmostra': tanquePrincipal?.densidadeObservada ?? '',
        'tempCT': tanquePrincipal?.tempCT ?? '',
        'densidade20': tanquePrincipal?.densidade20C ?? '',
        'fatorCorrecao': tanquePrincipal?.fatorCorrecao ?? '',
        'volumeCarregadoAmb': tanquePrincipal?.volumeAmbCtrl.text ?? '',
        'volumeApurado20C': tanquePrincipal?.volume20CCtrl.text ?? '',
      };
      
      final pdfDocument = await CertificadoPDF.gerar(
        data: dataCtrl.text,
        hora: horaCtrl.text,
        produto: produtoSelecionado,
        campos: dadosPDF,
      );
      
      final pdfBytes = await pdfDocument.save();
      
      if (context.mounted) Navigator.of(context).pop();
      
      if (kIsWeb) {
        await _downloadForWeb(pdfBytes);
      } else {
        print('PDF gerado (${pdfBytes.length} bytes) - Plataforma não web');
        _showMobileMessage();
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Certificado baixado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
    } catch (e) {
      print('ERRO no _baixarPDF: $e');
      
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadForWeb(Uint8List bytes) async {
    try {
      final base64 = base64Encode(bytes);
      final dataUrl = 'data:application/pdf;base64,$base64';
      final fileName = 'Certificado_${produtoSelecionado ?? "Analise"}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      final jsCode = '''
        try {
          const link = document.createElement('a');
          link.href = '$dataUrl';
          link.download = '$fileName';
          link.style.display = 'none';
          
          document.body.appendChild(link);
          link.click();
          
          setTimeout(() => {
            document.body.removeChild(link);
          }, 100);
          
          console.log('Download iniciado: ' + '$fileName');
        } catch (error) {
          console.error('Erro no download automático:', error);
          window.open('$dataUrl', '_blank');
        }
      ''';
      
      js.context.callMethod('eval', [jsCode]);
      
    } catch (e) {
      print('Erro no download Web: $e');
      
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Como baixar manualmente'),
            content: const Text(
              '1. O PDF foi gerado com sucesso\n'
              '2. Se não baixou automaticamente:\n'
              '3. Clique com botão direito na tela\n'
              '4. Selecione "Salvar página como"\n'
              '5. Salve como arquivo PDF',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showMobileMessage() {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF gerado! Em breve disponível para download no mobile.'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  String _aplicarMascaraNotasFiscais(String texto) {
    String apenasNumeros = texto.replaceAll(RegExp(r'[^\d]'), '');

    if (apenasNumeros.length > 6) {
      apenasNumeros = apenasNumeros.substring(0, 6);
    }

    if (apenasNumeros.isEmpty) return '';

    if (apenasNumeros.length > 3) {
      String parteMilhar = apenasNumeros.substring(0, apenasNumeros.length - 3);
      String parteCentena = apenasNumeros.substring(apenasNumeros.length - 3);
      return '$parteMilhar.$parteCentena';
    }

    return apenasNumeros;
  }

  String _aplicarMascaraTemperatura(String texto) {
    String apenasNumeros = texto.replaceAll(RegExp(r'[^\d]'), '');

    if (apenasNumeros.length > 3) {
      apenasNumeros = apenasNumeros.substring(0, 3);
    }

    if (apenasNumeros.isEmpty) return '';

    if (apenasNumeros.length > 2) {
      return '${apenasNumeros.substring(0, 2)},${apenasNumeros.substring(2)}';
    }

    return apenasNumeros;
  }

  String _aplicarMascaraDensidade(String texto) {
    String apenasNumeros = texto.replaceAll(RegExp(r'[^\d]'), '');

    if (apenasNumeros.isEmpty) return '';

    if (apenasNumeros.length > 5) {
      apenasNumeros = apenasNumeros.substring(0, 5);
    }

    String parteInteira = apenasNumeros.substring(0, 1);
    String parteDecimal =
        apenasNumeros.length > 1 ? apenasNumeros.substring(1) : '';

    return parteDecimal.isEmpty
        ? '$parteInteira,'
        : '$parteInteira,$parteDecimal';
  }

  // ================= BOTÃO VOLTAR =================
  void _voltar() {
    FocusScope.of(context).unfocus();
    
    Navigator.of(context).pop(true);
  }

  // Método para confirmar emissão do certificado
  void _confirmarEmissaoCertificado() {
    if (produtoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um produto!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: const BorderSide(
              color: Color(0xFF0D47A1),
              width: 2.0,
            ),
          ),
          backgroundColor: Colors.white,
          title: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D47A1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Emitir Certificado',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Tem certeza que deseja emitir o certificado?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, 
                           color: Colors.amber, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Após a emissão, qualquer edição ou correção no documento só poderá ser realizada por um supervisor nível 3.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color.fromARGB(255, 239, 108, 0),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey[400]!),
                ),
              ),
              child: const Text(
                'Cancelar',
                style: TextStyle(fontSize: 16),
              ),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _processarEmissaoCertificado();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Confirmar Emissão',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        );
      },
    );
  }
  
  // Método para processar a emissão do certificado
  Future<void> _processarEmissaoCertificado() async {
    if (!mounted) return;

    setState(() {
      _salvandoCertificado = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      final usuario = UsuarioAtual.instance;
      if (usuario == null || usuario.filialId == null) {
        throw Exception('Usuário sem filial vinculada');
      }

      // ========== VERIFICAÇÃO CRÍTICA ==========
      // Se veio de uma movimentação, verifica se já existe certificado de ORIGEM
      if (widget.idMovimentacao != null && widget.idMovimentacao!.isNotEmpty) {
        final certificadoExistente = await supabase
            .from('ordens_analises')
            .select('id, numero_controle, tipo_analise')
            .eq('movimentacao_id', widget.idMovimentacao!)
            .eq('tipo_analise', 'origem') // ← Filtra apenas certificados de origem
            .maybeSingle();

        if (certificadoExistente != null && 
            certificadoExistente['id'] != null &&
            certificadoExistente['tipo_analise'] == 'origem') {
          // Já existe certificado de ORIGEM para esta movimentação!
          if (!mounted) return;
          
          setState(() {
            _salvandoCertificado = false;
            _modoVisualizacao = true; // Força modo visualização
          });
          
          // Carrega os dados do certificado de origem existente
          await _carregarDadosCertificado(certificadoExistente['id'].toString());
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ Já existe um certificado de ORIGEM para esta movimentação (Nº ${certificadoExistente['numero_controle'] ?? '--'})!'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          return; // Não prossegue com a criação
        }
      }
      // =========================================

      final produtoId = await _resolverProdutoId(produtoSelecionado!);

      // Validar que pelo menos o primeiro tanque tem dados da coleta
      if (_tanques.isEmpty || _tanques[0].tempAmostra == null) {
        throw Exception('Preencha os dados da coleta do tanque antes de emitir o certificado!');
      }

      // Usar dados do primeiro tanque para o certificado
      final tanquePrincipal = _tanques[0];

      // Dados do certificado - ADICIONA tipo_analise = 'origem'
      final dadosOrdem = {
        'data_analise': _formatarDataParaBanco(dataCtrl.text),
        'hora_analise': horaCtrl.text,
        'data_conclusao': DateTime.now().toIso8601String(),
        'movimentacao_id': widget.idMovimentacao,
        'tipo_analise': 'origem', // ← ADICIONADO: define como análise de origem
        'transportadora': campos['transportadora']!.text,
        'motorista': campos['motorista']!.text,
        'notas_fiscais': campos['notas']!.text,
        'placa_cavalo': campos['placaCavalo']!.text,
        'carreta1': campos['carreta1']!.text,
        'carreta2': campos['carreta2']!.text,
        'produto_id': produtoId,
        'produto_nome': produtoSelecionado,
        // Usar dados do dialog de coleta do tanque principal
        'temperatura_amostra': _converterParaDecimal(tanquePrincipal.tempAmostra),
        'densidade_observada': _converterParaDecimal(tanquePrincipal.densidadeObservada),
        'temperatura_ct': _converterParaDecimal(tanquePrincipal.tempCT),
        'densidade_20c': _converterParaDecimal(tanquePrincipal.densidade20C),
        'fator_correcao': _converterParaDecimal(tanquePrincipal.fatorCorrecao),
        'origem_ambiente': _converterParaInteiro(tanquePrincipal.volumeAmbCtrl.text),
        'destino_20c': _converterParaInteiro(tanquePrincipal.volume20CCtrl.text),
        'usuario_id': user.id,
        'filial_id': usuario.filialId,
      };

      // INSERIR o certificado
      final response = await supabase
          .from('ordens_analises')
          .insert(dadosOrdem)
          .select('id, numero_controle')
          .single();

      if (!mounted) return;

      campos['numeroControle']!.text =
          response['numero_controle'].toString();

      // ========== INSERIR DADOS DE COLETA POR TANQUE ==========
      // Montar array de placas (sem valores vazios)
      final placas = [
        campos['placaCavalo']!.text,
        campos['carreta1']!.text,
        campos['carreta2']!.text,
      ].where((p) => p.isNotEmpty).toList();

      // Criar lista de dados de coleta para todos os tanques
      final dadosColetas = <Map<String, dynamic>>[];
      
      for (int i = 0; i < _tanques.length; i++) {
        final tanque = _tanques[i];
        
        // Usar produto_id do tanque (veio da página de detalhes)
        // Se não tiver, tenta resolver pelo produto selecionado
        String produtoIdTanque;
        if (tanque.produtoId != null && tanque.produtoId!.isNotEmpty) {
          produtoIdTanque = tanque.produtoId!;
        } else {
          // Fallback: usar o produto selecionado globalmente
          produtoIdTanque = produtoId;
        }
        
        // Adicionar dados do tanque (somente se tiver dados da coleta)
        if (tanque.tempAmostra != null || tanque.densidadeObservada != null || tanque.tempCT != null) {
          dadosColetas.add({
            'movimentacao_id': widget.idMovimentacao,
            'produto_id': produtoIdTanque,
            'tanque_numero': i + 1,
            'placas': placas,
            'temperatura_amostra': _converterParaDecimal(tanque.tempAmostra),
            'densidade_observada': _converterParaDecimal(tanque.densidadeObservada),
            'temperatura_ct': _converterParaDecimal(tanque.tempCT),
            'volume_amb': _converterParaInteiro(tanque.volumeAmbCtrl.text),
            'volume_vinte': _converterParaInteiro(tanque.volume20CCtrl.text),
          });
        }
      }
      
      // Inserir todos os tanques em batch (operação crítica)
      if (dadosColetas.isNotEmpty) {
        try {
          await supabase
              .from('coletas_tanques')
              .insert(dadosColetas);
          
          print('✓ ${dadosColetas.length} coleta(s) de tanque inserida(s) com sucesso');
        } catch (e) {
          // Se falhar a inserção das coletas, toda a operação deve falhar
          print('✗ ERRO CRÍTICO ao inserir coletas_tanques: $e');
          throw Exception('Falha ao registrar dados de coleta dos tanques: $e');
        }
      }
      // ========================================================

      // Atualizar movimentação com volume 20°C do primeiro tanque
      if (widget.idMovimentacao != null && _tanques.isNotEmpty) {
        final volume20C =
            _converterParaInteiro(_tanques[0].volume20CCtrl.text) ?? 0;

        await _atualizarMovimentacaoSomente20C(
          movimentacaoId: widget.idMovimentacao!,
          volume20C: volume20C,
        );
      }

      if (!mounted) return;

      setState(() {
        _modoVisualizacao = true;
        _salvandoCertificado = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Certificado de ORIGEM emitido com sucesso!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }

    } catch (e) {
      print('Erro ao emitir certificado: $e');
      
      if (mounted) {
        setState(() {
          _salvandoCertificado = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao emitir certificado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Atualiza movimentação usando apenas as 4 colunas padrão: saida_amb, saida_vinte, entrada_amb, entrada_vinte
  Future<void> _atualizarMovimentacaoSomente20C({
    required String movimentacaoId,
    required int volume20C,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final timestampBrasilia = _obterTimestampBrasilia();
      
      await supabase
          .from('movimentacoes')
          .update({
            'saida_vinte': volume20C,
            'data_carga': timestampBrasilia,
            'status_circuito_orig': '4',
            'updated_at': timestampBrasilia,
          })
          .eq('id', movimentacaoId);
    } catch (e) {
      print('✗ Erro ao atualizar movimentação: $e');
      rethrow;
    }
  }
  
  // Função auxiliar para obter timestamp no horário de Brasília (UTC-3)
  String _obterTimestampBrasilia() {
    final agora = DateTime.now().toUtc();
    final brasilia = agora.subtract(const Duration(hours: 3));
    return brasilia.toIso8601String();
  }
  
  // ================= AUXILIAR =================
  Future<String> _resolverProdutoId(String nomeProduto) async {
    final r = await Supabase.instance.client
        .from('produtos')
        .select('id')
        .eq('nome', nomeProduto)
        .maybeSingle();

    if (r == null) {
      throw Exception('Produto não encontrado: $nomeProduto');
    }
    return r['id'].toString();
  }
  
  @override
  void dispose() {
    // _focusTempCT.dispose(); // Removido - FocusNode não é mais usado
    for (var tanque in _tanques) {
      tanque.dispose();
    }
    super.dispose();
  }

  String _formatarDataParaBanco(String data) {
    if (data.isEmpty) return '';
    
    try {
      final partes = data.split('/');
      if (partes.length == 3) {
        return '${partes[2]}-${partes[1]}-${partes[0]}';
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  double? _converterParaDecimal(String? texto) {
    if (texto == null || texto.isEmpty || texto == '-') return null;
    
    try {
      final textoLimpo = texto.replaceAll('.', '').replaceAll(',', '.');
      return double.tryParse(textoLimpo);
    } catch (e) {
      return null;
    }
  }

  int? _converterParaInteiro(String texto) {
    if (texto.isEmpty) return null;
    
    try {
      final textoLimpo = texto.replaceAll('.', '');
      return int.tryParse(textoLimpo);
    } catch (e) {
      return null;
    }
  }

  String _mascaraMilharUI(String texto) {
    final numeros = texto.replaceAll(RegExp(r'[^\d]'), '');
    if (numeros.isEmpty) return '';

    String resultado = '';
    for (int i = numeros.length - 1, c = 0; i >= 0; i--, c++) {
      if (c > 0 && c % 3 == 0) resultado = '.$resultado';
      resultado = numeros[i] + resultado;
    }
    return resultado;
  }
}