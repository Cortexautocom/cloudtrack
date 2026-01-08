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
  final _categoriaController = TextEditingController();
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
  String? _categoriaSelecionada;

  // Opções para categoria CNH
  final List<String> _categoriasCNH = [
    'A', 'B', 'C', 'D', 'E', 'AB', 'AC', 'AD', 'AE'
  ];

  @override
  void dispose() {
    _nomeController.dispose();
    _nome2Controller.dispose();
    _cpfController.dispose();
    _cnhController.dispose();
    _categoriaController.dispose();
    _telefoneController.dispose();
    _telefone2Controller.dispose();
    super.dispose();
  }

  Future<void> _salvarMotorista() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _salvando = true);

    try {
      final dados = {
        'nome': _nomeController.text.trim(),
        'nome_2': _nome2Controller.text.trim(),
        'cpf': _cpfController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        'cnh': int.tryParse(_cnhController.text) ?? 0,
        'categoria': _categoriaSelecionada,
        'telefone': _telefoneController.text,
        'telefone_2': _telefone2Controller.text,
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
    _categoriaController.clear();
    _telefoneController.clear();
    _telefone2Controller.clear();
    setState(() => _categoriaSelecionada = null);
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
                            child: _CampoFormulario(
                              label: 'CPF',
                              controller: _cpfController,
                              formatters: [cpfMask],
                              keyboardType: TextInputType.number,
                              prefixIcon: Icons.badge_outlined,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _CampoFormulario(
                              label: 'CNH',
                              controller: _cnhController,
                              keyboardType: TextInputType.number,
                              prefixIcon: Icons.card_membership_outlined,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Terceira linha: Categoria e Telefone
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
                                    return DropdownMenuItem(
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
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Quarta linha: Telefone 2
                      _CampoFormulario(
                        label: 'Telefone 2 (opcional)',
                        controller: _telefone2Controller,
                        formatters: [telefoneMask],
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_outlined,
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