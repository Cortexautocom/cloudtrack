import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class AprovarUsuarioPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final Map<String, dynamic> usuario;

  const AprovarUsuarioPage({
    super.key,
    required this.onVoltar,
    required this.usuario,
  });

  @override
  State<AprovarUsuarioPage> createState() => _AprovarUsuarioPageState();
}

class _AprovarUsuarioPageState extends State<AprovarUsuarioPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  bool _salvando = false;
  String? nivelSelecionado;
  List<Map<String, dynamic>> _filiais = [];

  // Controladores dos campos
  final nomeController = TextEditingController();
  final emailController = TextEditingController();
  final celularController = TextEditingController();
  final funcaoController = TextEditingController();
  
  // 🔹 NOVOS CONTROLADORES PARA SENHA
  final senhaInicialController = TextEditingController();
  final confirmarSenhaController = TextEditingController();
  
  String? filialSelecionada;
  bool _obscureSenha1 = true;
  bool _obscureSenha2 = true;

  @override
  void initState() {
    super.initState();
    _carregarFiliais();
    _preencherCampos();
  }

  void _preencherCampos() {
    final u = widget.usuario;
    nomeController.text = u['nome'] ?? '';
    emailController.text = u['email'] ?? '';
    celularController.text = u['celular'] ?? '';
    funcaoController.text = u['funcao'] ?? '';
    filialSelecionada = u['id_filial']?.toString();
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

  // 🔹 VALIDAÇÃO DA SENHA
  String? _validarSenha(String? value) {
    if (value == null || value.isEmpty) {
      return 'Digite a senha inicial';
    }
    if (value.length < 6) {
      return 'A senha deve ter pelo menos 6 caracteres';
    }
    return null;
  }

  String? _validarConfirmacaoSenha(String? value) {
    if (value != senhaInicialController.text) {
      return 'As senhas não coincidem';
    }
    return null;
  }

  // 🔹 Aprova o usuário (AGORA COM SENHA)
  Future<void> _aprovarUsuario() async {
    if (!_formKey.currentState!.validate()) return;

    if (!mounted) return;
      setState(() => _salvando = true);

    try {
      final nome = nomeController.text.trim();
      final email = emailController.text.trim();
      final celular = celularController.text.trim();
      final funcao = funcaoController.text.trim();
      final filialId = filialSelecionada;
      final senhaInicial = senhaInicialController.text.trim();

      final int nivel = nivelSelecionado == "Gerência e coordenação" ? 2 : 1;

      // 🌐 URL da função no Supabase
      final url = "https://ikaxzlpaihdkqyjqrxyw.functions.supabase.co/aprovar-usuario";

      // 🔹 Envia os dados via POST para a função (AGORA COM SENHA)
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'nome': nome,
          'email': email,
          'celular': celular,
          'funcao': funcao,
          'id_filial': filialId,
          'nivel': nivel,
          'senha_inicial': senhaInicial, // ✅ NOVO CAMPO
        }),
      );

      final result = jsonDecode(response.body);
      if (result['success'] == true) {
        // ✅ Atualiza o cadastro pendente
        await supabase
            .from('cadastros_pendentes')
            .update({
              'status': 'aprovado',
              'nivel': nivel,
              'nome': nome,
              'celular': celular,
              'funcao': funcao,
              'id_filial': filialId
            })
            .eq('email', email);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✅ Usuário aprovado! Senha definida e notificação enviada para $email."),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          
          // ✅ SOLUÇÃO DEFINITIVA: Usar PostFrameCallback + Delay
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) {
                widget.onVoltar();
              }
            });
          });
        }
      } else {
        throw Exception(result['error'] ?? 'Erro desconhecido.');
      }
    } catch (e) {
      debugPrint("❌ Erro ao aprovar usuário: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erro ao aprovar: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(30),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            // 🔹 Cabeçalho
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                  onPressed: widget.onVoltar,
                ),
                const Text(
                  "Aprovar Usuário",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 20),

            // 🔹 Campos editáveis
            _campoEditavel("Nome completo", nomeController),
            _campoEditavel("E-mail", emailController,
                tipo: TextInputType.emailAddress),
            _campoEditavel("Celular", celularController,
                tipo: TextInputType.phone),
            _campoEditavel("Função / Cargo", funcaoController),

            // 🔹 Campo Filial
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
              onChanged: (v) => setState(() => filialSelecionada = v),
              validator: (v) => v == null ? "Selecione uma filial" : null,
            ),
            const SizedBox(height: 20),

            // 🔹 NOVO: Campo Senha Inicial
            TextFormField(
              controller: senhaInicialController,
              obscureText: _obscureSenha1,
              decoration: InputDecoration(
                labelText: "Senha inicial",
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureSenha1 
                      ? Icons.visibility_off_outlined 
                      : Icons.visibility_outlined),
                  onPressed: () => setState(() => _obscureSenha1 = !_obscureSenha1),
                ),
                helperText: "Mínimo 6 caracteres",
              ),
              validator: _validarSenha,
            ),
            const SizedBox(height: 16),

            // 🔹 NOVO: Campo Confirmar Senha
            TextFormField(
              controller: confirmarSenhaController,
              obscureText: _obscureSenha2,
              decoration: InputDecoration(
                labelText: "Confirmar senha inicial",
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureSenha2 
                      ? Icons.visibility_off_outlined 
                      : Icons.visibility_outlined),
                  onPressed: () => setState(() => _obscureSenha2 = !_obscureSenha2),
                ),
              ),
              validator: _validarConfirmacaoSenha,
            ),
            const SizedBox(height: 20),

            // 🔹 Selecionar nível
            DropdownButtonFormField<String>(
              value: nivelSelecionado,
              decoration: const InputDecoration(
                labelText: "Nível de acesso",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: "Logística / Operações ♦ Nível 1",
                  child: Text("Logística / Operações ♦ Nível 1"),
                ),
                DropdownMenuItem(
                  value: "Gerência e supervisão ♦ Nível 2",
                  child: Text("Gerência e supervisão ♦ Nível 2"),
                ),
                DropdownMenuItem(
                  value: "Diretoria e Administração ♦ Nível 2",
                  child: Text("Diretoria e Administração ♦ Nível 2"),
                ),
              ],
              onChanged: (v) => setState(() => nivelSelecionado = v),
              validator: (v) => v == null ? "Selecione o nível de acesso" : null,
            ),
            const SizedBox(height: 30),

            // 🔹 Informação importante
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "O usuário receberá um email de notificação e poderá fazer login "
                      "com esta senha. Na primeira vez, será solicitado que crie uma nova senha.",
                      style: TextStyle(
                        color: Colors.blue[800],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 🔹 Botão de aprovação
            Center(
              child: ElevatedButton.icon(
                onPressed: _salvando ? null : _aprovarUsuario,
                icon: _salvando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.check, color: Colors.white),
                label: Text(
                  _salvando ? "Aprovando..." : "Aprovar usuário",
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // 🔹 Campo genérico editável
  Widget _campoEditavel(String label, TextEditingController controller,
      {TextInputType tipo = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: tipo,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (v) => v == null || v.isEmpty ? "Preencha este campo" : null,
      ),
    );
  }

  @override
  void dispose() {
    // 🔹 Limpa os controladores
    nomeController.dispose();
    emailController.dispose();
    celularController.dispose();
    funcaoController.dispose();
    senhaInicialController.dispose();
    confirmarSenhaController.dispose();
    super.dispose();
  }
}