import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';

// Intent para mapear TAB no campo 'Nota fiscal' para focar o campo de data
class _FocusDataIntent extends Intent {
  const _FocusDataIntent();
}

// Intents adicionais para outras transições de foco
class _FocusQtd20Intent extends Intent {
  const _FocusQtd20Intent();
}

class _FocusPrecoIntent extends Intent {
  const _FocusPrecoIntent();
}

class CriarOrdemPage extends StatefulWidget {
  final VoidCallback? onCreated;
  final VoidCallback? onVoltar;
  const CriarOrdemPage({super.key, this.onCreated, this.onVoltar});

  @override
  State<CriarOrdemPage> createState() => _CriarOrdemPageState();
}

class _CriarOrdemPageState extends State<CriarOrdemPage> {
  final _formKey = GlobalKey<FormState>();

  final _origemCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  final _dataCtrl = TextEditingController();
  final _qtdAmbCtrl = TextEditingController();
  final _qtd20Ctrl = TextEditingController();
  final _valorUnitCtrl = TextEditingController();
  final _valorNfCtrl = TextEditingController();

  final FocusNode _valorNfFocus = FocusNode();
  final FocusNode _origemFocus = FocusNode();
  final FocusNode _notaFocus = FocusNode();
  final FocusNode _dataFocus = FocusNode();
  final FocusNode _qtdAmbFocus = FocusNode();
  final FocusNode _qtd20Focus = FocusNode();
  final FocusNode _produtoFocus = FocusNode();
  final FocusNode _terminalFocus = FocusNode();
  final FocusNode _valorUnitFocus = FocusNode();

  String? _produtoSelecionado;
  List<Map<String, dynamic>> _produtos = [];
  String? _terminalSelecionado;
  List<Map<String, dynamic>> _terminais = [];

  final supabase = Supabase.instance.client;
  bool _dateAlertShown = false;
  

  @override
  void initState() {
    super.initState();
    _carregarProdutos();
    _carregarTerminais();
    final usuarioInit = UsuarioAtual.instance;
    if (usuarioInit != null && usuarioInit.nivel != 3) {
      _terminalSelecionado = usuarioInit.terminalId;
    }
    _qtd20Ctrl.addListener(_atualizarValorNf);
    _valorUnitCtrl.addListener(_atualizarValorNf);
  }

  Future<void> _carregarTerminais() async {
    final res = await supabase.from('terminais').select('id, nome').order('nome');
    setState(() {
      _terminais = List<Map<String, dynamic>>.from(res);
    });
  }

  void _atualizarValorNf() {
    if (_valorNfFocus.hasFocus) return; // não sobrescreve enquanto o usuário edita

    final qtdText = _qtd20Ctrl.text.trim();
    final precoText = _valorUnitCtrl.text.trim();

    if (qtdText.isEmpty || precoText.isEmpty) return;

    try {
      // Quantidade: remove pontos de milhar (ex: 45.285 -> 45285)
      final qtd = int.parse(qtdText.replaceAll(RegExp(r'[^0-9]'), ''));

      // Preço: aceita vírgula OU ponto como separador decimal (ex: 3,4585 ou 3.4585)
      final precoNormalizado = precoText
          .replaceAll('.', '')     // remove separadores de milhar "fantasmas"
          .replaceAll(',', '.');   // normaliza decimal para double

      final preco = double.tryParse(precoNormalizado);
      if (preco == null) return;

      final total = qtd * preco;

      final formatted = NumberFormat.currency(
        locale: 'pt_BR',
        symbol: 'R\$',
      ).format(total);

      _valorNfCtrl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    } catch (_) {
      // ignora erros silenciosamente
    }
  }

  @override
  void dispose() {
    _origemCtrl.dispose();
    _notaCtrl.dispose();
    _dataCtrl.dispose();
    _qtdAmbCtrl.dispose();
    _qtd20Ctrl.dispose();
    _valorUnitCtrl.dispose();
    _valorNfCtrl.dispose();
    _valorNfFocus.dispose();
    _origemFocus.dispose();
    _notaFocus.dispose();
    _dataFocus.dispose();
    _qtdAmbFocus.dispose();
    _qtd20Focus.dispose();
    _produtoFocus.dispose();
    _terminalFocus.dispose();
    _valorUnitFocus.dispose();
    super.dispose();
  }

  Future<void> _carregarProdutos() async {
    final res = await supabase.from('produtos').select('id, nome').order('nome');
    setState(() {
      _produtos = List<Map<String, dynamic>>.from(res);
    });
  }

  String _formatMilhar(String value) {
    final numeric = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (numeric.isEmpty) return '';
    final number = int.parse(numeric);
    return NumberFormat.decimalPattern('pt_BR').format(number);
  }

  String _formatMoeda(String value) {
    final numeric = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (numeric.isEmpty) return '';
    final number = double.parse(numeric) / 100;
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(number);
  }

  String _formatData(String value) {
    final v = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (v.isEmpty) return '';
    if (v.length <= 2) return v;
    if (v.length <= 4) return '${v.substring(0, 2)}/${v.substring(2)}';

    final day = v.substring(0, 2);
    final month = v.substring(2, 4);
    final year = v.length >= 8 ? v.substring(4, 8) : v.substring(4);
    return '$day/$month/$year';
  }

  void _validarData(String dataText) {
    try {
      final data = DateFormat('dd/MM/yyyy').parse(dataText);
      final hoje = DateTime.now();
      final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);

      final diff = data.difference(hojeSemHora).inDays;
      if (diff > 30 || diff < -30) {
        // agende para o próximo frame para evitar chamar showDialog enquanto
        // o TextField está processando mudanças de foco/estado
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_dateAlertShown) {
            _showDateAlert();
          }
        });
      }
    } catch (_) {
      // ignora parse inválido
    }
  }

  Future<void> _showDateAlert() async {
    _dateAlertShown = true;
    try {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          return Shortcuts(
            shortcuts: <LogicalKeySet, Intent>{
              LogicalKeySet(LogicalKeyboardKey.escape): const ActivateIntent(),
            },
            child: Actions(
              actions: <Type, Action<Intent>>{
                ActivateIntent: CallbackAction<Intent>(
                  onInvoke: (Intent intent) {
                    Navigator.of(ctx).pop();
                    return null;
                  },
                ),
              },
              child: AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFF0D47A1), width: 1),
                ),
                content: const Text(
                  'Atenção na data digitada',
                  style: TextStyle(color: Colors.black87),
                ),
                actions: [
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0D47A1),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: const Size(64, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: const BorderSide(color: Color(0xFF0D47A1), width: 1),
                      ),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      _dateAlertShown = false;
    }
  }

  Future<void> _criarOrdem() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final dataEmissao = DateFormat('dd/MM/yyyy').parse(_dataCtrl.text);
      final usuario = UsuarioAtual.instance;

      final ordem = await supabase.from('ordens').insert({
        'empresa_id': usuario!.empresaId,
        'usuario_id': usuario.id,
        'terminal_id': _terminalSelecionado,
        'data_ordem': dataEmissao.toUtc().toIso8601String(),
      }).select().single();

      await supabase.from('notas_fiscais').insert({
        'ordem_id': ordem['id'],
        'origem': _origemCtrl.text.isEmpty ? null : _origemCtrl.text,
        'nota_fiscal': _notaCtrl.text.replaceAll('.', ''),
        'data_emissao': dataEmissao.toIso8601String(),
        'quantidade_amb': _qtdAmbCtrl.text.replaceAll('.', ''),
        'quantidade_20': _qtd20Ctrl.text.replaceAll('.', ''),
        'produto_id': _produtoSelecionado,
        'valor_unit': _valorUnitCtrl.text.trim().isEmpty ? null : _valorUnitCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
        'valor_nf': _valorNfCtrl.text.trim().isEmpty ? null : _valorNfCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ordem criada com sucesso')),
      );

      // Chama o callback do pai (se fornecido) para que ele mostre os cards
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          widget.onCreated?.call();
        } catch (_) {}
      });
    } catch (e, st) {
      // Log para diagnóstico sem interromper a app
      // ignore: avoid_print
      print('Erro ao criar ordem: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar ordem: $e')),
        );
      }
    }
  }

  InputDecoration _decoracaoSlim(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 14, color: Colors.grey.shade700),
      isDense: true,
      counterText: '', // remove contador de caracteres
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade700),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = UsuarioAtual.instance;
    return WillPopScope(
      onWillPop: () async {
        if (widget.onVoltar != null) {
          widget.onVoltar!();
          return false; // handled by parent, don't pop the route
        }
        return true; // fallback: allow normal pop
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Row(
                  children: const [
                    Icon(Icons.add_circle_outline, color: Color(0xFF0D47A1)),
                    SizedBox(width: 8),
                    Text(
                      'Criar nova ordem',
                      style: TextStyle(
                        fontSize: 20,
                        color: Color(0xFF0D47A1),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  child: Form(
                    key: _formKey,
                    child: Wrap(
                      spacing: 20,
                      runSpacing: 14,
                      children: [
                        if (usuario?.nivel == 3)
                          SizedBox(
                            width: 540,
                            child: DropdownButtonFormField<String>(
                              focusNode: _terminalFocus,
                              value: _terminalSelecionado,
                              decoration: _decoracaoSlim('Terminal'),
                              style: const TextStyle(fontSize: 14, color: Colors.black87),
                              items: _terminais
                                  .map<DropdownMenuItem<String>>(
                                    (t) => DropdownMenuItem<String>(
                                      value: t['id']?.toString(),
                                      child: Text(
                                        t['nome'] ?? '',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() => _terminalSelecionado = v),
                              validator: (v) => v == null ? 'Obrigatório' : null,
                            ),
                          ),

                        _campo('Origem', _origemCtrl, maiusculo: true, max: 50, letrasOnly: true, focusNode: _origemFocus, nextFocus: _notaFocus),
                        Shortcuts(
                          shortcuts: <LogicalKeySet, Intent>{
                            LogicalKeySet(LogicalKeyboardKey.tab): const _FocusDataIntent(),
                          },
                          child: Actions(
                            actions: <Type, Action<Intent>>{
                              _FocusDataIntent: CallbackAction<_FocusDataIntent>(
                                onInvoke: (Intent intent) {
                                  _dataFocus.requestFocus();
                                  return null;
                                },
                              ),
                            },
                            child: _campo('Nota fiscal', _notaCtrl, milhar: true, max: 8, focusNode: _notaFocus, nextFocus: _dataFocus),
                          ),
                        ),
                        _campo('Data de emissão', _dataCtrl, data: true, focusNode: _dataFocus, nextFocus: _qtdAmbFocus),
                        Shortcuts(
                          shortcuts: <LogicalKeySet, Intent>{
                            LogicalKeySet(LogicalKeyboardKey.tab): const _FocusQtd20Intent(),
                          },
                          child: Actions(
                            actions: <Type, Action<Intent>>{
                              _FocusQtd20Intent: CallbackAction<_FocusQtd20Intent>(
                                onInvoke: (Intent intent) {
                                  _qtd20Focus.requestFocus();
                                  return null;
                                },
                              ),
                            },
                            child: _campo('Quantidade (ambiente)', _qtdAmbCtrl, milhar: true, max: 5, focusNode: _qtdAmbFocus, nextFocus: _qtd20Focus),
                          ),
                        ),
                        _campo('Quantidade (20ºC)', _qtd20Ctrl, milhar: true, max: 5, focusNode: _qtd20Focus, nextFocus: _produtoFocus),

                        Shortcuts(
                          shortcuts: <LogicalKeySet, Intent>{
                            LogicalKeySet(LogicalKeyboardKey.tab): const _FocusPrecoIntent(),
                          },
                          child: Actions(
                            actions: <Type, Action<Intent>>{
                              _FocusPrecoIntent: CallbackAction<_FocusPrecoIntent>(
                                onInvoke: (Intent intent) {
                                  _valorUnitFocus.requestFocus();
                                  return null;
                                },
                              ),
                            },
                            child: SizedBox(
                              width: 260,
                              child: DropdownButtonFormField<String>(
                                focusNode: _produtoFocus,
                                decoration: _decoracaoSlim('Produto'),
                                style: const TextStyle(fontSize: 14, color: Colors.black87),
                                items: _produtos
                                    .map<DropdownMenuItem<String>>(
                                      (p) => DropdownMenuItem<String>(
                                        value: p['id']?.toString(),
                                        child: Text(
                                          p['nome'] ?? '',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) => _produtoSelecionado = v,
                                validator: (v) => v == null ? 'Obrigatório' : null,
                              ),
                            ),
                          ),
                        ),

                        _campo('Preço', _valorUnitCtrl, allowDecimalSeparators: true, max: 6, focusNode: _valorUnitFocus, nextFocus: _valorNfFocus),
                        _campo('Valor NF', _valorNfCtrl, moeda: true, max: 10, focusNode: _valorNfFocus),
                      ],
                    ),
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 36,
                      child: OutlinedButton(
                        onPressed: () {
                          if (widget.onVoltar != null) {
                            widget.onVoltar!();
                          } else {
                            Navigator.pop(context);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: _criarOrdem,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          textStyle: const TextStyle(fontSize: 13),
                          backgroundColor: const Color(0xFF0D47A1),
                        ),
                        child: const Text('Criar'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  Widget _campo(
    String label,
    TextEditingController controller, {
    bool milhar = false,
    bool moeda = false,
    bool data = false,
    bool maiusculo = false,
    bool letrasOnly = false,
    bool allowDecimalSeparators = false,
    FocusNode? focusNode,
    FocusNode? nextFocus,
    int? max,
  }) {
    return SizedBox(
      width: 260,
      child: TextFormField(
        focusNode: focusNode,
        controller: controller,
        maxLength: max,
        style: const TextStyle(fontSize: 14),
        inputFormatters: letrasOnly
            ? [
                FilteringTextInputFormatter.allow(RegExp(r"[A-Za-zÀ-ÿ ]")),
              ]
            : allowDecimalSeparators
                ? [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')),
                  ]
                : [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                  ],
        decoration: _decoracaoSlim(label),
        textInputAction: nextFocus != null ? TextInputAction.next : TextInputAction.done,
        onFieldSubmitted: (_) {
          if (nextFocus != null) FocusScope.of(context).requestFocus(nextFocus);
        },
        onChanged: (v) {
          String novo = v;

          if (maiusculo) novo = v.toUpperCase();
          if (milhar) novo = _formatMilhar(v);
          if (moeda) novo = _formatMoeda(v);
          if (data) novo = _formatData(v);

          controller.value = TextEditingValue(
            text: novo,
            selection: TextSelection.collapsed(offset: novo.length),
          );
          if (data && novo.length == 10) {
            _validarData(novo);
          }
        },
        validator: (v) {
          if (label != 'Origem' && label != 'Preço' && label != 'Valor NF' && (v == null || v.isEmpty)) {
            return 'Obrigatório';
          }
          return null;
        },
      ),
    );
  }
}