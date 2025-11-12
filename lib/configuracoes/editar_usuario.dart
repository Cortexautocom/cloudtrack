import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class EditarUsuarioPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final Map<String, dynamic> usuario;

  const EditarUsuarioPage({
    super.key,
    required this.onVoltar,
    required this.usuario,
  });

  @override
  State<EditarUsuarioPage> createState() => _EditarUsuarioPageState();
}

class _EditarUsuarioPageState extends State<EditarUsuarioPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final nomeController = TextEditingController();
  final emailController = TextEditingController();
  final celularController = TextEditingController();
  final funcaoController = TextEditingController();

  final nomeFocus = FocusNode();
  final emailFocus = FocusNode();
  final celularFocus = FocusNode();
  final funcaoFocus = FocusNode();

  String? filialSelecionada;
  String? nivelSelecionado;
  String? statusAtual;

  List<Map<String, dynamic>> _filiais = [];
  bool _salvando = false;
  bool _editado = false;

  // Máscara de celular
  final celularMask = MaskTextInputFormatter(
    mask: '(##) # ####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  @override
  void initState() {
    super.initState();
    _carregarFiliais();
    _preencherCampos();
    _configurarListenersDeFoco();
  }

  void _configurarListenersDeFoco() {
    nomeFocus.addListener(() {
      if (!nomeFocus.hasFocus) _verificarAlteracoes();
    });
    emailFocus.addListener(() {
      if (!emailFocus.hasFocus) _verificarAlteracoes();
    });
    celularFocus.addListener(() {
      if (!celularFocus.hasFocus) _verificarAlteracoes();
    });
    funcaoFocus.addListener(() {
      if (!funcaoFocus.hasFocus) _verificarAlteracoes();
    });
  }

  void _preencherCampos() {
    final u = widget.usuario;
    nomeController.text = u['nome'] ?? '';
    emailController.text = u['email'] ?? '';
    celularController.text = u['celular'] ?? '';
    funcaoController.text = u['funcao'] ?? '';
    filialSelecionada = u['id_filial']?.toString();
    nivelSelecionado = u['nivel']?.toString();
    statusAtual = u['status'] ?? 'ativo';
  }

  Future<void> _carregarFiliais() async {
    try {
      final res = await supabase.from('filiais').select('id, nome');
      setState(() {
        _filiais = List<Map<String, dynamic>>.from(res);
      });
    } catch (e) {
      debugPrint('❌ Erro ao carregar filiais: $e');
    }
  }

  void _verificarAlteracoes() {
    final u = widget.usuario;
    final alterado = nomeController.text != (u['nome'] ?? '') ||
        emailController.text != (u['email'] ?? '') ||
        celularController.text != (u['celular'] ?? '') ||
        funcaoController.text != (u['funcao'] ?? '') ||
        filialSelecionada != (u['id_filial']?.toString()) ||
        nivelSelecionado != (u['nivel']?.toString());
    setState(() => _editado = alterado);
  }

  Future<void> _salvarAlteracoes() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    try {
      await supabase.from('usuarios').update({
        'nome': nomeController.text.trim(),
        'email': emailController.text.trim(),
        'celular': celularController.text.trim(),
        'funcao': funcaoController.text.trim(),
        'id_filial': filialSelecionada,
        'nivel': int.tryParse(nivelSelecionado ?? '1'),
      }).eq('id', widget.usuario['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Alterações salvas com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onVoltar();
      }
    } catch (e) {
      debugPrint('❌ Erro ao salvar alterações: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _alternarStatusUsuario() async {
    final novoStatus = statusAtual == 'suspenso' ? 'ativo' : 'suspenso';
    final confirmar = await _mostrarDialogoConfirmacao(
      titulo: novoStatus == 'ativo' ? 'Reativar Usuário' : 'Suspender Usuário',
      mensagem: novoStatus == 'ativo'
          ? 'Tem certeza que deseja reativar este usuário?'
          : 'Tem certeza que deseja suspender este usuário?',
    );
    
    if (!confirmar) return;

    try {
      await supabase
          .from('usuarios')
          .update({'status': novoStatus}).eq('id', widget.usuario['id']);

      if (mounted) {
        final mensagem = novoStatus == 'ativo'
            ? '✅ Usuário reativado com sucesso.'
            : '⚠️ Usuário suspenso com sucesso.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensagem)),
        );
        widget.onVoltar();
      }
    } catch (e) {
      debugPrint('❌ Erro ao alterar status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao alterar status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _redefinirSenha() async {
    final confirmar = await _mostrarDialogoConfirmacao(
      titulo: 'Redefinir Senha',
      mensagem: 'Tem certeza que deseja redefinir a senha deste usuário? Uma nova senha temporária será enviada por e-mail.',
    );
    
    if (!confirmar) return;

    setState(() => _salvando = true);

    try {
      // TODO: Implementar lógica de redefinição de senha
      await Future.delayed(const Duration(seconds: 2)); // Simulação

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Senha redefinida com sucesso! Verifique o e-mail do usuário.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erro ao redefinir senha: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao redefinir senha: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<bool> _mostrarDialogoConfirmacao({
    required String titulo,
    required String mensagem,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final bool suspenso = statusAtual == 'suspenso';

    return Padding(
      padding: const EdgeInsets.only(top: 5, left: 20, right: 20),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 800,
          color: Colors.white,
          padding: const EdgeInsets.only(
            left: 30,
            right: 30,
            bottom: 30,
            top: 10,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 🔹 Cabeçalho com menu de ações
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                      onPressed: widget.onVoltar,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      suspenso ? "Usuário Suspenso" : "Editar Usuário",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const Spacer(),
                    // 🔹 Menu de ações
                    _buildMenuAcoes(suspenso),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 20),

                // 🔹 Campos do formulário
                Expanded(
                  child: ListView(
                    children: [
                      _campo("Nome completo", nomeController,
                          habilitado: !suspenso,
                          obrigatorio: true,
                          focusNode: nomeFocus),
                      _campo("E-mail", emailController,
                          tipo: TextInputType.emailAddress,
                          habilitado: !suspenso,
                          focusNode: emailFocus),
                      _campo("Celular", celularController,
                          tipo: TextInputType.phone,
                          habilitado: !suspenso,
                          mask: celularMask,
                          focusNode: celularFocus),
                      _campo("Função / Cargo", funcaoController,
                          habilitado: !suspenso, focusNode: funcaoFocus),

                      // 🔹 Filial
                      DropdownButtonFormField<String>(
                        value: filialSelecionada,
                        decoration: const InputDecoration(
                          labelText: "Filial",
                          border: OutlineInputBorder(),
                        ),
                        items: _filiais
                            .map((f) => DropdownMenuItem(
                                  value: f['id'].toString(),
                                  child: Text(f['nome']),
                                ))
                            .toList(),
                        onChanged: suspenso
                            ? null
                            : (v) {
                                setState(() {
                                  filialSelecionada = v;
                                });
                                _verificarAlteracoes();
                              },
                      ),
                      const SizedBox(height: 16),

                      // 🔹 Nível
                      DropdownButtonFormField<String>(
                        value: nivelSelecionado,
                        decoration: const InputDecoration(
                          labelText: "Nível de acesso",
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: "1", child: Text("Logística / Operações ♦ Nível 1")),
                          DropdownMenuItem(value: "2", child: Text("Gerência e supervisão ♦ Nível 2")),
                          DropdownMenuItem(value: "3", child: Text("Diretoria e Administração ♦ Nível 3")),
                        ],
                        onChanged: suspenso
                            ? null
                            : (v) {
                                setState(() {
                                  nivelSelecionado = v;
                                });
                                _verificarAlteracoes();
                              },
                      ),
                      const SizedBox(height: 20),

                      // 🔹 Status
                      TextFormField(
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: "Status atual: $statusAtual",
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🔹 Menu de ações
  Widget _buildMenuAcoes(bool suspenso) {
    return Row(
      children: [
        // Botão Salvar
        if (!suspenso)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: (_editado && !_salvando) ? _salvarAlteracoes : null,
              icon: const Icon(Icons.save, size: 18),
              label: Text(_salvando ? "Salvando..." : "Salvar"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

        // Menu dropdown com mais ações
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz, color: Color(0xFF0D47A1)),
          onSelected: (value) {
            switch (value) {
              case 'redefinir_senha':
                _redefinirSenha();
                break;
              case 'suspender_reativar':
                _alternarStatusUsuario();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'redefinir_senha',
              enabled: !_salvando,
              child: const Row(
                children: [
                  Icon(Icons.lock_reset, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Redefinir senha'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'suspender_reativar',
              enabled: !_salvando,
              child: Row(
                children: [
                  Icon(
                    suspenso ? Icons.check_circle : Icons.block,
                    color: suspenso ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(suspenso ? 'Reativar usuário' : 'Suspender usuário'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 🔹 Campo genérico
  Widget _campo(
    String label,
    TextEditingController controller, {
    TextInputType tipo = TextInputType.text,
    bool habilitado = true,
    bool obrigatorio = false,
    MaskTextInputFormatter? mask,
    FocusNode? focusNode,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        enabled: habilitado,
        controller: controller,
        focusNode: focusNode,
        keyboardType: tipo,
        inputFormatters: mask != null ? [mask] : [],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: !habilitado,
          fillColor: habilitado ? null : Colors.grey.shade200,
        ),
        validator: obrigatorio && habilitado
            ? (v) => v == null || v.isEmpty ? "Preencha este campo" : null
            : null,
      ),
    );
  }
}