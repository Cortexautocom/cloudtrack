import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert' show base64Encode;
import 'dart:js' as js;
import 'certificado_pdf.dart';
import '../../login_page.dart';

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
  final bool modoSomenteVisualizacao;

  const EmitirCertificadoPage({
    super.key,
    required this.onVoltar,
    this.idCertificado,
    this.idMovimentacao,
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
  final FocusNode _focusTempCT = FocusNode();

  final Map<String, TextEditingController?> campos = {
    'numeroControle': TextEditingController(),
    'transportadora': TextEditingController(),
    'motorista': TextEditingController(),
    'notas': TextEditingController(),

    'placaCavalo': TextEditingController(),
    'carreta1': TextEditingController(),
    'carreta2': TextEditingController(),

    'tempAmostra': TextEditingController(),
    'densidadeAmostra': TextEditingController(),
    'tempCT': TextEditingController(),

    'densidade20': TextEditingController(),
    'fatorCorrecao': TextEditingController(),

    'volumeCarregadoAmb': TextEditingController(),
    'volumeApurado20C': TextEditingController(),
  };

  // ================= PRODUTOS =================
  List<String> produtos = [];
  String? produtoSelecionado;
  bool carregandoProdutos = true;

  @override
  void initState() {
    super.initState();
    _setarDataHoraAtual();
    _carregarProdutos();

    _focusTempCT.addListener(() {
      if (!_modoVisualizacao && !_focusTempCT.hasFocus) {
        _calcularResultadosObtidos();
      }
    });

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

        // Preenche volume ambiente diretamente de saida_amb
        if (movimentacao['saida_amb'] != null) {
          campos['volumeCarregadoAmb']!.text =
              _mascaraMilharUI(movimentacao['saida_amb'].toString());
        }

        // Preenche volume 20°C diretamente de saida_vinte
        if (movimentacao['saida_vinte'] != null) {
          campos['volumeApurado20C']!.text =
              _mascaraMilharUI(movimentacao['saida_vinte'].toString());
        }
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

      campos['tempAmostra']!.text =
          _formatarDecimalParaExibicao(_dadosExistentes!['temperatura_amostra']);
      campos['densidadeAmostra']!.text =
          _formatarDecimalParaExibicao(_dadosExistentes!['densidade_observada']);
      campos['tempCT']!.text =
          _formatarDecimalParaExibicao(_dadosExistentes!['temperatura_ct']);
      campos['densidade20']!.text =
          _formatarDecimalParaExibicao(_dadosExistentes!['densidade_20c']);
      campos['fatorCorrecao']!.text =
          _formatarDecimalParaExibicao(_dadosExistentes!['fator_correcao']);

      final origemAmb = _dadosExistentes!['origem_ambiente'];
      if (origemAmb != null) {
        campos['volumeCarregadoAmb']!.text =
            _mascaraMilharUI(origemAmb.toString());
      }

      final destino20 = _dadosExistentes!['destino_20c'];
      if (destino20 != null) {
        campos['volumeApurado20C']!.text =
            _mascaraMilharUI(destino20.toString());
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

    if (fcv != '-' &&
        fcv.isNotEmpty &&
        campos['volumeCarregadoAmb']!.text.isNotEmpty) {
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

    final volumeAmbText = campos['volumeCarregadoAmb']!.text;
    if (volumeAmbText.isEmpty) {
      campos['volumeApurado20C']!.text = '';
      return;
    }

    final volumeAmb =
        double.tryParse(volumeAmbText.replaceAll('.', ''));
    final fcv =
        double.tryParse(fcvText.replaceAll(',', '.'));

    if (volumeAmb == null || fcv == null) return;

    final volume20C = volumeAmb * fcv;
    campos['volumeApurado20C']!.text =
        _formatarNumeroParaCampo(volume20C);

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
                                  _secao('Coletas na presença do motorista'),
                                  _linha([
                                    TextFormField(
                                      controller: campos['tempAmostra'],
                                      keyboardType: TextInputType.number,
                                      enabled: !_modoVisualizacao,
                                      onChanged: _modoVisualizacao ? null : (value) {
                                        final masked = _aplicarMascaraTemperatura(value);

                                        if (masked != value) {
                                          campos['tempAmostra']!.value = TextEditingValue(
                                            text: masked,
                                            selection: TextSelection.collapsed(offset: masked.length),
                                          );
                                        }
                                      },
                                      decoration: _decoration('Temperatura da amostra (°C)').copyWith(
                                        hintText: '00,0',
                                        fillColor: _modoVisualizacao ? Colors.grey[200] : Colors.white,
                                      ),
                                    ),

                                    TextFormField(
                                      controller: campos['densidadeAmostra'],
                                      keyboardType: TextInputType.number,
                                      enabled: !_modoVisualizacao,
                                      onChanged: _modoVisualizacao ? null : (value) {
                                        final masked = _aplicarMascaraDensidade(value);

                                        if (masked != value) {
                                          campos['densidadeAmostra']!.value = TextEditingValue(
                                            text: masked,
                                            selection: TextSelection.collapsed(offset: masked.length),
                                          );
                                        }
                                      },
                                      decoration: _decoration('Densidade observada').copyWith(
                                        hintText: '0,0000',
                                        fillColor: _modoVisualizacao ? Colors.grey[200] : Colors.white,
                                      ),
                                    ),

                                    TextFormField(
                                      controller: campos['tempCT'],
                                      focusNode: _modoVisualizacao ? null : _focusTempCT,
                                      keyboardType: TextInputType.number,
                                      enabled: !_modoVisualizacao,
                                      onChanged: _modoVisualizacao ? null : (value) {
                                        final masked = _aplicarMascaraTemperatura(value);

                                        if (masked != value) {
                                          campos['tempCT']!.value = TextEditingValue(
                                            text: masked,
                                            selection: TextSelection.collapsed(offset: masked.length),
                                          );
                                        }
                                      },
                                      decoration: _decoration('Temperatura do CT (°C)').copyWith(
                                        hintText: '00,0',
                                        fillColor: _modoVisualizacao ? Colors.grey[200] : Colors.white,
                                      ),
                                    ),
                                  ]),
                                  const SizedBox(height: 20),
                                  _secao('Resultados obtidos'),
                                  _linha([
                                    _campo('Densidade a 20 ºC', campos['densidade20']!, 
                                           enabled: false), 
                                    
                                    _campo('Fator de correção (FCV)', campos['fatorCorrecao']!, 
                                           enabled: false), 
                                  ]),
                                  const SizedBox(height: 20),
                                  _secao('Volumes apurados'),
                                  _linha([
                                    TextFormField(
                                      controller: campos['volumeCarregadoAmb'],
                                      keyboardType: TextInputType.number,
                                      enabled: false,
                                      decoration: _decoration('Volume carregado (ambiente)').copyWith(
                                        fillColor: Colors.grey[100],
                                      ),
                                    ),

                                    TextFormField(
                                      controller: campos['volumeApurado20C'],
                                      keyboardType: TextInputType.number,
                                      enabled: false,
                                      decoration: _decoration('Volume apurado a 20 ºC').copyWith(
                                        fillColor: Colors.grey[100],
                                      ),
                                    ),
                                  ]),
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
      final dadosPDF = {
        'numeroControle': campos['numeroControle']!.text,
        'transportadora': campos['transportadora']!.text,
        'motorista': campos['motorista']!.text,
        'placaCavalo': campos['placaCavalo']!.text,
        'carreta1': campos['carreta1']!.text,
        'carreta2': campos['carreta2']!.text,
        'notas': campos['notas']!.text,
        'tempAmostra': campos['tempAmostra']!.text,
        'densidadeAmostra': campos['densidadeAmostra']!.text,
        'tempCT': campos['tempCT']!.text,
        'densidade20': campos['densidade20']!.text,
        'fatorCorrecao': campos['fatorCorrecao']!.text,
        'volumeCarregadoAmb': campos['volumeCarregadoAmb']!.text,
        'volumeApurado20C': campos['volumeApurado20C']!.text,
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
        'temperatura_amostra':
            _converterParaDecimal(campos['tempAmostra']!.text),
        'densidade_observada':
            _converterParaDecimal(campos['densidadeAmostra']!.text),
        'temperatura_ct':
            _converterParaDecimal(campos['tempCT']!.text),
        'densidade_20c':
            _converterParaDecimal(campos['densidade20']!.text),
        'fator_correcao':
            _converterParaDecimal(campos['fatorCorrecao']!.text),
        'origem_ambiente':
            _converterParaInteiro(campos['volumeCarregadoAmb']!.text),
        'destino_20c':
            _converterParaInteiro(campos['volumeApurado20C']!.text),
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

      // Atualizar movimentação com volume 20°C
      if (widget.idMovimentacao != null) {
        final volume20C =
            _converterParaInteiro(campos['volumeApurado20C']!.text) ?? 0;

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
            duration: Duration(seconds: 3),
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
      final agora = DateTime.now().toUtc().toIso8601String();
      
      await supabase
          .from('movimentacoes')
          .update({
            'saida_vinte': volume20C,
            'data_carga': agora,
            'status_circuito_orig': '4',
            'updated_at': agora,
          })
          .eq('id', movimentacaoId);
    } catch (e) {
      print('✗ Erro ao atualizar movimentação: $e');
      rethrow;
    }
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
    _focusTempCT.dispose();
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

  double? _converterParaDecimal(String texto) {
    if (texto.isEmpty || texto == '-') return null;
    
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