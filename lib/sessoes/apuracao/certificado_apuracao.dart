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

  const PlacaAutocompleteField({
    super.key,
    required this.controller,
    required this.label,
    this.focusNode,
    this.onChanged,
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
    
    // Se um focusNode externo foi fornecido, sincronize com o interno
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
      _mostrarOverlay();
    } else {
      // Pequeno delay para permitir clique nos itens
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_internalFocusNode.hasFocus) {
          _fecharOverlay();
        }
      });
    }
  }

  Future<void> _buscarPlacas(String texto) async {
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
    // Cancelar timer anterior
    _debounceTimer?.cancel();
    
    // Limpar sugestões imediatamente se texto muito curto
    if (texto.length < 3) {
      setState(() {
        _sugestoes.clear();
      });
      _fecharOverlay();
      return;
    }

    // Configurar novo timer de debounce
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _buscarPlacas(texto);
      }
    });

    // Chamar callback externo se fornecido
    if (widget.onChanged != null) {
      widget.onChanged!(texto);
    }
  }

  void _onPlacaSelecionada(String placa) {
    widget.controller.text = placa;
    setState(() {
      _sugestoes.clear();
    });
    _fecharOverlay();
    _internalFocusNode.unfocus();
    
    // Mover cursor para o final
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: placa.length),
    );
  }

  void _mostrarOverlay() {
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

// ================= PÁGINA PRINCIPAL (COM AS ALTERAÇÕES) =================
class EmitirCertificadoPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final String? idCertificado; // ALTERADO: Agora recebe idCertificado

  const EmitirCertificadoPage({
    super.key,
    required this.onVoltar,
    this.idCertificado, // ALTERADO: Parâmetro opcional
  });

  @override
  State<EmitirCertificadoPage> createState() =>
      _EmitirCertificadoPageState();
}

class _EmitirCertificadoPageState extends State<EmitirCertificadoPage> {
  final _formKey = GlobalKey<FormState>();
  bool _analiseConcluida = false;
  bool _modoEdicao = false; // NOVO: Indica se está editando um certificado existente
  Map<String, dynamic>? _dadosExistentes; // NOVO: Para armazenar dados do certificado existente
  
  // ================= CONTROLLERS =================
  final TextEditingController dataCtrl = TextEditingController();
  final TextEditingController horaCtrl = TextEditingController();

  final Map<String, TextEditingController?> campos = {
    // Cabeçalho
    'numeroControle': TextEditingController(),
    'transportadora': TextEditingController(),
    'motorista': TextEditingController(),
    'notas': TextEditingController(),

    'placaCavalo': TextEditingController(),
    'carreta1': TextEditingController(),
    'carreta2': TextEditingController(),

    // Coletas (usuário)
    'tempAmostra': TextEditingController(),
    'densidadeAmostra': TextEditingController(),
    'tempCT': TextEditingController(),

    // Resultados (automáticos)
    'densidade20': TextEditingController(),
    'fatorCorrecao': TextEditingController(),

    // Volumes apurados
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
    
    // NOVO: Verificar se recebeu um ID para edição
    if (widget.idCertificado != null && widget.idCertificado!.isNotEmpty) {
      _modoEdicao = true;
      _carregarDadosCertificado(widget.idCertificado!);
    }
  }

  // NOVO: Método para carregar dados do certificado existente
  Future<void> _carregarDadosCertificado(String idCertificado) async {
    try {
      final supabase = Supabase.instance.client;
      
      // Buscar o certificado no banco (tabela 'ordens_analises' - mantém nome original do banco)
      final dados = await supabase
          .from('ordens_analises')
          .select('*')
          .eq('id', idCertificado)
          .single();
      
      // Armazenar os dados
      _dadosExistentes = Map<String, dynamic>.from(dados);
      
      // Preencher os campos com os dados existentes
      _preencherCamposComDadosExistentes();
      
      // Verificar se já está concluído
      if (_dadosExistentes!['analise_concluida'] == true) {
        setState(() {
          _analiseConcluida = true;
        });
      }
      
    } catch (e) {
      print('Erro ao carregar certificado: $e');
      // Se não encontrar, continua em modo criação
      _modoEdicao = false;
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
  
  // NOVO: Método para preencher os campos com dados existentes
  void _preencherCamposComDadosExistentes() {
    if (_dadosExistentes == null) return;
    
    setState(() {
      // Preencher os campos principais
      campos['numeroControle']!.text = _dadosExistentes!['numero_controle']?.toString() ?? '';
      campos['transportadora']!.text = _dadosExistentes!['transportadora']?.toString() ?? '';
      campos['motorista']!.text = _dadosExistentes!['motorista']?.toString() ?? '';
      campos['notas']!.text = _dadosExistentes!['notas_fiscais']?.toString() ?? '';
      
      // Placas
      campos['placaCavalo']!.text = _dadosExistentes!['placa_cavalo']?.toString() ?? '';
      campos['carreta1']!.text = _dadosExistentes!['carreta1']?.toString() ?? '';
      campos['carreta2']!.text = _dadosExistentes!['carreta2']?.toString() ?? '';
      
      // Coletas
      campos['tempAmostra']!.text = _formatarDecimalParaExibicao(_dadosExistentes!['temperatura_amostra']);
      campos['densidadeAmostra']!.text = _formatarDecimalParaExibicao(_dadosExistentes!['densidade_observada']);
      campos['tempCT']!.text = _formatarDecimalParaExibicao(_dadosExistentes!['temperatura_ct']);
      
      // Resultados
      campos['densidade20']!.text = _formatarDecimalParaExibicao(_dadosExistentes!['densidade_20c']);
      campos['fatorCorrecao']!.text = _formatarDecimalParaExibicao(_dadosExistentes!['fator_correcao']);
      
      // Volumes
      campos['volumeCarregadoAmb']!.text = _dadosExistentes!['volume_carregado_amb']?.toString() ?? '';
      campos['volumeApurado20C']!.text = _dadosExistentes!['volume_apurado_20c']?.toString() ?? '';
      
      // Data e hora
      if (_dadosExistentes!['data_analise'] != null) {
        try {
          final data = DateTime.parse(_dadosExistentes!['data_analise']);
          dataCtrl.text = '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
        } catch (_) {
          // Mantém a data atual se não conseguir parse
        }
      }
      
      if (_dadosExistentes!['hora_analise'] != null) {
        horaCtrl.text = _dadosExistentes!['hora_analise'].toString();
      }
      
      // Produto
      produtoSelecionado = _dadosExistentes!['produto_nome']?.toString();
    });
  }
  
  // NOVO: Formatar decimal para exibição (converte 0.7456 para 0,7456)
  String _formatarDecimalParaExibicao(dynamic valor) {
    if (valor == null) return '';
    
    try {
      String texto = valor.toString();
      // Substitui ponto por vírgula se existir
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
        
        // NOVO: Se estiver em modo edição e já temos produto, seleciona automaticamente
        if (_modoEdicao && produtoSelecionado != null && produtos.contains(produtoSelecionado)) {
          // Já está selecionado pelo _preencherCamposComDadosExistentes
        }
      });
    } catch (_) {
      carregandoProdutos = false;
    }
  }

  // ================= CÁLCULOS =================
  Future<void> _calcularResultadosObtidos() async {
    if (produtoSelecionado == null) {
      return;
    }

    final tempAmostra = campos['tempAmostra']!.text;
    final densObs = campos['densidadeAmostra']!.text;
    final tempCT = campos['tempCT']!.text;
    final fcvAtual = campos['fatorCorrecao']!.text;

    // Limpar campos antes de buscar
    campos['densidade20']!.text = '';
    campos['fatorCorrecao']!.text = '';

    final dens20 = await _buscarDensidade20C(
      temperaturaAmostra: tempAmostra,
      densidadeObservada: densObs,
      produtoNome: produtoSelecionado!,
    );

    campos['densidade20']!.text = dens20;

    final fcv = dens20 != '-'
        ? await _buscarFCV(
            temperaturaTanque: tempCT,
            densidade20C: dens20,
            produtoNome: produtoSelecionado!,
          )
        : '-';

    if (fcv != '-' && fcv.isNotEmpty) {
      campos['fatorCorrecao']!.text = fcv;
    } else {
      if (fcvAtual.isEmpty || fcvAtual == '-') {
        campos['fatorCorrecao']!.text = '-';
      }
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
                onPressed: widget.onVoltar,
              ),
              Text(
                // ALTERADO: Mostra título diferente para edição
                _modoEdicao 
                  ? 'Editar Certificado de Apuração de Volumes'
                  : 'Certificado de Apuração de Volumes',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                ),
              ),
              if (_modoEdicao) // NOVO: Indicador de modo edição
                Container(
                  margin: const EdgeInsets.only(left: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'EDIÇÃO',
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
                          // ================= FORMULÁRIO =================
                          Opacity(
                            opacity: 1.0,
                            child: AbsorbPointer(
                              absorbing: _analiseConcluida && !_modoEdicao, // ALTERADO: Em modo edição, pode editar mesmo se concluído
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
                                        enabled: false, // Será preenchido automaticamente pelo backend
                                        decoration: _decoration('Nº Controle do Certificado').copyWith(
                                          hintText: 'A ser gerado automaticamente',
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
                                                  onChanged: (value) {
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
                                                  decoration: _decoration('Notas Fiscais').copyWith(
                                                    hintText: '',
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
                                              onChanged: (valor) {
                                                setState(() {
                                                  produtoSelecionado = valor;
                                                });
                                                _calcularResultadosObtidos();
                                              },
                                              decoration: _decoration('Produto'),
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
                                      'flex': 10, // Motorista - 50% (10/20)
                                      'widget': TextFormField(
                                        controller: campos['motorista'],
                                        maxLength: 50,
                                        decoration: _decoration('Motorista').copyWith(
                                          counterText: '',
                                        ),
                                      ),
                                    },
                                    {
                                      'flex': 10, // Transportadora - 50% (10/20)
                                      'widget': TextFormField(
                                        controller: campos['transportadora'],
                                        maxLength: 50,
                                        decoration: _decoration('Transportadora').copyWith(
                                          counterText: '',
                                        ),
                                      ),
                                    },
                                  ]),
                                  const SizedBox(height: 12),                                
                                  // LINHA COM OS 3 CAMPOS DE PLACA - COM AUTOCOMPLETE
                                  _linhaFlexivel([
                                    {
                                      'flex': 4, // Placa do cavalo
                                      'widget': PlacaAutocompleteField(
                                        controller: campos['placaCavalo']!,
                                        label: 'Placa do cavalo',
                                      ),
                                    },
                                    {
                                      'flex': 4, // Carreta 1
                                      'widget': PlacaAutocompleteField(
                                        controller: campos['carreta1']!,
                                        label: 'Carreta 1',
                                      ),
                                    },
                                    {
                                      'flex': 4, // Carreta 2
                                      'widget': PlacaAutocompleteField(
                                        controller: campos['carreta2']!,
                                        label: 'Carreta 2',
                                      ),
                                    },
                                  ]),
                                  const SizedBox(height: 20),
                                  _secao('Coletas na presença do motorista'),
                                  _linha([
                                    TextFormField(
                                      controller: campos['tempAmostra'],
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) {
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
                                      ),
                                    ),

                                    TextFormField(
                                      controller: campos['densidadeAmostra'],
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) {
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
                                      ),
                                    ),

                                    TextFormField(
                                      controller: campos['tempCT'],
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) {
                                        final masked = _aplicarMascaraTemperatura(value);

                                        if (masked != value) {
                                          campos['tempCT']!.value = TextEditingValue(
                                            text: masked,
                                            selection: TextSelection.collapsed(offset: masked.length),
                                          );
                                        }
                                        _calcularResultadosObtidos();
                                      },
                                      decoration: _decoration('Temperatura do CT (°C)').copyWith(
                                        hintText: '00,0',
                                      ),
                                    ),

                                  ]),
                                  const SizedBox(height: 20),
                                  _secao('Resultados obtidos'),
                                  _linha([
                                    _campo('Densidade a 20 ºC', campos['densidade20']!, enabled: false),
                                    _campo('Fator de correção (FCV)', campos['fatorCorrecao']!, enabled: false),
                                  ]),
                                  const SizedBox(height: 20),
                                  _secao('Volumes apurados'),
                                  _linha([
                                    TextFormField(
                                      controller: campos['volumeCarregadoAmb'],
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) {
                                        final ctrl = campos['volumeCarregadoAmb']!;
                                        final masked = _aplicarMascaraNotasFiscais(value);

                                        if (masked != value) {
                                          ctrl.value = TextEditingValue(
                                            text: masked,
                                            selection: TextSelection.collapsed(offset: masked.length),
                                          );
                                        }
                                      },
                                      decoration: _decoration('Volume carregado (ambiente)'),
                                    ),
                                    TextFormField(
                                      controller: campos['volumeApurado20C'],
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) {
                                        final ctrl = campos['volumeApurado20C']!;
                                        final masked = _aplicarMascaraNotasFiscais(value);

                                        if (masked != value) {
                                          ctrl.value = TextEditingValue(
                                            text: masked,
                                            selection: TextSelection.collapsed(offset: masked.length),
                                          );
                                        }
                                      },
                                      decoration: _decoration('Volume apurado a 20 ºC'),
                                    ),
                                  ]),
                                  const SizedBox(height: 40),
                                ],
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // ALTERADO: Botão com texto dinâmico para edição
                              ElevatedButton.icon(
                                onPressed: (!_analiseConcluida || _modoEdicao) ? _confirmarEmissaoCertificado : null,
                                icon: Icon(_analiseConcluida && !_modoEdicao ? Icons.check_circle_outline : Icons.check_circle, size: 24),
                                label: Text(
                                  _modoEdicao 
                                    ? (_analiseConcluida ? 'Atualizar certificado' : 'Salvar alterações')
                                    : (_analiseConcluida ? 'Certificado emitido' : 'Emitir certificado'),
                                  style: const TextStyle(fontSize: 16),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _analiseConcluida && !_modoEdicao ? Colors.grey[400] : Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              
                              // BOTÃO GERAR PDF (CENTRO)
                              ElevatedButton.icon(
                                onPressed: (_analiseConcluida) ? _baixarPDF : null,
                                icon: Icon(
                                  Icons.picture_as_pdf, 
                                  size: 24,
                                  color: _analiseConcluida ? Colors.white : Colors.grey[600],
                                ),
                                label: Text(
                                  'Gerar Certificado PDF',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _analiseConcluida ? Colors.white : Colors.grey[600],
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _analiseConcluida 
                                      ? const Color(0xFF0D47A1)
                                      : Colors.grey[300],
                                  foregroundColor: _analiseConcluida ? Colors.white : Colors.grey[600],
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: _analiseConcluida 
                                          ? const Color(0xFF0D47A1)
                                          : Colors.grey[400]!,
                                      width: 1,
                                    ),
                                  ),
                                  elevation: _analiseConcluida ? 2 : 0,
                                  shadowColor: _analiseConcluida ? const Color(0xFF0D47A1).withOpacity(0.3) : Colors.transparent,
                                ),
                              ),
                              
                              // BOTÃO CONCLUIR (DIREITA)
                              ElevatedButton.icon(
                                onPressed: _concluir,
                                icon: const Icon(Icons.done_all, size: 24),
                                label: Text(
                                  _modoEdicao ? 'Voltar' : 'Concluir', // ALTERADO: Texto dinâmico
                                  style: const TextStyle(fontSize: 16),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _modoEdicao ? Colors.blue : Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
        decoration: _decoration(label, disabled: !enabled),
      ),
    );
  }

  InputDecoration _decoration(String label,
          {bool disabled = false}) =>
      InputDecoration(
        labelText: label,
        filled: true,
        fillColor:
            disabled ? Colors.grey.shade200 : Colors.white,
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

  // ================= CÁLCULOS - CÓPIA FIÉL DO CACL =================
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
        if (context.mounted && diferenca > 0.0001) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Usando fator de correção aproximado'),
                backgroundColor: Colors.orange,
              ),
            );
          });
        }
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Usando fator de correção aproximado'),
                    backgroundColor: Colors.orange,
                  ),
                );
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

    if (!_analiseConcluida) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conclua a análise primeiro para gerar o PDF!'),
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

    // ALTERADO: Diálogo com mensagem dinâmica para edição
    final String titulo = _modoEdicao ? 'Atualizar Certificado' : 'Emitir Certificado';
    final String mensagem = _modoEdicao 
      ? 'Tem certeza que deseja atualizar este certificado?'
      : 'Tem certeza que deseja emitir o certificado?';
    final String mensagemAviso = _modoEdicao
      ? 'Esta atualização substituirá os dados anteriores do certificado.'
      : 'Após a emissão, qualquer edição ou correção no documento só poderá ser realizada por um supervisor nível 3.';
    final String textoBotao = _modoEdicao ? 'Confirmar Atualização' : 'Confirmar Emissão';

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
                Icon(_modoEdicao ? Icons.edit : Icons.warning_amber, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Text(
                  titulo,
                  style: const TextStyle(
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
                Text(
                  mensagem,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _modoEdicao ? Colors.blue[50] : Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _modoEdicao ? Colors.blue[200]! : Colors.amber[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(_modoEdicao ? Icons.info : Icons.info_outline, 
                           color: _modoEdicao ? Colors.blue : Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          mensagemAviso,
                          style: TextStyle(
                            fontSize: 14,
                            color: _modoEdicao ? Colors.blue[800] : const Color.fromARGB(255, 239, 108, 0),
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
                backgroundColor: _modoEdicao ? Colors.blue : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                textoBotao,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        );
      },
    );
  }
  
  // Método para processar a emissão/atualização do certificado
  Future<void> _processarEmissaoCertificado() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            _modoEdicao ? Colors.blue : const Color(0xFF0D47A1)
          ),
        ),
      ),
    );

    try {
      final supabase = Supabase.instance.client;
      
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      final usuario = UsuarioAtual.instance;
      if (usuario == null || usuario.filialId == null) {
        throw Exception('Usuário sem filial vinculada.');
      }
      
      final Map<String, dynamic> dadosParaBanco = {
        'data_analise': _formatarDataParaBanco(dataCtrl.text),
        'hora_analise': horaCtrl.text,
        'produto_nome': produtoSelecionado!,
        'transportadora': campos['transportadora']!.text,
        'motorista': campos['motorista']!.text,
        'notas_fiscais': campos['notas']!.text,
        'placa_cavalo': campos['placaCavalo']!.text,
        'carreta1': campos['carreta1']!.text,
        'carreta2': campos['carreta2']!.text,
        'temperatura_amostra': _converterParaDecimal(campos['tempAmostra']!.text),
        'densidade_observada': _converterParaDecimal(campos['densidadeAmostra']!.text),
        'temperatura_ct': _converterParaDecimal(campos['tempCT']!.text),
        'densidade_20c': _converterParaDecimal(campos['densidade20']!.text),
        'fator_correcao': _converterParaDecimal(campos['fatorCorrecao']!.text),
        'volume_carregado_amb': _converterParaInteiro(campos['volumeCarregadoAmb']!.text),
        'volume_apurado_20c': _converterParaInteiro(campos['volumeApurado20C']!.text),
        'analise_concluida': true,
        'data_conclusao': DateTime.now().toIso8601String(),
        'usuario_id': user.id,
        'filial_id': usuario.filialId,
        'status': 'concluida',
      };
      
      final produtoResult = await supabase
          .from('produtos')
          .select('id')
          .eq('nome', produtoSelecionado!)
          .maybeSingle();
      
      if (produtoResult != null) {
        dadosParaBanco['produto_id'] = produtoResult['id'];
      }
      
      Map<String, dynamic> response;
      
      // ALTERADO: Verifica se está em modo edição
      if (_modoEdicao && widget.idCertificado != null) {
        // MODO EDIÇÃO: Atualizar certificado existente
        response = await supabase
            .from('ordens_analises')
            .update(dadosParaBanco)
            .eq('id', widget.idCertificado!)
            .select('id, numero_controle')
            .single();
      } else {
        // MODO CRIAÇÃO: Inserir novo certificado
        response = await supabase
            .from('ordens_analises')
            .insert(dadosParaBanco)
            .select('id, numero_controle')
            .single();
      }
      
      campos['numeroControle']!.text = response['numero_controle'].toString();
      
      // ALTERADO: Só salva movimentação se for criação (não edição)
      if (!_modoEdicao) {
        dadosParaBanco['id'] = response['id'];
        await _salvarMovimentacao(dadosParaBanco);
      }
      
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      setState(() {
        _analiseConcluida = true;
      });
      
      if (context.mounted) {
        final String mensagemSucesso = _modoEdicao
          ? '✓ Certificado ${response['numero_controle']} atualizado com sucesso!'
          : '✓ Certificado ${response['numero_controle']} emitido com sucesso! O PDF agora está disponível.';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(mensagemSucesso),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      if (context.mounted) {
        final String mensagemErro = _modoEdicao
          ? 'Erro ao atualizar certificado: ${e.toString()}'
          : 'Erro ao emitir certificado: ${e.toString()}';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(mensagemErro),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      
      print('Erro no processamento do certificado: $e');
    }
  }

  // Método para salvar na tabela de movimentações (apenas para novos certificados)
  Future<void> _salvarMovimentacao(Map<String, dynamic> dadosCertificado) async {
    try {
      final supabase = Supabase.instance.client;
      
      final user = supabase.auth.currentUser;
      if (user == null) return;
      
      String? filialId;
      String? empresaId;
      
      final usuarioData = await supabase
          .from('usuarios')
          .select('id_filial, empresa_id')
          .eq('id', user.id)
          .maybeSingle();
      
      if (usuarioData != null) {
        filialId = usuarioData['id_filial']?.toString();
        empresaId = usuarioData['empresa_id']?.toString();
      }
      
      if (filialId == null) {
        final primeiraFilial = await supabase
            .from('filiais')
            .select('id')
            .limit(1)
            .maybeSingle();
        filialId = primeiraFilial?['id']?.toString();
      }
      
      if (empresaId == null) {
        final primeiraEmpresa = await supabase
            .from('empresas')
            .select('id')
            .limit(1)
            .maybeSingle();
        empresaId = primeiraEmpresa?['id']?.toString();
      }
      
      if (filialId == null || empresaId == null) {
        return;
      }
      
      final List<String> placasArray = [];
      
      void adicionarPlacaSePreenchida(String placa) {
        final placaLimpa = placa.trim();
        if (placaLimpa.isNotEmpty && placaLimpa != '-') {
          placasArray.add(placaLimpa);
        }
      }
      
      adicionarPlacaSePreenchida(campos['placaCavalo']!.text);
      adicionarPlacaSePreenchida(campos['carreta1']!.text);
      adicionarPlacaSePreenchida(campos['carreta2']!.text);
      
      final volumeCarregadoAmb = _converterParaInteiro(campos['volumeCarregadoAmb']!.text) ?? 0;
      final volumeApurado20C = _converterParaInteiro(campos['volumeApurado20C']!.text) ?? 0;
      
      final Map<String, dynamic> camposProduto = _mapearCamposProduto();
      
      final Map<String, dynamic> dadosMovimentacao = {
        'filial_id': filialId,
        'empresa_id': empresaId,
        'data_mov': dadosCertificado['data_analise'],
        'descricao': null,
        'cliente': null,
        'anp': false,
        'entrada_amb': null,
        'entrada_vinte': null,
        'saida_amb': volumeCarregadoAmb,
        'saida_vinte': volumeApurado20C,
        'produto_id': dadosCertificado['produto_id'],
        'placa': placasArray.isNotEmpty ? '{${placasArray.join(',')}}' : null,
        'codigo': null,
        'cacl_id': null,
        'uf': null,
        'forma_pagamento': null,
        'observacoes': null,
        'quantidade': null,
        'usuario_id': dadosCertificado['usuario_id'],
        'created_at': DateTime.now().toIso8601String(),
        'status_circuito': '3',
        ...camposProduto,
      };
      
      await supabase
          .from('movimentacoes')
          .insert(dadosMovimentacao);
      
    } catch (e) {
      // Não lançar exceção
      print('Erro ao salvar movimentação: $e');
    }
  }

  Map<String, dynamic> _mapearCamposProduto() {
    final produto = produtoSelecionado?.toLowerCase() ?? '';
    final quantidade = _converterParaInteiro(campos['volumeCarregadoAmb']!.text) ?? 0;
    
    final camposProduto = {
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
    
    if (produto.contains('gasolina')) {
      if (produto.contains('comum')) {
        camposProduto['g_comum'] = quantidade;
      } else if (produto.contains('aditivada')) {
        camposProduto['g_aditivada'] = quantidade;
      } else {
        camposProduto['gasolina_a'] = quantidade;
      }
    } else if (produto.contains('diesel')) {
      if (produto.contains('s10')) {
        camposProduto['d_s10'] = quantidade;
      } else if (produto.contains('s500')) {
        camposProduto['d_s500'] = quantidade;
      }
    } else if (produto.contains('etanol')) {
      if (produto.contains('anidro')) {
        camposProduto['anidro'] = quantidade;
      } else if (produto.contains('hidratado')) {
        camposProduto['etanol'] = quantidade;
      }
    } else if (produto.contains('b100')) {
      camposProduto['b100'] = quantidade;
    }
    
    return camposProduto;
  }  

  // Método para concluir/voltar
  void _concluir() {
    if (_analiseConcluida && !_modoEdicao) {
      widget.onVoltar();
      return;
    }
    
    // ALTERADO: Mensagem dinâmica para edição
    final String titulo = _modoEdicao ? 'Descartar Alterações' : 'Concluir';
    final String mensagem = _modoEdicao
      ? 'Deseja realmente voltar sem salvar as alterações?'
      : 'Deseja realmente concluir e voltar para a página de acompanhamento?';
    final String descricao = _modoEdicao
      ? 'Todas as alterações feitas serão perdidas.'
      : 'Todos os dados preenchidos que não foram salvos serão perdidos.';

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
                Icon(_modoEdicao ? Icons.warning : Icons.warning_amber, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Text(
                  titulo,
                  style: const TextStyle(
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
                Text(
                  mensagem,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  descricao,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
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
                widget.onVoltar();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                _modoEdicao ? 'Descartar' : 'Concluir',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        );
      },
    );
  }

  // Função para formatar data DD/MM/YYYY para YYYY-MM-DD
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

  // Função para converter campo de texto para decimal (NUMERIC)
  double? _converterParaDecimal(String texto) {
    if (texto.isEmpty || texto == '-') return null;
    
    try {
      final textoLimpo = texto.replaceAll('.', '').replaceAll(',', '.');
      return double.tryParse(textoLimpo);
    } catch (e) {
      return null;
    }
  }

  // Função para converter campo de texto para inteiro
  int? _converterParaInteiro(String texto) {
    if (texto.isEmpty) return null;
    
    try {
      final textoLimpo = texto.replaceAll('.', '');
      return int.tryParse(textoLimpo);
    } catch (e) {
      return null;
    }
  }
}