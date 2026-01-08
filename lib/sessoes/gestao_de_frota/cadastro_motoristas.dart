import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CadastroMotoristaDialog extends StatefulWidget {
  final VoidCallback onCadastroConcluido;

  const CadastroMotoristaDialog({
    super.key,
    required this.onCadastroConcluido,
  });

  @override
  State<CadastroMotoristaDialog> createState() => _CadastroMotoristaDialogState();
}

class _CadastroMotoristaDialogState extends State<CadastroMotoristaDialog> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nomeController = TextEditingController();
  final _nome2Controller = TextEditingController();
  final _cpfController = TextEditingController();
  final _cnhController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _telefone2Controller = TextEditingController();
  
  // Máscaras
  final cpfMask = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
  );
  
  final telefoneMask = MaskTextInputFormatter(
    mask: '(##) # ####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );
  
  // Estados
  bool _salvando = false;
  bool _validandoCpf = false;
  String? _categoriaSelecionada;
  String _situacaoSelecionada = 'Ativo'; // Valor default
  String? _transportadoraSelecionada;
  List<Map<String, dynamic>> _transportadoras = [];
  bool _carregandoTransportadoras = true;
  String? _cpfError;

  // Opções para categoria CNH
  final List<String> _categoriasCNH = [
    'A', 'B', 'C', 'D', 'E', 'AB', 'AC', 'AD', 'AE'
  ];

  // Opções para situação
  final List<String> _situacoes = [
    'Ativo',
    'Inativo',
    'Férias',
    'Afastado',
    'Desligado'
  ];

  @override
  void initState() {
    super.initState();
    _carregarTransportadoras();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _nome2Controller.dispose();
    _cpfController.dispose();
    _cnhController.dispose();
    _telefoneController.dispose();
    _telefone2Controller.dispose();
    super.dispose();
  }

  Future<void> _carregarTransportadoras() async {
    try {
      final dados = await _supabase
          .from('transportadoras')
          .select('id, nome')
          .order('nome', ascending: true);

      setState(() {
        _transportadoras = List<Map<String, dynamic>>.from(dados);
        _carregandoTransportadoras = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar transportadoras: $e');
      setState(() => _carregandoTransportadoras = false);
    }
  }

  Future<bool> _verificarCpfExistente(String cpf) async {
    try {
      final cpfLimpo = cpf.replaceAll(RegExp(r'[^0-9]'), '');
      
      if (cpfLimpo.length != 11) {
        return false;
      }

      final resultado = await _supabase
          .from('motoristas')
          .select('id')
          .eq('cpf', cpfLimpo)
          .maybeSingle();

      return resultado != null;
    } catch (e) {
      debugPrint('Erro ao verificar CPF: $e');
      return false;
    }
  }

  Future<void> _validarCpf() async {
    final cpf = _cpfController.text;
    
    if (cpf.isEmpty) {
      setState(() {
        _cpfError = null;
        _validandoCpf = false;
      });
      return;
    }
    
    final cpfLimpo = cpf.replaceAll(RegExp(r'[^0-9]'), '');
    if (cpfLimpo.length != 11) {
      setState(() {
        _cpfError = 'CPF inválido';
        _validandoCpf = false;
      });
      return;
    }
    
    setState(() => _validandoCpf = true);
    
    final cpfExistente = await _verificarCpfExistente(cpf);
    
    setState(() {
      _validandoCpf = false;
      _cpfError = cpfExistente ? 'CPF já cadastrado' : null;
    });
  }

  Future<void> _salvarMotorista() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // Validar CPF novamente antes de salvar
    if (_cpfError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_cpfError!),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _salvando = true);

    try {
      final cpfLimpo = _cpfController.text.replaceAll(RegExp(r'[^0-9]'), '');
      
      // Verificar se CPF já existe (verificação final)
      final cpfExistente = await _verificarCpfExistente(_cpfController.text);
      if (cpfExistente) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('CPF já cadastrado no sistema!'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _salvando = false);
        return;
      }

      // Encontrar o ID da transportadora selecionada
      String? transportadoraId;
      if (_transportadoraSelecionada != null) {
        final transportadora = _transportadoras.firstWhere(
          (t) => t['nome'] == _transportadoraSelecionada,
          orElse: () => {},
        );
        transportadoraId = transportadora['id']?.toString();
      }

      final dados = {
        'nome': _nomeController.text.trim(),
        'nome_2': _nome2Controller.text.trim(),
        'cpf': cpfLimpo,
        'cnh': int.tryParse(_cnhController.text) ?? 0,
        'categoria': _categoriaSelecionada,
        'telefone': _telefoneController.text,
        'telefone_2': _telefone2Controller.text,
        'situacao': _situacaoSelecionada, // Novo campo
        'transportadora_id': transportadoraId,
      };

      await _supabase.from('motoristas').insert(dados);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Motorista cadastrado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        
        widget.onCadastroConcluido();
      }
    } catch (e) {
      debugPrint('Erro ao cadastrar motorista: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao cadastrar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  void _limparFormulario() {
    _formKey.currentState?.reset();
    _nomeController.clear();
    _nome2Controller.clear();
    _cpfController.clear();
    _cnhController.clear();
    _telefoneController.clear();
    _telefone2Controller.clear();
    setState(() {
      _categoriaSelecionada = null;
      _situacaoSelecionada = 'Ativo'; // Reset para valor default
      _transportadoraSelecionada = null;
      _cpfError = null;
      _validandoCpf = false;
    });
  }

  String? _validarCpfSync(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Informe o CPF';
    }
    
    final cpfLimpo = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (cpfLimpo.length != 11) {
      return 'CPF inválido';
    }
    
    // Retorna o erro do CPF se houver
    return _cpfError;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Form(
          key: _formKey,
          // LISTENER PARA CAPTURAR A TECLA ESC
          child: RawKeyboardListener(
            focusNode: FocusNode(),
            onKey: (RawKeyEvent event) {
              if (event is RawKeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                Navigator.of(context).pop();
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cabeçalho
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0D47A1),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_add, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Cadastrar Novo Motorista',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // Corpo do formulário
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Primeira linha: Nome e Nome 2
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _CampoFormulario(
                                label: 'Nome *',
                                controller: _nomeController,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Informe o nome do motorista';
                                  }
                                  return null;
                                },
                                prefixIcon: Icons.person_outline,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _CampoFormulario(
                                label: 'Nome 2',
                                controller: _nome2Controller,
                                formatters: [
                                  LengthLimitingTextInputFormatter(12), // Limita a 12 caracteres
                                ],
                                prefixIcon: Icons.person_outline,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Segunda linha: CPF e CNH
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'CPF *',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Stack(
                                    children: [
                                      TextFormField(
                                        controller: _cpfController,
                                        inputFormatters: [
                                          cpfMask,
                                          LengthLimitingTextInputFormatter(14), // CPF limitado a 14 caracteres com máscara
                                        ],
                                        keyboardType: TextInputType.number,
                                        validator: _validarCpfSync,
                                        onChanged: (value) {
                                          // Limpar erro quando o usuário começar a digitar
                                          if (_cpfError != null && value.isNotEmpty) {
                                            setState(() => _cpfError = null);
                                          }
                                        },
                                        decoration: InputDecoration(
                                          prefixIcon: const Icon(Icons.badge_outlined),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey.shade400),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 16,
                                          ),
                                          errorMaxLines: 2,
                                        ),
                                      ),
                                      if (_validandoCpf)
                                        Positioned(
                                          right: 8,
                                          top: 0,
                                          bottom: 0,
                                          child: Center(
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (!_validandoCpf && _cpfError == null && _cpfController.text.isNotEmpty)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: GestureDetector(
                                          onTap: _validarCpf,
                                          child: Text(
                                            'Verificar CPF',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context).primaryColor,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _CampoFormulario(
                                label: 'CNH',
                                controller: _cnhController,
                                keyboardType: TextInputType.number,
                                formatters: [
                                  LengthLimitingTextInputFormatter(13), // Limita a 13 caracteres
                                  FilteringTextInputFormatter.digitsOnly, // Apenas números
                                ],
                                validator: (value) {
                                  if (value != null && value.isNotEmpty) {
                                    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                                      return 'Apenas números são permitidos';
                                    }
                                    if (value.length < 11) {
                                      return 'CNH deve ter pelo menos 11 dígitos';
                                    }
                                  }
                                  return null;
                                },
                                prefixIcon: Icons.card_membership_outlined,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Terceira linha: Categoria CNH e Situação
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Categoria CNH *',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: _categoriaSelecionada,
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(Icons.drive_eta_outlined),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.grey.shade400),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 16,
                                      ),
                                    ),
                                    items: _categoriasCNH.map((categoria) {
                                      return DropdownMenuItem<String>(
                                        value: categoria,
                                        child: Text(categoria),
                                      );
                                    }).toList(),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Selecione uma categoria';
                                      }
                                      return null;
                                    },
                                    onChanged: (value) {
                                      setState(() {
                                        _categoriaSelecionada = value;
                                      });
                                    },
                                    hint: const Text('Selecione...'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Situação *',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: _situacaoSelecionada,
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(Icons.work_outline),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.grey.shade400),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 16,
                                      ),
                                    ),
                                    items: _situacoes.map((situacao) {
                                      return DropdownMenuItem<String>(
                                        value: situacao,
                                        child: Text(situacao),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _situacaoSelecionada = value;
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Quarta linha: Telefone e Telefone 2
                        Row(
                          children: [
                            Expanded(
                              child: _CampoFormulario(
                                label: 'Telefone *',
                                controller: _telefoneController,
                                formatters: [telefoneMask],
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Informe um telefone';
                                  }
                                  if (value.replaceAll(RegExp(r'[^0-9]'), '').length < 10) {
                                    return 'Telefone inválido';
                                  }
                                  return null;
                                },
                                prefixIcon: Icons.phone_outlined,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _CampoFormulario(
                                label: 'Telefone 2 (opcional)',
                                controller: _telefone2Controller,
                                formatters: [telefoneMask],
                                keyboardType: TextInputType.phone,
                                prefixIcon: Icons.phone_outlined,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Quinta linha: Transportadora (sozinha)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Transportadora',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _carregandoTransportadoras
                                ? Container(
                                    height: 56,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF0D47A1),
                                      ),
                                    ),
                                  )
                                : DropdownButtonFormField<String?>(
                                    value: _transportadoraSelecionada,
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(Icons.local_shipping_outlined),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.grey.shade400),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 16,
                                      ),
                                    ),
                                    items: [
                                      const DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text('Nenhuma'),
                                      ),
                                      ..._transportadoras.map((transportadora) {
                                        return DropdownMenuItem<String?>(
                                          value: transportadora['nome'] as String?,
                                          child: Text(transportadora['nome'] ?? ''),
                                        );
                                      }).toList(),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        _transportadoraSelecionada = value;
                                      });
                                    },
                                    hint: const Text('Selecione...'),
                                  ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Botões
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _limparFormulario,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  side: BorderSide(color: Colors.grey.shade400),
                                ),
                                child: const Text(
                                  'Limpar',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _salvando ? null : _salvarMotorista,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D47A1),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: _salvando
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.save, size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            'Salvar Motorista',
                                            style: TextStyle(fontSize: 16),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Widget para campos do formulário
class _CampoFormulario extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? formatters;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;

  const _CampoFormulario({
    required this.label,
    required this.controller,
    this.validator,
    this.formatters,
    this.keyboardType,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          inputFormatters: formatters,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 16,
            ),
            errorMaxLines: 2,
          ),
        ),
      ],
    );
  }
}